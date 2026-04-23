#include "operators.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/*
 * Costruisce il Laplaciano discreto 1D con condizioni di Neumann omogenee.
 *
 * La matrice ha struttura tridiagonale standard:
 *     1  -2   1
 *
 * con correzioni ai bordi dovute ai ghost nodes:
 * - sinistra:  u_0     = u_2
 * - destra:    u_{M+1} = u_{M-1}
 *
 * Input:
 *   L = matrice da riempire, di dimensione M x M
 *   M = numero di nodi
 *   h = passo spaziale
 */
static void build_1d_laplacian_dense(double *L, int M, double h) {
    double h2_inv = 1.0 / (h * h);		// Fattore 1/h^2 del Laplaciano discreto
    
    memset(L, 0, M * M * sizeof(double));		// Inizializza tutta la matrice a zero
    
    for (int i = 0; i < M; i++) {		// Costruisce la tridiagonale standard
        L[i*M + i] = -2.0 * h2_inv;		// Diagonale principale
        if (i > 0)     L[i*M + (i-1)] = 1.0 * h2_inv;		// Sottodiagonale
        if (i < M - 1) L[i*M + (i+1)] = 1.0 * h2_inv;		// Sovradiagonale
    }
    
    L[0*M + 1] = 2.0 * h2_inv;		// Correzione al bordo sinistro per Neumann
    L[(M-1)*M + (M-2)] = 2.0 * h2_inv;		// Correzione al bordo destro per Neumann
}

/*
 * Costruisce il gradiente discreto 1D con condizioni di Neumann omogenee.
 *
 * Ai nodi interni usa la formula centrata:
 *     (u_{i+1} - u_{i-1}) / (2h)
 *
 * Ai bordi le righe restano nulle, coerentemente con il gradiente nullo.
 *
 * Input:
 *   G = matrice da riempire, di dimensione M x M
 *   M = numero di nodi
 *   h = passo spaziale
 */
static void build_1d_gradient_dense(double *G, int M, double h) {
    double h2_inv = 0.5 / h;		// Fattore 1/(2h)
    
    memset(G, 0, M * M * sizeof(double));		// Inizializza la matrice a zero
    
    for (int i = 1; i < M - 1; i++) {		// Solo nodi interni
        G[i*M + (i-1)] = -h2_inv;		// Coefficiente sinistro
        G[i*M + (i+1)] =  h2_inv;		// Coefficiente destro
    }
    
    // Le righe di bordo restano nulle: G(1,:) = 0 e G(M,:) = 0
}

/*
 * Crea e inizializza la struttura Operators.
 *
 * Alloca e costruisce:
 * - Lx, Ly = Laplaciani 1D
 * - Gx, Gy = gradienti 1D
 *
 * Questi operatori sono poi usati per applicare gli operatori 2D
 * nella forma equivalente ai prodotti di Kronecker.
 *
 * Input:
 *   p = parametri della simulazione
 *
 * Output:
 *   puntatore a Operators inizializzato
 *   oppure NULL in caso di errore
 */
Operators* operators_create(const Params *p) {
    if (!p) {		// Controlla validità dei parametri
        fprintf(stderr, "ERROR: operators_create received NULL Params\n");
        return NULL;
    }
    
    Operators *op = (Operators*) malloc(sizeof(Operators));		// Alloca struttura Operators
    if (!op) {		// Verifica allocazione
        fprintf(stderr, "ERROR: Failed to allocate Operators\n");
        return NULL;
    }
    
    op->Lx = (double*) malloc(p->Mx * p->Mx * sizeof(double));		// Laplaciano 1D in x
    op->Ly = (double*) malloc(p->My * p->My * sizeof(double));		// Laplaciano 1D in y
    op->Gx = (double*) malloc(p->Mx * p->Mx * sizeof(double));		// Gradiente 1D in x
    op->Gy = (double*) malloc(p->My * p->My * sizeof(double));		// Gradiente 1D in y
    
    if (!op->Lx || !op->Ly || !op->Gx || !op->Gy) {		// Verifica allocazioni
        fprintf(stderr, "ERROR: Failed to allocate operator matrices\n");
        free(op->Lx);
        free(op->Ly);
        free(op->Gx);
        free(op->Gy);
        free(op);
        return NULL;
    }
    
    op->Mx = p->Mx;		// Salva dimensione x
    op->My = p->My;		// Salva dimensione y
    
    build_1d_laplacian_dense(op->Lx, p->Mx, p->hx);		// Costruisce Lx
    build_1d_laplacian_dense(op->Ly, p->My, p->hy);		// Costruisce Ly
    build_1d_gradient_dense(op->Gx, p->Mx, p->hx);		// Costruisce Gx
    build_1d_gradient_dense(op->Gy, p->My, p->hy);		// Costruisce Gy
    
    return op;		// Restituisce struttura inizializzata
}

/*
 * Applica il Laplaciano discreto 2D a un campo vettorializzato.
 *
 * Implementa:
 *     Δ_h = I_y ⊗ L_x + L_y ⊗ I_x
 *
 * Input:
 *   out = vettore risultato
 *   in  = vettore ingresso
 *   op  = struttura operatori
 *   p   = parametri
 */
void apply_laplacian_2d(double *out, const double *in,
                        const Operators *op, const Params *p) {
    memset(out, 0, p->Mx * p->My * sizeof(double));		// Azzera il vettore di uscita
    
    for (int j = 0; j < p->My; j++) {		// Applica Lx lungo ogni colonna j
        for (int i = 0; i < p->Mx; i++) {
            for (int ii = 0; ii < p->Mx; ii++) {
                int idx_out = i + p->Mx * j;		// Nodo di uscita (i,j)
                int idx_in  = ii + p->Mx * j;		// Nodo di ingresso sulla stessa colonna
                out[idx_out] += op->Lx[i*p->Mx + ii] * in[idx_in];		// Contributo del termine in x
            }
        }
    }
    
    for (int i = 0; i < p->Mx; i++) {		// Applica Ly lungo ogni riga i
        for (int j = 0; j < p->My; j++) {
            for (int jj = 0; jj < p->My; jj++) {
                int idx_out = i + p->Mx * j;		// Nodo di uscita (i,j)
                int idx_in  = i + p->Mx * jj;		// Nodo di ingresso sulla stessa riga
                out[idx_out] += op->Ly[j*p->My + jj] * in[idx_in];		// Contributo del termine in y
            }
        }
    }
}

/*
 * Applica il gradiente discreto 2D nella direzione x.
 *
 * Implementa:
 *     out = (I_y ⊗ G_x) in
 *
 * Input:
 *   out = vettore risultato
 *   in  = vettore ingresso
 *   op  = struttura operatori
 *   p   = parametri
 */
void apply_gradient_x_2d(double *out, const double *in,
                         const Operators *op, const Params *p) {
    memset(out, 0, p->Mx * p->My * sizeof(double));		// Azzera il vettore di uscita
    
    for (int j = 0; j < p->My; j++) {		// Applica Gx separatamente a ogni colonna
        for (int i = 0; i < p->Mx; i++) {
            for (int ii = 0; ii < p->Mx; ii++) {
                int idx_out = i + p->Mx * j;		// Nodo di uscita
                int idx_in  = ii + p->Mx * j;		// Nodo di ingresso sulla stessa colonna
                out[idx_out] += op->Gx[i*p->Mx + ii] * in[idx_in];		// Contributo del gradiente in x
            }
        }
    }
}

/*
 * Applica il gradiente discreto 2D nella direzione y.
 *
 * Implementa:
 *     out = (G_y ⊗ I_x) in
 *
 * Input:
 *   out = vettore risultato
 *   in  = vettore ingresso
 *   op  = struttura operatori
 *   p   = parametri
 */
void apply_gradient_y_2d(double *out, const double *in,
                         const Operators *op, const Params *p) {
    memset(out, 0, p->Mx * p->My * sizeof(double));		// Azzera il vettore di uscita
    
    for (int i = 0; i < p->Mx; i++) {		// Applica Gy separatamente a ogni riga
        for (int j = 0; j < p->My; j++) {
            for (int jj = 0; jj < p->My; jj++) {
                int idx_out = i + p->Mx * j;		// Nodo di uscita
                int idx_in  = i + p->Mx * jj;		// Nodo di ingresso sulla stessa riga
                out[idx_out] += op->Gy[j*p->My + jj] * in[idx_in];		// Contributo del gradiente in y
            }
        }
    }
}

/*
 * Libera la memoria associata alla struttura Operators.
 */
void operators_free(Operators *op) {
    if (op) {		// Controlla validità del puntatore
        free(op->Lx);		// Libera Lx
        free(op->Ly);		// Libera Ly
        free(op->Gx);		// Libera Gx
        free(op->Gy);		// Libera Gy
        free(op);		// Libera struttura principale
    }
}
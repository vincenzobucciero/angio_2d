#include "reaction.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

/*
 * Crea e inizializza una workspace temporanea per il passo di reazione.
 *
 * La workspace contiene tutti i buffer necessari per:
 * - i termini noti delle variabili
 * - il campo di velocità (vx, vy)
 * - Laplaciani e gradienti discreti
 *
 * Input:
 *   M = numero totale di nodi della griglia
 *
 * Output:
 *   puntatore a ReactionWorkspace inizializzata
 *   oppure NULL in caso di errore
 */
ReactionWorkspace* reaction_workspace_create(int M) {
    ReactionWorkspace *ws = (ReactionWorkspace*) malloc(sizeof(ReactionWorkspace));		// Alloca struttura workspace
    if (!ws) {		// Controlla allocazione
        fprintf(stderr, "ERROR: Failed to allocate ReactionWorkspace\n");		// Errore
        return NULL;		// Esce
    }
    
    ws->C_rhs = (double*) malloc(M * sizeof(double));		// RHS della variabile C
    ws->P_rhs = (double*) malloc(M * sizeof(double));		// RHS della variabile P
    ws->Inh_rhs = (double*) malloc(M * sizeof(double));		// RHS della variabile Inh
    ws->F_rhs = (double*) malloc(M * sizeof(double));		// RHS della variabile F
    
    ws->vx = (double*) malloc(M * sizeof(double));		// Componente x del campo di velocità
    ws->vy = (double*) malloc(M * sizeof(double));		// Componente y del campo di velocità
    
    ws->lap_I = (double*) malloc(M * sizeof(double));		// Laplaciano di Inh
    ws->lap_F = (double*) malloc(M * sizeof(double));		// Laplaciano di F
    
    ws->gx_I = (double*) malloc(M * sizeof(double));		// Gradiente x di Inh
    ws->gy_I = (double*) malloc(M * sizeof(double));		// Gradiente y di Inh
    ws->gx_F = (double*) malloc(M * sizeof(double));		// Gradiente x di F
    ws->gy_F = (double*) malloc(M * sizeof(double));		// Gradiente y di F
    ws->gx_C = (double*) malloc(M * sizeof(double));		// Gradiente x di C
    ws->gy_C = (double*) malloc(M * sizeof(double));		// Gradiente y di C
    
    if (!ws->C_rhs || !ws->P_rhs || !ws->Inh_rhs || !ws->F_rhs ||
        !ws->vx || !ws->vy || !ws->lap_I || !ws->lap_F ||
        !ws->gx_I || !ws->gy_I || !ws->gx_F || !ws->gy_F ||
        !ws->gx_C || !ws->gy_C) {		// Verifica allocazioni
        fprintf(stderr, "ERROR: Failed to allocate workspace arrays\n");		// Errore
        reaction_workspace_free(ws);		// Libera memoria già allocata
        return NULL;		// Esce
    }
    
    ws->M = M;		// Salva numero totale di nodi
    return ws;		// Restituisce workspace
}

/*
 * Calcola i termini del lato destro del sistema di reazione/trasporto.
 *
 * In particolare costruisce:
 * - il campo di velocità vx, vy
 * - i termini C_rhs, P_rhs, Inh_rhs, F_rhs
 *
 * Input:
 *   ws   = workspace temporanea
 *   C,P,Inh,F = stato corrente
 *   taf  = campo TAF e potenziale ausiliario
 *   op   = operatori discreti
 *   p    = parametri del modello
 */
void reaction_compute_rhs(ReactionWorkspace *ws,
                          const double *C, const double *P,
                          const double *Inh, const double *F,
                          const TAF *taf, const Operators *op,
                          const Params *p) {
    int M = ws->M;		// Numero totale di nodi
    
    apply_laplacian_2d(ws->lap_I, Inh, op, p);		// Calcola Laplaciano di Inh
    apply_laplacian_2d(ws->lap_F, F, op, p);		// Calcola Laplaciano di F
    
    apply_gradient_x_2d(ws->gx_I, Inh, op, p);		// Gradiente x di Inh
    apply_gradient_y_2d(ws->gy_I, Inh, op, p);		// Gradiente y di Inh
    apply_gradient_x_2d(ws->gx_F, F, op, p);		// Gradiente x di F
    apply_gradient_y_2d(ws->gy_F, F, op, p);		// Gradiente y di F
    apply_gradient_x_2d(ws->gx_C, C, op, p);		// Gradiente x di C
    apply_gradient_y_2d(ws->gy_C, C, op, p);		// Gradiente y di C
    
    for (int i = 0; i < M; i++) {		// Costruisce il campo di velocità
        ws->vx[i] = p->alpha2 * ws->gx_I[i] - p->alpha1 * ws->gx_F[i] - p->alpha3 * taf->phi_x[i];		// Velocità in x
        ws->vy[i] = p->alpha2 * ws->gy_I[i] - p->alpha1 * ws->gy_F[i] - p->alpha3 * taf->phi_y[i];		// Velocità in y
    }
    
    double *div_v = (double*) malloc(M * sizeof(double));		// Divergenza del campo di velocità
    for (int i = 0; i < M; i++) {		// Calcola div_v
        div_v[i] = p->alpha2 * ws->lap_I[i] - p->alpha1 * ws->lap_F[i];		// Divergenza semplificata
    }
    
    for (int i = 0; i < M; i++) {		// RHS della variabile C
        ws->C_rhs[i] = ws->vx[i] * ws->gx_C[i]
                     + ws->vy[i] * ws->gy_C[i]
                     + div_v[i] * C[i]
                     + p->k1 * C[i] * (1.0 - C[i]);		// Trasporto + crescita logistica
    }
    
    for (int i = 0; i < M; i++) {		// RHS della variabile P
        ws->P_rhs[i] = -p->k3 * P[i] * Inh[i]
                     + p->k4 * taf->T[i] * C[i]
                     + p->k5 * taf->T[i]
                     - p->k6 * P[i];		// Interazione, produzione e decadimento
    }
    
    for (int i = 0; i < M; i++) {		// RHS della variabile Inh
        ws->Inh_rhs[i] = -p->k3 * P[i] * Inh[i];		// Consumo dovuto a interazione con P
    }
    
    for (int i = 0; i < M; i++) {		// RHS della variabile F
        ws->F_rhs[i] = -p->k2 * P[i] * F[i];		// Degradazione ECM
    }
    
    free(div_v);		// Libera buffer temporaneo della divergenza
}

/*
 * Esegue un passo di Eulero esplicito per il sistema di reazione.
 *
 * Aggiorna in-place le quattro variabili usando i termini RHS
 * già calcolati nella workspace.
 *
 * Input:
 *   C,P,Inh,F = stato corrente
 *   ws        = workspace contenente i RHS
 *   dt        = passo temporale locale
 *   M         = numero totale di nodi
 */
void reaction_euler_step(double *C, double *P, double *Inh, double *F,
                         const ReactionWorkspace *ws, double dt, int M) {
    for (int i = 0; i < M; i++) {		// Aggiornamento esplicito nodo per nodo
        C[i] = C[i] + dt * ws->C_rhs[i];		// Euler forward per C
        P[i] = P[i] + dt * ws->P_rhs[i];		// Euler forward per P
        Inh[i] = Inh[i] + dt * ws->Inh_rhs[i];		// Euler forward per Inh
        F[i] = F[i] + dt * ws->F_rhs[i];		// Euler forward per F
    }
}

/*
 * Impone la non negatività delle variabili del modello.
 *
 * Dopo ogni passo esplicito, eventuali valori negativi
 * dovuti a errore numerico vengono tagliati a zero.
 *
 * Input:
 *   C,P,Inh,F = campi da correggere
 *   M         = numero totale di nodi
 */
void reaction_clamp_positive(double *C, double *P, double *Inh, double *F, int M) {
    for (int i = 0; i < M; i++) {		// Scorre tutti i nodi
        if (C[i] < 0.0) C[i] = 0.0;		// Impone C >= 0
        if (P[i] < 0.0) P[i] = 0.0;		// Impone P >= 0
        if (Inh[i] < 0.0) Inh[i] = 0.0;		// Impone Inh >= 0
        if (F[i] < 0.0) F[i] = 0.0;		// Impone F >= 0
    }
}

/*
 * Esegue un passo completo di reazione/trasporto.
 *
 * La funzione:
 * 1) crea la workspace temporanea
 * 2) calcola i RHS
 * 3) esegue il passo di Eulero
 * 4) impone non negatività
 * 5) libera la workspace
 *
 * Input:
 *   C,P,Inh,F = stato corrente
 *   taf       = campo TAF
 *   op        = operatori discreti
 *   p         = parametri
 *   dt        = passo temporale locale
 */
void reaction_step(double *C, double *P, double *Inh, double *F,
                   const TAF *taf, const Operators *op,
                   const Params *p, double dt) {
    int M = p->Mx * p->My;		// Numero totale di nodi
    
    ReactionWorkspace *ws = reaction_workspace_create(M);		// Alloca workspace temporanea
    if (!ws) return;		// Esce se allocazione fallisce
    
    reaction_compute_rhs(ws, C, P, Inh, F, taf, op, p);		// Costruisce i termini RHS
    reaction_euler_step(C, P, Inh, F, ws, dt, M);		// Esegue aggiornamento esplicito
    reaction_clamp_positive(C, P, Inh, F, M);		// Impone non negatività
    
    reaction_workspace_free(ws);		// Libera workspace
}

/*
 * Libera la memoria associata alla workspace di reazione.
 *
 * Input:
 *   ws = workspace da deallocare
 */
void reaction_workspace_free(ReactionWorkspace *ws) {
    if (ws) {		// Controlla validità puntatore
        free(ws->C_rhs);		// Libera RHS di C
        free(ws->P_rhs);		// Libera RHS di P
        free(ws->Inh_rhs);		// Libera RHS di Inh
        free(ws->F_rhs);		// Libera RHS di F
        free(ws->vx);		// Libera velocità x
        free(ws->vy);		// Libera velocità y
        free(ws->lap_I);		// Libera Laplaciano di Inh
        free(ws->lap_F);		// Libera Laplaciano di F
        free(ws->gx_I);		// Libera gradiente x di Inh
        free(ws->gy_I);		// Libera gradiente y di Inh
        free(ws->gx_F);		// Libera gradiente x di F
        free(ws->gy_F);		// Libera gradiente y di F
        free(ws->gx_C);		// Libera gradiente x di C
        free(ws->gy_C);		// Libera gradiente y di C
        free(ws);		// Libera struttura principale
    }
}
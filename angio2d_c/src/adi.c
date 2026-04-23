#include "adi.h"		// Definizione struct ADI e prototipi
#include <stdlib.h>		// malloc, free
#include <stdio.h>		// fprintf
#include <string.h>		// utility stringhe
#include <math.h>		// funzioni matematiche

/*
 * Crea e inizializza la struttura ADI.
 *
 * Alloca tutta la memoria necessaria per:
 * - coefficienti tridiagonali (x e y)
 * - termini noti (RHS, RHS2)
 * - soluzione intermedia U_star
 *
 * Input:
 *   p = parametri della simulazione
 *
 * Output:
 *   puntatore a struttura ADI pronta all'uso
 */
ADI* adi_create(const Params *p) {
    ADI *adi = (ADI*) malloc(sizeof(ADI));		// Alloca struttura principale

    if (!adi) {		// Controllo allocazione
        fprintf(stderr, "ERROR: Failed to allocate ADI\n");		// Errore
        return NULL;		// Esce
    }

    adi->ax = (double*) malloc(p->Mx * sizeof(double));		// Sottodiagonale x
    adi->bx = (double*) malloc(p->Mx * sizeof(double));		// Diagonale principale x
    adi->cx = (double*) malloc(p->Mx * sizeof(double));		// Sovradiagonale x

    adi->ay = (double*) malloc(p->My * sizeof(double));		// Sottodiagonale y
    adi->by = (double*) malloc(p->My * sizeof(double));		// Diagonale principale y
    adi->cy = (double*) malloc(p->My * sizeof(double));		// Sovradiagonale y

    adi->RHS = (double*) malloc(p->Mx * p->My * sizeof(double));		// RHS primo semi-passo
    adi->RHS2 = (double*) malloc(p->Mx * p->My * sizeof(double));		// RHS secondo semi-passo
    adi->U_star = (double*) malloc(p->Mx * p->My * sizeof(double));		// Soluzione intermedia

    if (!adi->ax || !adi->bx || !adi->cx ||
        !adi->ay || !adi->by || !adi->cy ||
        !adi->RHS || !adi->RHS2 || !adi->U_star) {		// Verifica allocazioni
        fprintf(stderr, "ERROR: Failed to allocate ADI arrays\n");		// Errore
        adi_free(adi);		// Libera memoria
        return NULL;		// Esce
    }

    adi->Mx = p->Mx;		// Salva dimensione x
    adi->My = p->My;		// Salva dimensione y

    return adi;		// Restituisce struttura
}

/*
 * Risolve un sistema tridiagonale Ax = d con algoritmo di Thomas.
 *
 * Input:
 *   a, b, c = diagonali della matrice
 *   d       = termine noto
 *   x       = soluzione
 *   n       = dimensione sistema
 */
void thomas_solve(const double *a, const double *b, const double *c,
                  const double *d, double *x, int n) {

    double *c_star = (double*) malloc(n * sizeof(double));		// Sovradiagonale modificata
    double *d_star = (double*) malloc(n * sizeof(double));		// RHS modificato

    c_star[0] = c[0] / b[0];		// Primo coefficiente
    d_star[0] = d[0] / b[0];		// Primo termine noto

    for (int i = 1; i < n; i++) {		// Forward sweep
        double denom = b[i] - a[i] * c_star[i-1];		// Pivot

        if (i < n - 1) {		// Non ultimo
            c_star[i] = c[i] / denom;		// Aggiorna c*
        }

        d_star[i] = (d[i] - a[i] * d_star[i-1]) / denom;		// Aggiorna d*
    }

    x[n-1] = d_star[n-1];		// Ultima incognita

    for (int i = n - 2; i >= 0; i--) {		// Back substitution
        x[i] = d_star[i] - c_star[i] * x[i+1];		// Risoluzione
    }

    free(c_star);		// Libera memoria
    free(d_star);		// Libera memoria
}

/*
 * Esegue un passo ADI per diffusione:
 *
 *   ∂u/∂t = d Δu
 *
 * Schema:
 *   1) implicito in x
 *   2) implicito in y
 *
 * Input:
 *   u       = campo (vettore 1D)
 *   p       = parametri
 *   adi     = struttura ADI
 *   d_coeff = coefficiente diffusione
 *   tau     = passo temporale
 */
void adi_step(double *u, const Params *p, ADI *adi, double d_coeff, double tau) {

    int Mx = p->Mx;		// Dimensione x
    int My = p->My;		// Dimensione y

    double hx = p->hx;		// Passo x
    double hy = p->hy;		// Passo y

    double tau2 = tau / 2.0;		// Mezzo passo
    double rx = d_coeff * tau2 / (hx * hx);		// Coeff diffusione x
    double ry = d_coeff * tau2 / (hy * hy);		// Coeff diffusione y

    double **U = (double**) malloc(Mx * sizeof(double*));		// Vista 2D (non necessaria)
    for (int i = 0; i < Mx; i++) {		// Loop
        U[i] = &u[i + Mx * 0];		// Puntatore base
    }

    for (int j = 0; j < My; j++) {		// Primo semi-passo (y esplicito)
        for (int i = 0; i < Mx; i++) {		// Loop x
            double rhs_val;		// RHS locale

            if (j == 0) {		// Bordo basso
                rhs_val = (1.0 - 2.0*ry) * u[i + Mx*j] + 2.0*ry * u[i + Mx*(j+1)];		// Neumann
            } else if (j == My - 1) {		// Bordo alto
                rhs_val = 2.0*ry * u[i + Mx*(j-1)] + (1.0 - 2.0*ry) * u[i + Mx*j];		// Neumann
            } else {		// Interno
                rhs_val = ry * u[i + Mx*(j-1)] + (1.0 - 2.0*ry) * u[i + Mx*j] + ry * u[i + Mx*(j+1)];		// Schema centrale
            }

            adi->RHS[i + Mx*j] = rhs_val;		// Salva RHS
        }
    }

    for (int i = 0; i < Mx; i++) {		// Costruzione matrice x
        adi->ax[i] = -rx;		// Sotto
        adi->bx[i] = 1.0 + 2.0*rx;		// Diagonale
        adi->cx[i] = -rx;		// Sopra
    }

    adi->ax[0] = 0.0;		// Bordo sinistro
    adi->cx[0] = -2.0*rx;		// Neumann
    adi->ax[Mx-1] = -2.0*rx;		// Bordo destro
    adi->cx[Mx-1] = 0.0;		// Neumann

    for (int j = 0; j < My; j++) {		// Risolve lungo x
        thomas_solve(adi->ax, adi->bx, adi->cx,
                     &adi->RHS[Mx*j], &adi->U_star[Mx*j], Mx);		// Sistema tridiagonale
    }

    for (int i = 0; i < Mx; i++) {		// Secondo semi-passo
        for (int j = 0; j < My; j++) {		// Loop y
            double rhs_val;		// RHS locale

            if (i == 0) {		// Bordo sinistro
                rhs_val = (1.0 - 2.0*rx) * adi->U_star[i + Mx*j] + 2.0*rx * adi->U_star[(i+1) + Mx*j];		// Neumann
            } else if (i == Mx - 1) {		// Bordo destro
                rhs_val = 2.0*rx * adi->U_star[(i-1) + Mx*j] + (1.0 - 2.0*rx) * adi->U_star[i + Mx*j];		// Neumann
            } else {		// Interno
                rhs_val = rx * adi->U_star[(i-1) + Mx*j] + (1.0 - 2.0*rx) * adi->U_star[i + Mx*j] + rx * adi->U_star[(i+1) + Mx*j];		// Schema centrale
            }

            adi->RHS2[i + Mx*j] = rhs_val;		// Salva RHS2
        }
    }

    for (int j = 0; j < My; j++) {		// Costruzione matrice y
        adi->ay[j] = -ry;		// Sotto
        adi->by[j] = 1.0 + 2.0*ry;		// Diagonale
        adi->cy[j] = -ry;		// Sopra
    }

    adi->ay[0] = 0.0;		// Bordo basso
    adi->cy[0] = -2.0*ry;		// Neumann
    adi->ay[My-1] = -2.0*ry;		// Bordo alto
    adi->cy[My-1] = 0.0;		// Neumann

    for (int i = 0; i < Mx; i++) {		// Risolve lungo y
        double *rhs_col = (double*) malloc(My * sizeof(double));		// Colonna RHS
        double *sol_col = (double*) malloc(My * sizeof(double));		// Soluzione colonna

        for (int j = 0; j < My; j++) {		// Estrazione colonna
            rhs_col[j] = adi->RHS2[i + Mx*j];		// Copia valori
        }

        thomas_solve(adi->ay, adi->by, adi->cy, rhs_col, sol_col, My);		// Sistema y

        for (int j = 0; j < My; j++) {		// Scrittura risultato
            u[i + Mx*j] = sol_col[j];		// Aggiorna soluzione
        }

        free(rhs_col);		// Libera
        free(sol_col);		// Libera
    }

    free(U);		// Libera vista 2D
}

/*
 * Libera la memoria associata alla struttura ADI.
 */
void adi_free(ADI *adi) {
    if (adi) {		// Controllo validità
        free(adi->ax);		// Libera ax
        free(adi->bx);		// Libera bx
        free(adi->cx);		// Libera cx
        free(adi->ay);		// Libera ay
        free(adi->by);		// Libera by
        free(adi->cy);		// Libera cy
        free(adi->RHS);		// Libera RHS
        free(adi->RHS2);		// Libera RHS2
        free(adi->U_star);		// Libera U_star
        free(adi);		// Libera struttura
    }
}
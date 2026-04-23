#include "diagnostics.h"		// Definizione struct Diagnostics e prototipi
#include "operators.h"		// Operatori discreti (gradienti)
#include <stdlib.h>		// malloc, free
#include <stdio.h>		// fprintf
#include <math.h>		// funzioni matematiche

Diagnostics* diagnostics_create(int Nsteps) {
    Diagnostics *diag = (Diagnostics*) malloc(sizeof(Diagnostics));		// Alloca struttura principale
    
    if (!diag) {		// Controllo errore allocazione
        fprintf(stderr, "ERROR: Failed to allocate Diagnostics\n");		// Stampa errore
        return NULL;		// Esce
    }
    
    diag->t  = (double*) malloc((Nsteps + 1) * sizeof(double));		// Array tempi
    diag->mC = (double*) malloc((Nsteps + 1) * sizeof(double));		// Massa totale C
    diag->mF = (double*) malloc((Nsteps + 1) * sizeof(double));		// Massa totale F
    diag->En = (double*) malloc((Nsteps + 1) * sizeof(double));		// Energia discreta
    
    if (!diag->t || !diag->mC || !diag->mF || !diag->En) {		// Verifica allocazioni
        fprintf(stderr, "ERROR: Failed to allocate Diagnostics arrays\n");		// Errore
        diagnostics_free(diag);		// Libera memoria
        return NULL;		// Esce con errore
    }
    
    diag->step = 0;		// Step iniziale
    
    return diag;		// Restituisce struttura
}

double trap2d(const double *u, const Params *p) {
    // Quadratura trapezoidale 2D: pesi 1 interno, 1/2 bordi, 1/4 angoli
    
    int Mx = p->Mx;		// Numero nodi x
    int My = p->My;		// Numero nodi y
    double hx = p->hx;		// Passo spaziale x
    double hy = p->hy;		// Passo spaziale y
    
    double sum = 0.0;		// Accumulatore
    
    for (int j = 0; j < My; j++) {		// Loop su y
        for (int i = 0; i < Mx; i++) {		// Loop su x
            
            double weight = 1.0;		// Peso nodo interno
            
            if (i == 0 || i == Mx - 1) weight *= 0.5;		// Bordi verticali
            if (j == 0 || j == My - 1) weight *= 0.5;		// Bordi orizzontali
            
            sum += weight * u[i + Mx*j];		// Somma pesata
        }
    }
    
    return hx * hy * sum;		// Moltiplica per area
}

void diagnostics_record(Diagnostics *diag, const double *C, const double *F,
                        const Operators *op, const Params *p, double t) {
    
    int M = p->Mx * p->My;		// Numero totale nodi
    int step = diag->step;		// Step corrente
    
    diag->t[step] = t;		// Salva tempo
    diag->mC[step] = trap2d(C, p);		// Massa C
    diag->mF[step] = trap2d(F, p);		// Massa F
    
    // Energia: E = 0.5*(dC*(||∇C||²) + ||F||²)*hx*hy
    
    double *gx_C = (double*) malloc(M * sizeof(double));		// Gradiente C in x
    double *gy_C = (double*) malloc(M * sizeof(double));		// Gradiente C in y
    
    apply_gradient_x_2d(gx_C, C, op, p);		// ∂C/∂x
    apply_gradient_y_2d(gy_C, C, op, p);		// ∂C/∂y
    
    double norm_grad_C = 0.0;		// ||∇C||²
    double norm_F = 0.0;		// ||F||²
    
    for (int i = 0; i < M; i++) {		// Loop nodi
        norm_grad_C += gx_C[i]*gx_C[i] + gy_C[i]*gy_C[i];		// Somma gradienti
        norm_F += F[i]*F[i];		// Somma F²
    }
    
    diag->En[step] = 0.5 * (p->dC * norm_grad_C + norm_F) * p->hx * p->hy;		// Energia
    
    free(gx_C);		// Libera gradiente x
    free(gy_C);		// Libera gradiente y
    
    diag->step++;		// Incrementa step
}

void diagnostics_free(Diagnostics *diag) {
    if (diag) {		// Controllo validità
        free(diag->t);		// Libera tempi
        free(diag->mC);		// Libera massa C
        free(diag->mF);		// Libera massa F
        free(diag->En);		// Libera energia
        free(diag);		// Libera struttura
    }
}
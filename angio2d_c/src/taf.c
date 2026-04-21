#include "taf.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

TAF* taf_compute(const Params *p, const Grid *g) {
    if (!p || !g) {
        fprintf(stderr, "ERROR: taf_compute received NULL pointer\n");
        return NULL;
    }
    
    TAF *t = (TAF*) malloc(sizeof(TAF));
    if (!t) {
        fprintf(stderr, "ERROR: Failed to allocate TAF\n");
        return NULL;
    }
    
    int M = p->Mx * p->My;
    
    t->T = (double*) malloc(M * sizeof(double));
    t->Tx = (double*) malloc(M * sizeof(double));
    t->Ty = (double*) malloc(M * sizeof(double));
    t->phi_x = (double*) malloc(M * sizeof(double));
    t->phi_y = (double*) malloc(M * sizeof(double));
    
    if (!t->T || !t->Tx || !t->Ty || !t->phi_x || !t->phi_y) {
        fprintf(stderr, "ERROR: Failed to allocate TAF arrays\n");
        free(t->T);
        free(t->Tx);
        free(t->Ty);
        free(t->phi_x);
        free(t->phi_y);
        free(t);
        return NULL;
    }
    
    t->Mx = p->Mx;
    t->My = p->My;
    
    double inv_eps = 1.0 / p->epsilon;
    
    // Calcola T, Tx, Ty, phi_x, phi_y per ogni punto della griglia
    for (int ij = 0; ij < M; ij++) {
        double dx = g->X[ij] - p->Lx;
        double dy = g->Y[ij] - p->Ly / 2.0;
        
        // T = exp(-1/epsilon * (dx^2 + dy^2))
        double r2 = dx*dx + dy*dy;
        t->T[ij] = exp(-inv_eps * r2);
        
        // Tx = -2/epsilon * (X-Lx) * T
        t->Tx[ij] = -2.0 * inv_eps * dx * t->T[ij];
        
        // Ty = -2/epsilon * (Y-Ly/2) * T
        t->Ty[ij] = -2.0 * inv_eps * dy * t->T[ij];
        
        // phi_x = Tx / (1 + alpha4*T)
        // phi_y = Ty / (1 + alpha4*T)
        double denom = 1.0 + p->alpha4 * t->T[ij];
        t->phi_x[ij] = t->Tx[ij] / denom;
        t->phi_y[ij] = t->Ty[ij] / denom;
    }
    
    return t;
}

void taf_free(TAF *t) {
    if (t) {
        free(t->T);
        free(t->Tx);
        free(t->Ty);
        free(t->phi_x);
        free(t->phi_y);
        free(t);
    }
}

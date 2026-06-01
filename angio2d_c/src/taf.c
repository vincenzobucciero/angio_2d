#include "taf.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

/*
 * Compute the analytical TAF field and related auxiliary arrays.
 *
 * For each grid node we build:
 * - T      = TAF profile (Gaussian)
 * - Tx,Ty  = analytical gradients of T
 * - phi_x,phi_y = gradients of the auxiliary potential phi
 *
 * Inputs:
 *   p = model parameters
 *   g = Cartesian grid
 *
 * Returns:
 *   pointer to an initialized TAF struct, or NULL on error
 */
TAF* taf_compute(const Params *p, const Grid *g) {
    if (!p || !g) {		// validate input pointers
        fprintf(stderr, "ERROR: taf_compute received NULL pointer\n");
        return NULL;
    }
    
    TAF *t = (TAF*) malloc(sizeof(TAF));		// allocate main TAF struct
    if (!t) {		// allocation check
        fprintf(stderr, "ERROR: Failed to allocate TAF\n");
        return NULL;
    }
    
    int M = p->Mx * p->My;		// total number of grid nodes
    
    t->T = (double*) malloc(M * sizeof(double));
    t->Tx = (double*) malloc(M * sizeof(double));
    t->Ty = (double*) malloc(M * sizeof(double));
    t->phi_x = (double*) malloc(M * sizeof(double));
    t->phi_y = (double*) malloc(M * sizeof(double));
    
    if (!t->T || !t->Tx || !t->Ty || !t->phi_x || !t->phi_y) {		// allocation check
        fprintf(stderr, "ERROR: Failed to allocate TAF arrays\n");
        free(t->T);
        free(t->Tx);
        free(t->Ty);
        free(t->phi_x);
        free(t->phi_y);
        free(t);
        return NULL;
    }
    
    t->Mx = p->Mx;        // store grid dims
    t->My = p->My;
    
    double inv_eps = 1.0 / p->epsilon;		// precompute 1/epsilon
    
    for (int ij = 0; ij < M; ij++) {		    // iterate over all grid nodes
        double dx = g->X[ij] - p->Lx;		    // horizontal distance from tumor center
        double dy = g->Y[ij] - p->Ly / 2.0;		// vertical distance from tumor center
        
        double r2 = dx*dx + dy*dy;          // squared radius
        t->T[ij] = exp(-inv_eps * r2);      // Gaussian TAF profile
        
        t->Tx[ij] = -2.0 * inv_eps * dx * t->T[ij];    // analytical dT/dx
        t->Ty[ij] = -2.0 * inv_eps * dy * t->T[ij];    // analytical dT/dy
        
        double denom = 1.0 + p->alpha4 * t->T[ij];    // denominator for phi
        t->phi_x[ij] = t->Tx[ij] / denom;    // phi_x = Tx/(1+alpha4*T)
        t->phi_y[ij] = t->Ty[ij] / denom;    // phi_y = Ty/(1+alpha4*T)
    }
    
    return t;		// return pointer to initialized TAF struct
}

/* Free memory associated with a TAF struct. */
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
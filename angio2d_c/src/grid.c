#include "grid.h"
#include <stdlib.h>
#include <stdio.h>

Grid* grid_create(const Params *p) {
    if (!p) {
        fprintf(stderr, "ERROR: grid_create received NULL Params\n");
        return NULL;
    }
    
    Grid *g = (Grid*) malloc(sizeof(Grid));
    if (!g) {
        fprintf(stderr, "ERROR: Failed to allocate Grid\n");
        return NULL;
    }
    
    int M = p->Mx * p->My;
    
    g->X = (double*) malloc(M * sizeof(double));
    g->Y = (double*) malloc(M * sizeof(double));
    
    if (!g->X || !g->Y) {
        fprintf(stderr, "ERROR: Failed to allocate coordinate arrays\n");
        free(g->X);
        free(g->Y);
        free(g);
        return NULL;
    }
    
    g->Mx = p->Mx;
    g->My = p->My;
    g->hx = p->hx;
    g->hy = p->hy;
    
    // MATLAB: x = linspace(0, Lx, Mx)
    // Equivalente: x[i] = i * hx per i = 0..Mx-1
    double *x = (double*) malloc(p->Mx * sizeof(double));
    double *y = (double*) malloc(p->My * sizeof(double));
    
    for (int i = 0; i < p->Mx; i++) {
        x[i] = i * p->hx;
    }
    for (int j = 0; j < p->My; j++) {
        y[j] = j * p->hy;
    }
    
    // MATLAB: [X, Y] = meshgrid(x, y); X = X'; Y = Y';
    // Riempire 2D grid in ordine riga-major: idx = i + Mx*j
    for (int i = 0; i < p->Mx; i++) {
        for (int j = 0; j < p->My; j++) {
            int idx = i + p->Mx * j;
            g->X[idx] = x[i];
            g->Y[idx] = y[j];
        }
    }
    
    free(x);
    free(y);
    
    return g;
}

void grid_free(Grid *g) {
    if (g) {
        free(g->X);
        free(g->Y);
        free(g);
    }
}

#include "grid.h"       
#include <stdlib.h>
#include <stdio.h>

/*
 * Create and initialize the 2D grid.
 *
 * Builds the uniform Cartesian grid coordinates for the domain:
 * - X = x coordinate of every node
 * - Y = y coordinate of every node
 *
 * Coordinates are stored as 1D arrays using linear index:
 *     idx = i + Mx * j
 *
 * Input:
 *   p = numeric parameters struct
 *
 * Returns:
 *   pointer to an allocated and initialized Grid, or NULL on error
 */
Grid* grid_create(const Params *p) {
    if (!p) {        // ensure params pointer is valid
        fprintf(stderr, "ERROR: grid_create received NULL Params\n");
        return NULL;
    }

    Grid *g = (Grid*) malloc(sizeof(Grid));        // allocate main Grid struct
    if (!g) {        // allocation check
        fprintf(stderr, "ERROR: Failed to allocate Grid\n");
        return NULL;
    }

    int M = p->Mx * p->My;        // total number of grid nodes

    g->X = (double*) malloc(M * sizeof(double));        // x coordinates array for 2D grid
    g->Y = (double*) malloc(M * sizeof(double));        // y coordinates array for 2D grid

    if (!g->X || !g->Y) {        // check coordinate array allocations
        fprintf(stderr, "ERROR: Failed to allocate coordinate arrays\n");
        free(g->X);
        free(g->Y);
        free(g);
        return NULL;
    }

    g->Mx = p->Mx;        // store grid dimensions
    g->My = p->My;
    g->hx = p->hx;        // store spatial step in x
    g->hy = p->hy;        // store spatial step in y

    // MATLAB: x = linspace(0, Lx, Mx)
    // Equivalent: x[i] = i * hx for i = 0..Mx-1
    double *x = (double*) malloc(p->Mx * sizeof(double));        // 1D x coordinates vector
    double *y = (double*) malloc(p->My * sizeof(double));        // 1D y coordinates vector

    for (int i = 0; i < p->Mx; i++) {        // build x vector
        x[i] = i * p->hx;        // i-th node along x
    }
    for (int j = 0; j < p->My; j++) {        // build y vector
        y[j] = j * p->hy;        // j-th node along y
    }

    // MATLAB: [X, Y] = meshgrid(x, y); X = X'; Y = Y';
    // Fill 2D grid in row-major order: idx = i + Mx*j
    for (int i = 0; i < p->Mx; i++) {        // loop over x nodes
        for (int j = 0; j < p->My; j++) {        // loop over y nodes
            int idx = i + p->Mx * j;        // linear index for (i,j)
            g->X[idx] = x[i];        // x coordinate at node
            g->Y[idx] = y[j];        // y coordinate at node
        }
    }

    free(x);        // free temporary x vector
    free(y);        // free temporary y vector

    return g;        // return initialized grid
}

/* Free memory associated with the Grid. */
void grid_free(Grid *g) {
    if (g) {
        free(g->X);
        free(g->Y);
        free(g);
    }
}
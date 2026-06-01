#ifndef GRID_H
#define GRID_H

#include "params.h"

/**
 * @file grid.h
 * @brief Uniform 2D structured grid (linspace equivalent)
 * 
 * MATLAB:
 *   hx = Lx/(Mx-1);
 *   x = linspace(0, Lx, Mx)';
 *   [X, Y] = meshgrid(x, y);
 *   X = X'; Y = Y';  % Mx × My
 */

typedef struct {
    double *X, *Y;      // 2D coordinates (length Mx*My)
    int Mx, My;
    double hx, hy;
} Grid;

/**
 * Allocate and initialize the grid
 * 
 * Input: Params p (contains Lx, Ly, Mx, My, hx, hy)
 * Output: Grid* with X[], Y[] arrays
 * 
 * Linear indexing: (i,j) -> idx = i + Mx*j.
 * This matches MATLAB's column-wise flattening for arrays shaped Mx x My.
 */
Grid* grid_create(const Params *p);

/**
 * Deallocate the grid
 */
void grid_free(Grid *g);

#endif // GRID_H

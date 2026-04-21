#ifndef GRID_H
#define GRID_H

#include "params.h"

/**
 * @file grid.h
 * @brief Griglia strutturata uniforme 2D (linspace equivalente)
 * 
 * MATLAB:
 *   hx = Lx/(Mx-1);
 *   x = linspace(0, Lx, Mx)';
 *   [X, Y] = meshgrid(x, y);
 *   X = X'; Y = Y';  % Mx × My
 */

typedef struct {
    double *X, *Y;      // Coordinate 2D (lunghezza Mx*My)
    int Mx, My;
    double hx, hy;
} Grid;

/**
 * Alloca e inizializza griglia
 * 
 * Input: Params p (contiene Lx, Ly, Mx, My, hx, hy)
 * Output: Grid* con X[], Y[] arrays
 * 
 * Indexing: (i,j) -> idx = i + Mx*j  (riga-major, compatibile MATLAB column-major)
 */
Grid* grid_create(const Params *p);

/**
 * Dealloca griglia
 */
void grid_free(Grid *g);

#endif // GRID_H

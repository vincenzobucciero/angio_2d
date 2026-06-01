#ifndef TAF_H
#define TAF_H

#include "params.h"
#include "grid.h"

/**
 * @file taf.h
 * @brief Precomputed Gaussian TAF (Tumor Angiogenic Factor) field
 * 
 * MATLAB:
 *   T = exp(-1/epsilon * ((X-Lx)^2 + (Y-Ly/2)^2))
 *   Tx = -2/epsilon * (X-Lx) * T
 *   Ty = -2/epsilon * (Y-Ly/2) * T
 *   phi_x = Tx / (1 + alpha4*T)
 *   phi_y = Ty / (1 + alpha4*T)
 */

typedef struct {
    double *T;          // TAF field (Mx*My)
    double *Tx, *Ty;    // TAF gradients (Mx*My)
    double *phi_x;      // Saturated x potential (Mx*My)
    double *phi_y;      // Saturated y potential (Mx*My)
    int Mx, My;
} TAF;

/**
 * Compute TAF field and derivatives from the grid
 */
TAF* taf_compute(const Params *p, const Grid *g);

/**
 * Deallocate TAF
 */
void taf_free(TAF *t);

#endif // TAF_H

#ifndef TAF_H
#define TAF_H

#include "params.h"
#include "grid.h"

/**
 * @file taf.h
 * @brief Campo TAF (Tumor Angiogenic Factor) gaussiano precalcolato
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
    double *Tx, *Ty;    // Gradienti TAF (Mx*My)
    double *phi_x;      // Potenziale saturo x (Mx*My)
    double *phi_y;      // Potenziale saturo y (Mx*My)
    int Mx, My;
} TAF;

/**
 * Calcola campo TAF e derivate da griglia
 */
TAF* taf_compute(const Params *p, const Grid *g);

/**
 * Dealloca TAF
 */
void taf_free(TAF *t);

#endif // TAF_H

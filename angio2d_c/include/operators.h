#ifndef OPERATORS_H
#define OPERATORS_H

#include "params.h"

/**
 * @file operators.h
 * @brief Operatori spaziali 1D e 2D (Laplaciano, Gradienti)
 * 
 * MATLAB build_1d_ops(M, h):
 *   L = tridiag(1, -2, 1) / h^2
 *   L(1,2)     = 2/h^2   (BC Neumann sinistro: u_0 = u_2)
 *   L(M,M-1)   = 2/h^2   (BC Neumann destro: u_{M+1} = u_{M-1})
 *   
 *   G: centrale interno (G(i, i±1) = ±1/(2h))
 *      BORDI G(1,:) e G(M,:) rimangono ZERO
 */

typedef struct {
    int Mx, My;
    double hx, hy;
    double inv_hx2, inv_hy2;
    double inv_2hx, inv_2hy;
} Operators;

/**
 * Costruisce operatori 1D (Laplaciano + Gradienti) con BC Neumann
 */
Operators* operators_create(const Params *p);

/**
 * Applica Laplaciano 2D: out = (I⊗Lx + Ly⊗I) * in
 * Eseguito implicitamente via stencil, no matrice globale.
 * 
 * input:  vettore 1D di lunghezza Mx*My (ordine riga-major)
 * output: vettore 1D di lunghezza Mx*My
 */
void apply_laplacian_2d(double *out, const double *in, 
                        const Operators *op, const Params *p);

/**
 * Applica Gradiente X: out = (I⊗Gx) * in
 */
void apply_gradient_x_2d(double *out, const double *in,
                         const Operators *op, const Params *p);

/**
 * Applica Gradiente Y: out = (Gy⊗I) * in
 */
void apply_gradient_y_2d(double *out, const double *in,
                         const Operators *op, const Params *p);

/**
 * Dealloca operatori
 */
void operators_free(Operators *op);

#endif // OPERATORS_H

#ifndef OPERATORS_H
#define OPERATORS_H

#include "params.h"

/**
 * @file operators.h
 * @brief 1D and 2D spatial operators (Laplacian, gradients)
 * 
 * MATLAB build_1d_ops(M, h):
 *   L = tridiag(1, -2, 1) / h^2
 *   L(1,2)     = 2/h^2   (left Neumann BC: u_0 = u_2)
 *   L(M,M-1)   = 2/h^2   (right Neumann BC: u_{M+1} = u_{M-1})
 *   
 *   G: centered stencil in the interior (G(i, i±1) = ±1/(2h))
 *      BOUNDARY rows G(1,:) and G(M,:) remain ZERO
 */

typedef struct {
    int Mx, My;
    double hx, hy;
    double inv_hx2, inv_hy2;
    double inv_2hx, inv_2hy;
} Operators;

/**
 * Build 1D operators (Laplacian + gradients) with Neumann BCs
 */
Operators* operators_create(const Params *p);

/**
 * Apply 2D Laplacian: out = (I⊗Lx + Ly⊗I) * in
 * Implemented implicitly via stencil, no global matrix.
 * 
 * input:  1D vector of length Mx*My (row-major order)
 * output: 1D vector of length Mx*My
 */
void apply_laplacian_2d(double *out, const double *in, 
                        const Operators *op, const Params *p);

/**
 * Apply X gradient: out = (I⊗Gx) * in
 */
void apply_gradient_x_2d(double *out, const double *in,
                         const Operators *op, const Params *p);

/**
 * Apply Y gradient: out = (Gy⊗I) * in
 */
void apply_gradient_y_2d(double *out, const double *in,
                         const Operators *op, const Params *p);

/**
 * Deallocate operators
 */
void operators_free(Operators *op);

#endif // OPERATORS_H

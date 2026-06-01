#ifndef ADI_H
#define ADI_H

#include "params.h"

/*
 * ADI (Alternating Direction Implicit) structure.
 *
 * Contains all data needed to perform a diffusive step
 * with a 2D ADI scheme:
 *
 * - ax, bx, cx = tridiagonal coefficients along x
 * - ay, by, cy = tridiagonal coefficients along y
 *
 * - RHS  = first half-step right-hand side (implicit in x)
 * - RHS2 = second half-step right-hand side (implicit in y)
 *
 * - U_star = intermediate solution after the first sweep
 *
 * - Mx, My = grid dimensions
 */
typedef struct {
    double *ax, *bx, *cx;		/* Tridiagonal matrix along x */
    double *ay, *by, *cy;		/* Tridiagonal matrix along y */
    
    double *RHS;			/* First half-step RHS */
    double *RHS2;			/* Second half-step RHS */
    
    double *U_star;			/* Intermediate solution */
    double *thomas_c_star;   /* Per-thread Thomas workspace */
    double *thomas_d_star;   /* Per-thread Thomas workspace */
    double *rhs_col_buffer;  /* Per-thread RHS column buffer */
    double *sol_col_buffer;  /* Per-thread solution column buffer */
    int max_threads;         /* Maximum supported thread count */
    int thomas_nmax;         /* Maximum Thomas system size */
    /* OPTIMIZATION: Cache-line padding to prevent false sharing between threads */
    int padded_nmax;         /* Padded size for cache-line alignment (nmax + 8 doubles) */
    int padded_my;           /* Padded My for cache-line alignment (My + 8 doubles) */
    
    int Mx, My;			/* Grid dimensions */
} ADI;

/*
 * Allocate and initialize the ADI structure.
 *
 * Input:
 *   p = model parameters
 *
 * Output:
 *   pointer to a ready-to-use ADI object
 *   or NULL on error
 */
ADI* adi_create(const Params *p);

/*
 * Free all memory associated with the ADI structure.
 */
void adi_free(ADI *adi);

/*
 * Solve a tridiagonal linear system using the Thomas method.
 *
 * Sistema:
 *   Ax = d
 *
 * where A is defined by:
 *   a = subdiagonal
 *   b = main diagonal
 *   c = superdiagonal
 *
 * Input:
 *   a, b, c = tridiagonal coefficients
 *   d       = right-hand side
 *   n       = system size
 *
 * Output:
 *   x = system solution
 */
void thomas_solve(const double *a, const double *b, const double *c,
                  const double *d, double *x, int n);

void thomas_solve_ws(const double *a, const double *b, const double *c,
                     const double *d, double *x, int n,
                     double *c_star, double *d_star);

/*
 * Perform a diffusive step using the ADI scheme.
 *
 * Solves:
 *   ∂u/∂t = d Δu
 *
 * with the Peaceman-Rachford scheme:
 *   1) implicit in x, explicit in y
 *   2) explicit in x, implicit in y
 *
 * Input:
 *   u       = field to update (in place)
 *   p       = simulation parameters
 *   adi     = ADI structure with allocated buffers
 *   d_coeff = diffusion coefficient
 *   tau     = time step
 */
void adi_step(double *u, const Params *p, ADI *adi, double d_coeff, double tau);

#endif // ADI_H

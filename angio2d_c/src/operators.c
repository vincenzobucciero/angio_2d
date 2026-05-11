#include "operators.h"
#include <stdlib.h>
#include <stdio.h>
#ifdef _OPENMP
#include <omp.h>
#endif

Operators* operators_create(const Params *p) {
    if (!p) {
        fprintf(stderr, "ERROR: operators_create received NULL Params\n");
        return NULL;
    }

    Operators *op = (Operators*) malloc(sizeof(Operators));
    if (!op) {
        fprintf(stderr, "ERROR: Failed to allocate Operators\n");
        return NULL;
    }

    op->Mx = p->Mx;
    op->My = p->My;
    op->hx = p->hx;
    op->hy = p->hy;
    op->inv_hx2 = 1.0 / (p->hx * p->hx);
    op->inv_hy2 = 1.0 / (p->hy * p->hy);
    op->inv_2hx = 0.5 / p->hx;
    op->inv_2hy = 0.5 / p->hy;

    return op;
}

void apply_laplacian_2d(double *out, const double *in,
                        const Operators *op, const Params *p) {
    (void) p;
    const int Mx = op->Mx;
    const int My = op->My;
    const double inv_hx2 = op->inv_hx2;
    const double inv_hy2 = op->inv_hy2;

    /* OPTIMIZATION: Removed if(Mx*My > 1024) guard - always parallelize
       Added collapse(2) for better work distribution across 2D grid
       Laplacian is 2D stencil operation, perfect for 2D thread grid */
    #pragma omp parallel for collapse(2) schedule(static)
    for (int j = 0; j < My; j++) {
        for (int i = 0; i < Mx; i++) {
            const int idx = i + Mx * j;
            const int im = (i == 0) ? 1 : (i - 1);
            const int ip = (i == Mx - 1) ? (Mx - 2) : (i + 1);
            const int jm = (j == 0) ? 1 : (j - 1);
            const int jp = (j == My - 1) ? (My - 2) : (j + 1);

            const double lap_x = (in[im + Mx * j] - 2.0 * in[idx] + in[ip + Mx * j]) * inv_hx2;
            const double lap_y = (in[i + Mx * jm] - 2.0 * in[idx] + in[i + Mx * jp]) * inv_hy2;
            out[idx] = lap_x + lap_y;
        }
    }
}

void apply_gradient_x_2d(double *out, const double *in,
                         const Operators *op, const Params *p) {
    (void) p;
    const int Mx = op->Mx;
    const int My = op->My;
    const double inv_2hx = op->inv_2hx;

    /* OPTIMIZATION: Removed if(Mx*My > 1024) guard - always parallelize
       1D row-wise gradient operation, easily parallelizable */
    #pragma omp parallel for schedule(static)
    for (int j = 0; j < My; j++) {
        out[0 + Mx * j] = 0.0;
        for (int i = 1; i < Mx - 1; i++) {
            const int idx = i + Mx * j;
            out[idx] = (in[(i + 1) + Mx * j] - in[(i - 1) + Mx * j]) * inv_2hx;
        }
        out[(Mx - 1) + Mx * j] = 0.0;
    }
}

void apply_gradient_y_2d(double *out, const double *in,
                         const Operators *op, const Params *p) {
    (void) p;
    const int Mx = op->Mx;
    const int My = op->My;
    const double inv_2hy = op->inv_2hy;

    /* OPTIMIZATION: Removed if(Mx*My > 1024) guard - always parallelize
       1D column-wise gradient operation, easily parallelizable */
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < Mx; i++) {
        out[i + Mx * 0] = 0.0;
        for (int j = 1; j < My - 1; j++) {
            const int idx = i + Mx * j;
            out[idx] = (in[i + Mx * (j + 1)] - in[i + Mx * (j - 1)]) * inv_2hy;
        }
        out[i + Mx * (My - 1)] = 0.0;
    }
}

void operators_free(Operators *op) {
    if (op) {
        free(op);
    }
}

#include "adi.h"
#ifdef USE_CUDA
#include "adi_cuda.h"
#endif
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#ifdef _OPENMP
#include <omp.h>
#endif

/* OPTIMIZATION: Cache-line padding constant (64 bytes typical L1 = 8 doubles)
   Prevents false sharing: thread buffers allocated at tid * (size + PAD) offset
   Ensures each thread's data resides on separate cache lines */
#define CACHE_LINE_PAD 8

ADI* adi_create(const Params *p) {
    ADI *adi = (ADI*) malloc(sizeof(ADI));
    if (!adi) {
        fprintf(stderr, "ERROR: Failed to allocate ADI\n");
        return NULL;
    }

    adi->ax = (double*) malloc(p->Mx * sizeof(double));
    adi->bx = (double*) malloc(p->Mx * sizeof(double));
    adi->cx = (double*) malloc(p->Mx * sizeof(double));

    adi->ay = (double*) malloc(p->My * sizeof(double));
    adi->by = (double*) malloc(p->My * sizeof(double));
    adi->cy = (double*) malloc(p->My * sizeof(double));

    adi->RHS = (double*) malloc(p->Mx * p->My * sizeof(double));
    adi->RHS2 = (double*) malloc(p->Mx * p->My * sizeof(double));
    adi->U_star = (double*) malloc(p->Mx * p->My * sizeof(double));

#ifdef _OPENMP
    adi->max_threads = omp_get_max_threads();
#else
    adi->max_threads = 1;
#endif
    adi->thomas_nmax = (p->Mx > p->My) ? p->Mx : p->My;
    
    /* OPTIMIZATION: Allocate with cache-line padding to avoid false sharing
       Each thread gets buffer at offset: tid * (size + CACHE_LINE_PAD)
       This ensures buffers don't share cache lines between threads
       Without padding: threads on different cores invalidate each other's cache */
    int padded_nmax = adi->thomas_nmax + CACHE_LINE_PAD;
    int padded_my = p->My + CACHE_LINE_PAD;
    adi->thomas_c_star = (double*) malloc((size_t)adi->max_threads * (size_t)padded_nmax * sizeof(double));
    adi->thomas_d_star = (double*) malloc((size_t)adi->max_threads * (size_t)padded_nmax * sizeof(double));
    adi->rhs_col_buffer = (double*) malloc((size_t)adi->max_threads * (size_t)padded_my * sizeof(double));
    adi->sol_col_buffer = (double*) malloc((size_t)adi->max_threads * (size_t)padded_my * sizeof(double));
    
    /* Store padded sizes for later indexing */
    adi->padded_nmax = padded_nmax;
    adi->padded_my = padded_my;

    if (!adi->ax || !adi->bx || !adi->cx ||
        !adi->ay || !adi->by || !adi->cy ||
        !adi->RHS || !adi->RHS2 || !adi->U_star ||
        !adi->thomas_c_star || !adi->thomas_d_star ||
        !adi->rhs_col_buffer || !adi->sol_col_buffer) {
        fprintf(stderr, "ERROR: Failed to allocate ADI arrays\n");
        adi_free(adi);
        return NULL;
    }

    adi->Mx = p->Mx;
    adi->My = p->My;

    return adi;
}

void thomas_solve_ws(const double *a, const double *b, const double *c,
                     const double *d, double *x, int n,
                     double *c_star, double *d_star) {
    c_star[0] = c[0] / b[0];
    d_star[0] = d[0] / b[0];

    for (int i = 1; i < n; i++) {
        const double denom = b[i] - a[i] * c_star[i - 1];
        if (i < n - 1) {
            c_star[i] = c[i] / denom;
        }
        d_star[i] = (d[i] - a[i] * d_star[i - 1]) / denom;
    }

    x[n - 1] = d_star[n - 1];
    for (int i = n - 2; i >= 0; i--) {
        x[i] = d_star[i] - c_star[i] * x[i + 1];
    }
}

void thomas_solve(const double *a, const double *b, const double *c,
                  const double *d, double *x, int n) {
    double *c_star = (double*) malloc((size_t)n * sizeof(double));
    double *d_star = (double*) malloc((size_t)n * sizeof(double));
    if (!c_star || !d_star) {
        free(c_star);
        free(d_star);
        return;
    }
    thomas_solve_ws(a, b, c, d, x, n, c_star, d_star);
    free(c_star);
    free(d_star);
}

void adi_step(double *u, const Params *p, ADI *adi, double d_coeff, double tau) {
    const int Mx = p->Mx;
    const int My = p->My;

#ifdef USE_CUDA
    static int cuda_fallback_warned = 0;
    const char *backend = getenv("ANGIO2D_BACKEND");
    if (backend && strcmp(backend, "cuda") == 0) {
        int cuda_rc = adi_cuda_step(u, Mx, My, p->hx, p->hy, d_coeff, tau);
        if (cuda_rc == 0) {
            return;
        }
        if (!cuda_fallback_warned) {
            fprintf(stderr, "WARN: CUDA ADI path unavailable (rc=%d), falling back to CPU ADI.\n", cuda_rc);
            cuda_fallback_warned = 1;
        }
    }
#endif

    const double tau2 = tau / 2.0;
    const double rx = d_coeff * tau2 / (p->hx * p->hx);
    const double ry = d_coeff * tau2 / (p->hy * p->hy);

    for (int i = 0; i < Mx; i++) {
        adi->ax[i] = -rx;
        adi->bx[i] = 1.0 + 2.0 * rx;
        adi->cx[i] = -rx;
    }
    adi->ax[0] = 0.0;
    adi->cx[0] = -2.0 * rx;
    adi->ax[Mx - 1] = -2.0 * rx;
    adi->cx[Mx - 1] = 0.0;

    for (int j = 0; j < My; j++) {
        adi->ay[j] = -ry;
        adi->by[j] = 1.0 + 2.0 * ry;
        adi->cy[j] = -ry;
    }
    adi->ay[0] = 0.0;
    adi->cy[0] = -2.0 * ry;
    adi->ay[My - 1] = -2.0 * ry;
    adi->cy[My - 1] = 0.0;

    #pragma omp parallel for if(Mx * My > 1024) schedule(static)
    for (int j = 0; j < My; j++) {
        for (int i = 0; i < Mx; i++) {
            double rhs_val;
            if (j == 0) {
                rhs_val = (1.0 - 2.0 * ry) * u[i + Mx * j] + 2.0 * ry * u[i + Mx * (j + 1)];
            } else if (j == My - 1) {
                rhs_val = 2.0 * ry * u[i + Mx * (j - 1)] + (1.0 - 2.0 * ry) * u[i + Mx * j];
            } else {
                rhs_val = ry * u[i + Mx * (j - 1)] + (1.0 - 2.0 * ry) * u[i + Mx * j] + ry * u[i + Mx * (j + 1)];
            }
            adi->RHS[i + Mx * j] = rhs_val;
        }
    }

    #pragma omp parallel for if(My > 4) schedule(static)
    for (int j = 0; j < My; j++) {
        int tid = 0;
#ifdef _OPENMP
        tid = omp_get_thread_num();
#endif
        /* OPTIMIZATION: Index into padded buffer to prevent cache coherency misses
           Each thread uses buffer at: tid * padded_nmax offset (not tid * nmax)
           This guarantees no cache line sharing between thread buffers */
        double *c_star = &adi->thomas_c_star[tid * adi->padded_nmax];
        double *d_star = &adi->thomas_d_star[tid * adi->padded_nmax];
        thomas_solve_ws(adi->ax, adi->bx, adi->cx,
                        &adi->RHS[Mx * j], &adi->U_star[Mx * j], Mx,
                        c_star, d_star);
    }

    #pragma omp parallel for if(Mx * My > 1024) schedule(static)
    for (int i = 0; i < Mx; i++) {
        for (int j = 0; j < My; j++) {
            double rhs_val;
            if (i == 0) {
                rhs_val = (1.0 - 2.0 * rx) * adi->U_star[i + Mx * j] + 2.0 * rx * adi->U_star[(i + 1) + Mx * j];
            } else if (i == Mx - 1) {
                rhs_val = 2.0 * rx * adi->U_star[(i - 1) + Mx * j] + (1.0 - 2.0 * rx) * adi->U_star[i + Mx * j];
            } else {
                rhs_val = rx * adi->U_star[(i - 1) + Mx * j] + (1.0 - 2.0 * rx) * adi->U_star[i + Mx * j] + rx * adi->U_star[(i + 1) + Mx * j];
            }
            adi->RHS2[i + Mx * j] = rhs_val;
        }
    }

    #pragma omp parallel for if(Mx > 4) schedule(static)
    for (int i = 0; i < Mx; i++) {
        int tid = 0;
#ifdef _OPENMP
        tid = omp_get_thread_num();
#endif
        /* OPTIMIZATION: Use padded offsets for thread-local buffers
           Prevents multiple threads from sharing cache lines during backsolve */
        double *c_star = &adi->thomas_c_star[tid * adi->padded_nmax];
        double *d_star = &adi->thomas_d_star[tid * adi->padded_nmax];
        double *rhs_col = &adi->rhs_col_buffer[tid * adi->padded_my];
        double *sol_col = &adi->sol_col_buffer[tid * adi->padded_my];

        for (int j = 0; j < My; j++) {
            rhs_col[j] = adi->RHS2[i + Mx * j];
        }

        thomas_solve_ws(adi->ay, adi->by, adi->cy, rhs_col, sol_col, My, c_star, d_star);

        for (int j = 0; j < My; j++) {
            u[i + Mx * j] = sol_col[j];
        }
    }
}

void adi_free(ADI *adi) {
    if (adi) {
        free(adi->ax);
        free(adi->bx);
        free(adi->cx);
        free(adi->ay);
        free(adi->by);
        free(adi->cy);
        free(adi->RHS);
        free(adi->RHS2);
        free(adi->U_star);
        free(adi->thomas_c_star);
        free(adi->thomas_d_star);
        free(adi->rhs_col_buffer);
        free(adi->sol_col_buffer);
        free(adi);
    }
}

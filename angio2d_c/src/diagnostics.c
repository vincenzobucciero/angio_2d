#include "diagnostics.h"
#include "operators.h"
#include <stdlib.h>
#include <stdio.h>
#ifdef _OPENMP
#include <omp.h>
#endif

Diagnostics* diagnostics_create(int Nsteps, int M) {
    Diagnostics *diag = (Diagnostics*) malloc(sizeof(Diagnostics));

    if (!diag) {
        fprintf(stderr, "ERROR: Failed to allocate Diagnostics\n");
        return NULL;
    }

    diag->t  = (double*) malloc((Nsteps + 1) * sizeof(double));
    diag->mC = (double*) malloc((Nsteps + 1) * sizeof(double));
    diag->mF = (double*) malloc((Nsteps + 1) * sizeof(double));
    diag->En = (double*) malloc((Nsteps + 1) * sizeof(double));
    diag->gx_C = (double*) malloc((size_t)M * sizeof(double));
    diag->gy_C = (double*) malloc((size_t)M * sizeof(double));

    if (!diag->t || !diag->mC || !diag->mF || !diag->En || !diag->gx_C || !diag->gy_C) {
        fprintf(stderr, "ERROR: Failed to allocate Diagnostics arrays\n");
        diagnostics_free(diag);
        return NULL;
    }

    diag->M = M;
    diag->step = 0;

    return diag;
}

double trap2d(const double *u, const Params *p) {
    int Mx = p->Mx;
    int My = p->My;
    double sum = 0.0;

    #pragma omp parallel for reduction(+:sum) if(Mx * My > 1024) schedule(static)
    for (int j = 0; j < My; j++) {
        for (int i = 0; i < Mx; i++) {
            double weight = 1.0;
            if (i == 0 || i == Mx - 1) weight *= 0.5;
            if (j == 0 || j == My - 1) weight *= 0.5;
            sum += weight * u[i + Mx * j];
        }
    }

    return p->hx * p->hy * sum;
}

void diagnostics_record(Diagnostics *diag, const double *C, const double *F,
                        const Operators *op, const Params *p, double t) {
    int step = diag->step;

    diag->t[step] = t;
    diag->mC[step] = trap2d(C, p);
    diag->mF[step] = trap2d(F, p);

    apply_gradient_x_2d(diag->gx_C, C, op, p);
    apply_gradient_y_2d(diag->gy_C, C, op, p);

    double norm_grad_C = 0.0;
    double norm_F = 0.0;

    #pragma omp parallel for reduction(+:norm_grad_C,norm_F) if(diag->M > 1024) schedule(static)
    for (int i = 0; i < diag->M; i++) {
        norm_grad_C += diag->gx_C[i] * diag->gx_C[i] + diag->gy_C[i] * diag->gy_C[i];
        norm_F += F[i] * F[i];
    }

    diag->En[step] = 0.5 * (p->dC * norm_grad_C + norm_F) * p->hx * p->hy;
    diag->step++;
}

void diagnostics_free(Diagnostics *diag) {
    if (diag) {
        free(diag->t);
        free(diag->mC);
        free(diag->mF);
        free(diag->En);
        free(diag->gx_C);
        free(diag->gy_C);
        free(diag);
    }
}

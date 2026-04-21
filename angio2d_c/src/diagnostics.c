#include "diagnostics.h"
#include "operators.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

Diagnostics* diagnostics_create(int Nsteps) {
    Diagnostics *diag = (Diagnostics*) malloc(sizeof(Diagnostics));
    if (!diag) {
        fprintf(stderr, "ERROR: Failed to allocate Diagnostics\n");
        return NULL;
    }
    
    diag->t = (double*) malloc((Nsteps + 1) * sizeof(double));
    diag->mC = (double*) malloc((Nsteps + 1) * sizeof(double));
    diag->mF = (double*) malloc((Nsteps + 1) * sizeof(double));
    diag->En = (double*) malloc((Nsteps + 1) * sizeof(double));
    
    if (!diag->t || !diag->mC || !diag->mF || !diag->En) {
        fprintf(stderr, "ERROR: Failed to allocate Diagnostics arrays\n");
        diagnostics_free(diag);
        return NULL;
    }
    
    diag->step = 0;
    return diag;
}

double trap2d(const double *u, const Params *p) {
    // Quadratura trapezoide: peso 1 interno, 0.5 bordo, 0.25 angolo
    int Mx = p->Mx;
    int My = p->My;
    double hx = p->hx;
    double hy = p->hy;
    
    double sum = 0.0;
    
    for (int j = 0; j < My; j++) {
        for (int i = 0; i < Mx; i++) {
            double weight = 1.0;
            if (i == 0 || i == Mx - 1) weight *= 0.5;
            if (j == 0 || j == My - 1) weight *= 0.5;
            
            sum += weight * u[i + Mx*j];
        }
    }
    
    return hx * hy * sum;
}

void diagnostics_record(Diagnostics *diag, const double *C, const double *F,
                        const Operators *op, const Params *p, double t) {
    int M = p->Mx * p->My;
    int step = diag->step;
    
    diag->t[step] = t;
    diag->mC[step] = trap2d(C, p);
    diag->mF[step] = trap2d(F, p);
    
    // Energia: 0.5*(dC*(||∇C||²) + ||F||²)*hx*hy
    double *gx_C = (double*) malloc(M * sizeof(double));
    double *gy_C = (double*) malloc(M * sizeof(double));
    
    apply_gradient_x_2d(gx_C, C, op, p);
    apply_gradient_y_2d(gy_C, C, op, p);
    
    double norm_grad_C = 0.0;
    double norm_F = 0.0;
    for (int i = 0; i < M; i++) {
        norm_grad_C += gx_C[i]*gx_C[i] + gy_C[i]*gy_C[i];
        norm_F += F[i]*F[i];
    }
    
    diag->En[step] = 0.5 * (p->dC * norm_grad_C + norm_F) * p->hx * p->hy;
    
    free(gx_C);
    free(gy_C);
    
    diag->step++;
}

void diagnostics_free(Diagnostics *diag) {
    if (diag) {
        free(diag->t);
        free(diag->mC);
        free(diag->mF);
        free(diag->En);
        free(diag);
    }
}

#include "reaction.h"
#include <stdlib.h>
#include <stdio.h>
#ifdef _OPENMP
#include <omp.h>
#endif

ReactionWorkspace* reaction_workspace_create(int M) {
    ReactionWorkspace *ws = (ReactionWorkspace*) malloc(sizeof(ReactionWorkspace));
    if (!ws) {
        fprintf(stderr, "ERROR: Failed to allocate ReactionWorkspace\n");
        return NULL;
    }

    ws->C_rhs = (double*) malloc(M * sizeof(double));
    ws->P_rhs = (double*) malloc(M * sizeof(double));
    ws->Inh_rhs = (double*) malloc(M * sizeof(double));
    ws->F_rhs = (double*) malloc(M * sizeof(double));

    ws->vx = (double*) malloc(M * sizeof(double));
    ws->vy = (double*) malloc(M * sizeof(double));
    ws->div_v = (double*) malloc(M * sizeof(double));

    ws->lap_I = (double*) malloc(M * sizeof(double));
    ws->lap_F = (double*) malloc(M * sizeof(double));

    ws->gx_I = (double*) malloc(M * sizeof(double));
    ws->gy_I = (double*) malloc(M * sizeof(double));
    ws->gx_F = (double*) malloc(M * sizeof(double));
    ws->gy_F = (double*) malloc(M * sizeof(double));
    ws->gx_C = (double*) malloc(M * sizeof(double));
    ws->gy_C = (double*) malloc(M * sizeof(double));

    if (!ws->C_rhs || !ws->P_rhs || !ws->Inh_rhs || !ws->F_rhs ||
        !ws->vx || !ws->vy || !ws->div_v || !ws->lap_I || !ws->lap_F ||
        !ws->gx_I || !ws->gy_I || !ws->gx_F || !ws->gy_F ||
        !ws->gx_C || !ws->gy_C) {
        fprintf(stderr, "ERROR: Failed to allocate workspace arrays\n");
        reaction_workspace_free(ws);
        return NULL;
    }

    ws->M = M;
    return ws;
}

void reaction_compute_rhs(ReactionWorkspace *ws,
                          const double *C, const double *P,
                          const double *Inh, const double *F,
                          const TAF *taf, const Operators *op,
                          const Params *p) {
    int M = ws->M;

    apply_laplacian_2d(ws->lap_I, Inh, op, p);
    apply_laplacian_2d(ws->lap_F, F, op, p);

    apply_gradient_x_2d(ws->gx_I, Inh, op, p);
    apply_gradient_y_2d(ws->gy_I, Inh, op, p);
    apply_gradient_x_2d(ws->gx_F, F, op, p);
    apply_gradient_y_2d(ws->gy_F, F, op, p);
    apply_gradient_x_2d(ws->gx_C, C, op, p);
    apply_gradient_y_2d(ws->gy_C, C, op, p);

    #pragma omp parallel for schedule(static)
    for (int i = 0; i < M; i++) {
        ws->vx[i] = p->alpha2 * ws->gx_I[i] - p->alpha1 * ws->gx_F[i] - p->alpha3 * taf->phi_x[i];
        ws->vy[i] = p->alpha2 * ws->gy_I[i] - p->alpha1 * ws->gy_F[i] - p->alpha3 * taf->phi_y[i];
        ws->div_v[i] = p->alpha2 * ws->lap_I[i] - p->alpha1 * ws->lap_F[i];
    }

    #pragma omp parallel for schedule(static)
    for (int i = 0; i < M; i++) {
        ws->C_rhs[i] = ws->vx[i] * ws->gx_C[i]
                     + ws->vy[i] * ws->gy_C[i]
                     + ws->div_v[i] * C[i]
                     + p->k1 * C[i] * (1.0 - C[i]);

        ws->P_rhs[i] = -p->k3 * P[i] * Inh[i]
                     + p->k4 * taf->T[i] * C[i]
                     + p->k5 * taf->T[i]
                     - p->k6 * P[i];

        ws->Inh_rhs[i] = -p->k3 * P[i] * Inh[i];
        ws->F_rhs[i] = -p->k2 * P[i] * F[i];
    }
}

void reaction_euler_step(double *C, double *P, double *Inh, double *F,
                         const ReactionWorkspace *ws, double dt, int M) {
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < M; i++) {
        C[i] = C[i] + dt * ws->C_rhs[i];
        P[i] = P[i] + dt * ws->P_rhs[i];
        Inh[i] = Inh[i] + dt * ws->Inh_rhs[i];
        F[i] = F[i] + dt * ws->F_rhs[i];
    }
}

void reaction_clamp_positive(double *C, double *P, double *Inh, double *F, int M) {
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < M; i++) {
        if (C[i] < 0.0) C[i] = 0.0;
        if (P[i] < 0.0) P[i] = 0.0;
        if (Inh[i] < 0.0) Inh[i] = 0.0;
        if (F[i] < 0.0) F[i] = 0.0;
    }
}

void reaction_step_with_workspace(double *C, double *P, double *Inh, double *F,
                                  const TAF *taf, const Operators *op,
                                  const Params *p, double dt,
                                  ReactionWorkspace *ws) {
    reaction_compute_rhs(ws, C, P, Inh, F, taf, op, p);
    reaction_euler_step(C, P, Inh, F, ws, dt, ws->M);
    reaction_clamp_positive(C, P, Inh, F, ws->M);
}

void reaction_step(double *C, double *P, double *Inh, double *F,
                   const TAF *taf, const Operators *op,
                   const Params *p, double dt) {
    int M = p->Mx * p->My;
    ReactionWorkspace *ws = reaction_workspace_create(M);
    if (!ws) return;

    reaction_step_with_workspace(C, P, Inh, F, taf, op, p, dt, ws);
    reaction_workspace_free(ws);
}

void reaction_workspace_free(ReactionWorkspace *ws) {
    if (ws) {
        free(ws->C_rhs);
        free(ws->P_rhs);
        free(ws->Inh_rhs);
        free(ws->F_rhs);
        free(ws->vx);
        free(ws->vy);
        free(ws->div_v);
        free(ws->lap_I);
        free(ws->lap_F);
        free(ws->gx_I);
        free(ws->gy_I);
        free(ws->gx_F);
        free(ws->gy_F);
        free(ws->gx_C);
        free(ws->gy_C);
        free(ws);
    }
}

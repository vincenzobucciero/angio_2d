#include "operators.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* Helper: Costruisce matrice 1D Laplaciano con BC Neumann */
static void build_1d_laplacian_dense(double *L, int M, double h) {
    double h2_inv = 1.0 / (h * h);
    
    memset(L, 0, M * M * sizeof(double));
    
    // Tridiagonale: 1, -2, 1
    for (int i = 0; i < M; i++) {
        L[i*M + i] = -2.0 * h2_inv;
        if (i > 0)     L[i*M + (i-1)] = 1.0 * h2_inv;
        if (i < M - 1) L[i*M + (i+1)] = 1.0 * h2_inv;
    }
    
    // BC Neumann sinistro: u_0 = u_2 => L[0] opera su u_0, u_1, u_2
    // MATLAB: L(1,2) = 2/h^2 (L(1,3) già = 1/h^2)
    L[0*M + 1] = 2.0 * h2_inv;
    
    // BC Neumann destro: u_{M+1} = u_{M-1}
    // MATLAB: L(M,M-1) = 2/h^2
    L[(M-1)*M + (M-2)] = 2.0 * h2_inv;
}

/* Helper: Costruisce matrice 1D Gradiente con BC Neumann */
static void build_1d_gradient_dense(double *G, int M, double h) {
    double h2_inv = 0.5 / h;
    
    memset(G, 0, M * M * sizeof(double));
    
    // Centrale interno: -1/(2h), 0, 1/(2h)
    for (int i = 1; i < M - 1; i++) {
        G[i*M + (i-1)] = -h2_inv;
        G[i*M + (i+1)] =  h2_inv;
    }
    
    // BORDI rimangono ZERO (MATLAB: G(1,:)=0, G(M,:)=0)
}

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
    
    // Alloca matrici 1D
    op->Lx = (double*) malloc(p->Mx * p->Mx * sizeof(double));
    op->Ly = (double*) malloc(p->My * p->My * sizeof(double));
    op->Gx = (double*) malloc(p->Mx * p->Mx * sizeof(double));
    op->Gy = (double*) malloc(p->My * p->My * sizeof(double));
    
    if (!op->Lx || !op->Ly || !op->Gx || !op->Gy) {
        fprintf(stderr, "ERROR: Failed to allocate operator matrices\n");
        free(op->Lx);
        free(op->Ly);
        free(op->Gx);
        free(op->Gy);
        free(op);
        return NULL;
    }
    
    op->Mx = p->Mx;
    op->My = p->My;
    
    // Costruisce operatori
    build_1d_laplacian_dense(op->Lx, p->Mx, p->hx);
    build_1d_laplacian_dense(op->Ly, p->My, p->hy);
    build_1d_gradient_dense(op->Gx, p->Mx, p->hx);
    build_1d_gradient_dense(op->Gy, p->My, p->hy);
    
    return op;
}

/* Apply 2D Operators */

void apply_laplacian_2d(double *out, const double *in,
                        const Operators *op, const Params *p) {
    double *tmp = (double*) malloc(p->Mx * p->My * sizeof(double));
    memset(out, 0, p->Mx * p->My * sizeof(double));
    
    // Parte x: out += (I⊗Lx) * in
    // Per ogni colonna j, applica Lx ai Mx elementi
    for (int j = 0; j < p->My; j++) {
        for (int i = 0; i < p->Mx; i++) {
            for (int ii = 0; ii < p->Mx; ii++) {
                int idx_out = ii + p->Mx * j;
                int idx_in  = ii + p->Mx * j;
                out[idx_out] += op->Lx[i*p->Mx + ii] * in[idx_in];
            }
        }
    }
    
    // Parte y: out += (Ly⊗I) * in
    // Per ogni riga i, applica Ly ai My elementi
    for (int i = 0; i < p->Mx; i++) {
        for (int j = 0; j < p->My; j++) {
            for (int jj = 0; jj < p->My; jj++) {
                int idx_out = i + p->Mx * j;
                int idx_in  = i + p->Mx * jj;
                out[idx_out] += op->Ly[j*p->My + jj] * in[idx_in];
            }
        }
    }
    
    free(tmp);
}

void apply_gradient_x_2d(double *out, const double *in,
                         const Operators *op, const Params *p) {
    memset(out, 0, p->Mx * p->My * sizeof(double));
    
    // out = (I⊗Gx) * in
    // Per ogni colonna j, applica Gx ai Mx elementi
    for (int j = 0; j < p->My; j++) {
        for (int i = 0; i < p->Mx; i++) {
            for (int ii = 0; ii < p->Mx; ii++) {
                int idx_out = i + p->Mx * j;
                int idx_in  = ii + p->Mx * j;
                out[idx_out] += op->Gx[i*p->Mx + ii] * in[idx_in];
            }
        }
    }
}

void apply_gradient_y_2d(double *out, const double *in,
                         const Operators *op, const Params *p) {
    memset(out, 0, p->Mx * p->My * sizeof(double));
    
    // out = (Gy⊗I) * in
    // Per ogni riga i, applica Gy ai My elementi
    for (int i = 0; i < p->Mx; i++) {
        for (int j = 0; j < p->My; j++) {
            for (int jj = 0; jj < p->My; jj++) {
                int idx_out = i + p->Mx * j;
                int idx_in  = i + p->Mx * jj;
                out[idx_out] += op->Gy[j*p->My + jj] * in[idx_in];
            }
        }
    }
}

void operators_free(Operators *op) {
    if (op) {
        free(op->Lx);
        free(op->Ly);
        free(op->Gx);
        free(op->Gy);
        free(op);
    }
}

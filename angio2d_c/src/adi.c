#include "adi.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

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
    
    if (!adi->ax || !adi->bx || !adi->cx ||
        !adi->ay || !adi->by || !adi->cy ||
        !adi->RHS || !adi->RHS2 || !adi->U_star) {
        fprintf(stderr, "ERROR: Failed to allocate ADI arrays\n");
        adi_free(adi);
        return NULL;
    }
    
    adi->Mx = p->Mx;
    adi->My = p->My;
    return adi;
}

void thomas_solve(const double *a, const double *b, const double *c,
                  const double *d, double *x, int n) {
    // Forward sweep
    double *c_star = (double*) malloc(n * sizeof(double));
    double *d_star = (double*) malloc(n * sizeof(double));
    
    c_star[0] = c[0] / b[0];
    d_star[0] = d[0] / b[0];
    
    for (int i = 1; i < n; i++) {
        double denom = b[i] - a[i] * c_star[i-1];
        if (i < n - 1) {
            c_star[i] = c[i] / denom;
        }
        d_star[i] = (d[i] - a[i] * d_star[i-1]) / denom;
    }
    
    // Back substitution
    x[n-1] = d_star[n-1];
    for (int i = n - 2; i >= 0; i--) {
        x[i] = d_star[i] - c_star[i] * x[i+1];
    }
    
    free(c_star);
    free(d_star);
}

void adi_step(double *u, const Params *p, ADI *adi, double d_coeff, double tau) {
    int Mx = p->Mx;
    int My = p->My;
    double hx = p->hx;
    double hy = p->hy;
    
    double tau2 = tau / 2.0;
    double rx = d_coeff * tau2 / (hx * hx);
    double ry = d_coeff * tau2 / (hy * hy);
    
    // Reshape u into 2D (u[i + Mx*j])
    double **U = (double**) malloc(Mx * sizeof(double*));
    for (int i = 0; i < Mx; i++) {
        U[i] = &u[i + Mx * 0];  // Trick: punta alle righe virtuali
    }
    
    // SEMI-PASSO 1: implicito in x, esplicito in y
    // RHS = ry*U(:,j-1) + (1-2*ry)*U(:,j) + ry*U(:,j+1)  [con BC]
    for (int j = 0; j < My; j++) {
        for (int i = 0; i < Mx; i++) {
            double rhs_val;
            if (j == 0) {
                // BC: U(i, -1) = U(i, 1)
                rhs_val = (1.0 - 2.0*ry) * u[i + Mx*j] + 2.0*ry * u[i + Mx*(j+1)];
            } else if (j == My - 1) {
                // BC: U(i, My) = U(i, My-2)
                rhs_val = 2.0*ry * u[i + Mx*(j-1)] + (1.0 - 2.0*ry) * u[i + Mx*j];
            } else {
                rhs_val = ry * u[i + Mx*(j-1)] + (1.0 - 2.0*ry) * u[i + Mx*j] + ry * u[i + Mx*(j+1)];
            }
            adi->RHS[i + Mx*j] = rhs_val;
        }
    }
    
    // Coefficienti tridiagonali per x (Neumann BC)
    for (int i = 0; i < Mx; i++) {
        adi->ax[i] = -rx;
        adi->bx[i] = 1.0 + 2.0*rx;
        adi->cx[i] = -rx;
    }
    adi->ax[0] = 0.0;
    adi->cx[0] = -2.0*rx;        // Bordo sinistro
    adi->ax[Mx-1] = -2.0*rx;     // Bordo destro
    adi->cx[Mx-1] = 0.0;
    
    // Risolvi (I - τ/2*d*Lx)*U_star = RHS per ogni j
    for (int j = 0; j < My; j++) {
        thomas_solve(adi->ax, adi->bx, adi->cx,
                     &adi->RHS[Mx*j], &adi->U_star[Mx*j], Mx);
    }
    
    // SEMI-PASSO 2: esplicito in x, implicito in y
    // RHS2 = rx*U_star(i-1,:) + (1-2*rx)*U_star(i,:) + rx*U_star(i+1,:)  [con BC]
    for (int i = 0; i < Mx; i++) {
        for (int j = 0; j < My; j++) {
            double rhs_val;
            if (i == 0) {
                // BC: U_star(-1, j) = U_star(1, j)
                rhs_val = (1.0 - 2.0*rx) * adi->U_star[i + Mx*j] + 2.0*rx * adi->U_star[(i+1) + Mx*j];
            } else if (i == Mx - 1) {
                // BC: U_star(Mx, j) = U_star(Mx-2, j)
                rhs_val = 2.0*rx * adi->U_star[(i-1) + Mx*j] + (1.0 - 2.0*rx) * adi->U_star[i + Mx*j];
            } else {
                rhs_val = rx * adi->U_star[(i-1) + Mx*j] + (1.0 - 2.0*rx) * adi->U_star[i + Mx*j] + rx * adi->U_star[(i+1) + Mx*j];
            }
            adi->RHS2[i + Mx*j] = rhs_val;
        }
    }
    
    // Coefficienti tridiagonali per y (Neumann BC)
    for (int j = 0; j < My; j++) {
        adi->ay[j] = -ry;
        adi->by[j] = 1.0 + 2.0*ry;
        adi->cy[j] = -ry;
    }
    adi->ay[0] = 0.0;
    adi->cy[0] = -2.0*ry;        // Bordo inferiore
    adi->ay[My-1] = -2.0*ry;     // Bordo superiore
    adi->cy[My-1] = 0.0;
    
    // Risolvi (I - τ/2*d*Ly)*u_new = RHS2 per ogni i
    // RHS2 è in ordine (i, j), devo estrarre colonne j per ogni i
    for (int i = 0; i < Mx; i++) {
        double *rhs_col = (double*) malloc(My * sizeof(double));
        for (int j = 0; j < My; j++) {
            rhs_col[j] = adi->RHS2[i + Mx*j];
        }
        double *sol_col = (double*) malloc(My * sizeof(double));
        thomas_solve(adi->ay, adi->by, adi->cy, rhs_col, sol_col, My);
        for (int j = 0; j < My; j++) {
            u[i + Mx*j] = sol_col[j];
        }
        free(rhs_col);
        free(sol_col);
    }
    
    free(U);
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
        free(adi);
    }
}

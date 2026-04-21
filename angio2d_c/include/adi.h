#ifndef ADI_H
#define ADI_H

#include "params.h"

typedef struct {
    double *ax, *bx, *cx, *ay, *by, *cy;
    double *RHS, *RHS2;
    double *U_star;
    int Mx, My;
} ADI;

ADI* adi_create(const Params *p);
void adi_free(ADI *adi);

void thomas_solve(const double *a, const double *b, const double *c,
                  const double *d, double *x, int n);

void adi_step(double *u, const Params *p, ADI *adi, double d_coeff, double tau);

#endif // ADI_H

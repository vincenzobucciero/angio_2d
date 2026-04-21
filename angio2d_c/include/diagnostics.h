#ifndef DIAGNOSTICS_H
#define DIAGNOSTICS_H

#include "params.h"
#include "operators.h"

typedef struct {
    double *t;
    double *mC;
    double *mF;
    double *En;
    int step;
} Diagnostics;

Diagnostics* diagnostics_create(int Nsteps);
void diagnostics_free(Diagnostics *diag);

double trap2d(const double *u, const Params *p);

void diagnostics_record(Diagnostics *diag, const double *C, const double *F,
                        const Operators *op, const Params *p, double t);

#endif // DIAGNOSTICS_H

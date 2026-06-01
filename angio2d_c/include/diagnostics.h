#ifndef DIAGNOSTICS_H
#define DIAGNOSTICS_H

#include "params.h"
#include "operators.h"

/*
 * Structure for the simulation time diagnostics.
 *
 * Contains:
 * - t   = simulation times
 * - mC  = total C-cell mass
 * - mF  = total F-matrix mass
 * - En  = system energy
 *
 * - step = number of recorded time steps
 */
typedef struct {
    double *t;		/* Time */
    double *mC;		/* C mass */
    double *mF;		/* F mass */
    double *En;		/* Energy */
    double *gx_C;    /* C x-gradient workspace */
    double *gy_C;    /* C y-gradient workspace */
    int M;           /* Total number of nodes */
    int step;		/* Time-step counter */
} Diagnostics;

/*
 * Allocate and initialize the Diagnostics structure.
 *
 * Input:
 *   Nsteps = maximum number of expected time steps
 *
 * Output:
 *   pointer to an initialized Diagnostics object
 *   or NULL on error
 */
Diagnostics* diagnostics_create(int Nsteps, int M);

/*
 * Free the memory associated with the Diagnostics structure.
 */
void diagnostics_free(Diagnostics *diag);

/*
 * Compute the numerical integral of a 2D field using the trapezoidal rule.
 *
 * Applies weights:
 * - 1 on interior nodes
 * - 1/2 sui bordi
 * - 1/4 agli angoli
 *
 * Input:
 *   u = discrete field
 *   p = grid parameters
 *
 * Output:
 *   value of the integral over the domain
 */
double trap2d(const double *u, const Params *p);

/*
 * Record diagnostic values at the current time.
 *
 * Computes and stores:
 * - time t
 * - C mass
 * - F mass
 * - system energy
 *
 * Input:
 *   diag = diagnostics structure
 *   C,F  = current fields
 *   op   = discrete operators (for gradients)
 *   p    = parameters
 *   t    = current time
 */
void diagnostics_record(Diagnostics *diag, const double *C, const double *F,
                        const Operators *op, const Params *p, double t);

#endif // DIAGNOSTICS_H

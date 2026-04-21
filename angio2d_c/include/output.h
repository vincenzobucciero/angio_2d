#ifndef OUTPUT_H
#define OUTPUT_H

#include "diagnostics.h"
#include "params.h"

void diagnostics_save_csv(const Diagnostics *diag, const Params *p,
                          const char *filename);

void diagnostics_print_summary(const Diagnostics *diag, const Params *p);

void save_solution_to_csv(const double *C, const double *P,
                          const double *Inh, const double *F,
                          const Params *p, const char *prefix);

#endif // OUTPUT_H

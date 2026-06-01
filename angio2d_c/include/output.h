#ifndef OUTPUT_H
#define OUTPUT_H

#include "diagnostics.h"
#include "params.h"

/*
 * Save temporal diagnostics to a CSV file.
 *
 * The file contains the columns:
 *   t, mC, mF, Energy
 *
 * Input:
 *   diag     = diagnostics structure
 *   p        = simulation parameters
 *   filename = output filename
 */
void diagnostics_save_csv(const Diagnostics *diag, const Params *p,
                          const char *filename);

/*
 * Print a simulation summary to the terminal.
 *
 * Includes:
 * - grid and time information
 * - initial and final values of mC, mF, energy
 * - percentage changes
 *
 * Input:
 *   diag = diagnostics structure
 *   p    = simulation parameters
 */
void diagnostics_print_summary(const Diagnostics *diag, const Params *p);

/*
 * Save the final simulation fields to separate CSV files.
 *
 * The generated files are:
 *   prefix_C.csv
 *   prefix_P.csv
 *   prefix_Inh.csv
 *   prefix_F.csv
 *
 * Input:
 *   C,P,Inh,F = final fields
 *   p         = simulation parameters
 *   prefix    = output file prefix
 */
void save_solution_to_csv(const double *C, const double *P,
                          const double *Inh, const double *F,
                          const Params *p, const char *prefix);

/*
 * Save the main simulation parameters as CSV.
 *
 * Includes:
 *   Mx, My, Lx, Ly, hx, hy, Tf, tau, Nsteps, epsilon
 *
 * Input:
 *   p        = simulation parameters
 *   filename = output filename
 */
void save_run_metadata(const Params *p, const char *filename);

#endif // OUTPUT_H
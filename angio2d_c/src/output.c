#include "output.h"
#include <stdio.h>

/*
 * Save a single scalar field to CSV.
 *
 * The file contains one value per line in linear memory order.
 *
 * Input:
 *   field    = field vector to save
 *   M        = total number of elements
 *   filename = output filename
 */
static void save_field_csv(const double *field, int M, const char *filename) {
    /* Open file and write one value per line in linear order */
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);
        return;
    }

    for (int i = 0; i < M; i++) {
        fprintf(fp, "%.10e\n", field[i]);
    }

    fclose(fp);
}

/*
 * Save time series diagnostics to CSV.
 *
 * The file contains columns: t, mC, mF, Energy
 *
 * Input:
 *   diag     = diagnostics structure
 *   p        = model parameters
 *   filename = output filename
 */
void diagnostics_save_csv(const Diagnostics *diag, const Params *p,
                          const char *filename) {
    (void)p;    // unused parameter in this function

    FILE *fp = fopen(filename, "w");    // open CSV file for writing
    if (!fp) {
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);
        return;
    }

    fprintf(fp, "t,mC,mF,Energy\n");    // write CSV header
    for (int i = 0; i < diag->step; i++) {
        fprintf(fp, "%.10e,%.10e,%.10e,%.10e\n",
                diag->t[i], diag->mC[i], diag->mF[i], diag->En[i]);
    }

    fclose(fp);    // close file
    printf("Diagnostics saved to %s (%d timesteps)\n", filename, diag->step);
}

/*
 * Save the final solution of the four fields into separate CSV files.
 *
 * Produced files:
 *   prefix_C.csv
 *   prefix_P.csv
 *   prefix_Inh.csv
 *   prefix_F.csv
 *
 * Input:
 *   C, P, Inh, F = final fields
 *   p            = simulation parameters
 *   prefix       = common filename prefix
 */
void save_solution_to_csv(const double *C, const double *P,
                          const double *Inh, const double *F,
                          const Params *p, const char *prefix) {
    int M = p->Mx * p->My;    // total number of nodes
    char filename[256];    // buffer to build filenames

    snprintf(filename, sizeof(filename), "%s_C.csv", prefix);    // build filename for C
    save_field_csv(C, M, filename);    // save C field

    snprintf(filename, sizeof(filename), "%s_P.csv", prefix);    // build filename for P
    save_field_csv(P, M, filename);    // save P field

    snprintf(filename, sizeof(filename), "%s_Inh.csv", prefix);    // build filename for Inh
    save_field_csv(Inh, M, filename);    // save Inh field

    snprintf(filename, sizeof(filename), "%s_F.csv", prefix);    // build filename for F
    save_field_csv(F, M, filename);    // save F field

    printf("Solution saved to %s_[CPIF].csv\n", prefix);    // summary message
}

/*
 * Save the main run metadata into a CSV file.
 *
 * The file contains a single row with:
 *   Mx, My, Lx, Ly, hx, hy, Tf, tau, Nsteps, epsilon
 *
 * Input:
 *   p        = simulation parameters
 *   filename = output filename
 */
void save_run_metadata(const Params *p, const char *filename) {
    FILE *fp = fopen(filename, "w");    // open metadata file
    if (!fp) {
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);
        return;
    }

    fprintf(fp, "Mx,My,Lx,Ly,hx,hy,Tf,tau,Nsteps,epsilon\n");    // CSV header
    fprintf(fp, "%d,%d,%.10e,%.10e,%.10e,%.10e,%.10e,%.10e,%d,%.10e\n",
            p->Mx, p->My, p->Lx, p->Ly, p->hx, p->hy,
            p->Tf, p->tau, p->Nsteps, p->epsilon);    // write parameters in one row

    fclose(fp);    // close file
    printf("Run metadata saved to %s\n", filename);    // informational message
}

/*
 * Print a final run summary to stdout.
 *
 * Shows:
 * - grid information and final time
 * - initial values of mC, mF, E
 * - final values of mC, mF, E
 * - absolute and percentage changes
 *
 * Input:
 *   diag = diagnostics structure
 *   p    = simulation parameters
 */
void diagnostics_print_summary(const Diagnostics *diag, const Params *p) {
    if (diag->step == 0) {    // ensure at least one record exists
        printf("ERROR: No diagnostics recorded\n");
        return;
    }

    printf("\n");
    printf("==== SOLVER SUMMARY ====\n");
    printf("Grid: %d × %d\n", p->Mx, p->My);    // grid size
    printf("Domain: [0, %.2f] × [0, %.2f]\n", p->Lx, p->Ly);    // domain extent
    printf("Final time: %.3f (tau=%.6e, Nsteps=%d)\n", p->Tf, p->tau, p->Nsteps);    // time info

    printf("\n---- DIAGNOSTICS ----\n");
    printf("Timesteps recorded: %d\n", diag->step);    // number of saved timesteps

    printf("\nInitial state:\n");
    printf("  mC(0) = %.10e\n", diag->mC[0]);    // initial C mass
    printf("  mF(0) = %.10e\n", diag->mF[0]);    // initial F mass
    printf("  E(0)  = %.10e\n", diag->En[0]);    // initial energy

    printf("\nFinal state:\n");
    printf("  mC(T) = %.10e\n", diag->mC[diag->step-1]);    // final C mass
    printf("  mF(T) = %.10e\n", diag->mF[diag->step-1]);    // final F mass
    printf("  E(T)  = %.10e\n", diag->En[diag->step-1]);    // final energy

    printf("\nChange:\n");
    printf("  ΔmC = %.10e (%.2f%%)\n",
           diag->mC[diag->step-1] - diag->mC[0],
           100.0*(diag->mC[diag->step-1] - diag->mC[0])/diag->mC[0]);    // absolute and percentage change of mC

    printf("  ΔmF = %.10e (%.2f%%)\n",
           diag->mF[diag->step-1] - diag->mF[0],
           100.0*(diag->mF[diag->step-1] - diag->mF[0])/diag->mF[0]);    // absolute and percentage change of mF

    printf("  ΔE  = %.10e (%.2f%%)\n",
           diag->En[diag->step-1] - diag->En[0],
           100.0*(diag->En[diag->step-1] - diag->En[0])/diag->En[0]);    // absolute and percentage change of energy

    printf("\n");
}
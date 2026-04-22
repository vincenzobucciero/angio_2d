#include "output.h"
#include <stdio.h>

/* Helper: Save a single field to CSV */
static void save_field_csv(const double *field, int M, const char *filename) {
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

void diagnostics_save_csv(const Diagnostics *diag, const Params *p,
                          const char *filename) {
    (void)p;
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);
        return;
    }
    
    fprintf(fp, "t,mC,mF,Energy\n");
    for (int i = 0; i < diag->step; i++) {
        fprintf(fp, "%.10e,%.10e,%.10e,%.10e\n",
                diag->t[i], diag->mC[i], diag->mF[i], diag->En[i]);
    }
    fclose(fp);
    printf("Diagnostics saved to %s (%d timesteps)\n", filename, diag->step);
}

void save_solution_to_csv(const double *C, const double *P,
                          const double *Inh, const double *F,
                          const Params *p, const char *prefix) {
    int M = p->Mx * p->My;
    char filename[256];
    
    snprintf(filename, sizeof(filename), "%s_C.csv", prefix);
    save_field_csv(C, M, filename);
    
    snprintf(filename, sizeof(filename), "%s_P.csv", prefix);
    save_field_csv(P, M, filename);
    
    snprintf(filename, sizeof(filename), "%s_Inh.csv", prefix);
    save_field_csv(Inh, M, filename);
    
    snprintf(filename, sizeof(filename), "%s_F.csv", prefix);
    save_field_csv(F, M, filename);
    
    printf("Solution saved to %s_[CPIF].csv\n", prefix);
}

void save_run_metadata(const Params *p, const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);
        return;
    }

    fprintf(fp, "Mx,My,Lx,Ly,hx,hy,Tf,tau,Nsteps,epsilon\n");
    fprintf(fp, "%d,%d,%.10e,%.10e,%.10e,%.10e,%.10e,%.10e,%d,%.10e\n",
            p->Mx, p->My, p->Lx, p->Ly, p->hx, p->hy,
            p->Tf, p->tau, p->Nsteps, p->epsilon);
    fclose(fp);
    printf("Run metadata saved to %s\n", filename);
}

void diagnostics_print_summary(const Diagnostics *diag, const Params *p) {
    if (diag->step == 0) {
        printf("ERROR: No diagnostics recorded\n");
        return;
    }
    
    printf("\n");
    printf("==== SOLVER SUMMARY ====\n");
    printf("Grid: %d × %d\n", p->Mx, p->My);
    printf("Domain: [0, %.2f] × [0, %.2f]\n", p->Lx, p->Ly);
    printf("Final time: %.3f (tau=%.6e, Nsteps=%d)\n", p->Tf, p->tau, p->Nsteps);
    printf("\n---- DIAGNOSTICS ----\n");
    printf("Timesteps recorded: %d\n", diag->step);
    printf("\nInitial state:\n");
    printf("  mC(0) = %.10e\n", diag->mC[0]);
    printf("  mF(0) = %.10e\n", diag->mF[0]);
    printf("  E(0)  = %.10e\n", diag->En[0]);
    
    printf("\nFinal state:\n");
    printf("  mC(T) = %.10e\n", diag->mC[diag->step-1]);
    printf("  mF(T) = %.10e\n", diag->mF[diag->step-1]);
    printf("  E(T)  = %.10e\n", diag->En[diag->step-1]);
    
    printf("\nChange:\n");
    printf("  ΔmC = %.10e (%.2f%%)\n",
           diag->mC[diag->step-1] - diag->mC[0],
           100.0*(diag->mC[diag->step-1] - diag->mC[0])/diag->mC[0]);
    printf("  ΔmF = %.10e (%.2f%%)\n",
           diag->mF[diag->step-1] - diag->mF[0],
           100.0*(diag->mF[diag->step-1] - diag->mF[0])/diag->mF[0]);
    printf("  ΔE  = %.10e (%.2f%%)\n",
           diag->En[diag->step-1] - diag->En[0],
           100.0*(diag->En[diag->step-1] - diag->En[0])/diag->En[0]);
    printf("\n");
}

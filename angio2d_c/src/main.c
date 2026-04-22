#include "params.h"
#include "grid.h"
#include "taf.h"
#include "operators.h"
#include "reaction.h"
#include "adi.h"
#include "diagnostics.h"
#include "output.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <sys/stat.h>

static void ensure_output_dirs(void) {
    /* Keep every generated artifact under output/ so runs stay self-contained. */
    mkdir("output", 0777);
    mkdir("output/csv", 0777);
    mkdir("output/figures", 0777);
}

int main(void) {
    ensure_output_dirs();

    Params *p = params_init();
    if (!p) return 1;
    
    Grid *g = grid_create(p);
    if (!g) {
        params_free(p);
        return 1;
    }
    
    TAF *taf = taf_compute(p, g);
    if (!taf) {
        grid_free(g);
        params_free(p);
        return 1;
    }
    
    Operators *op = operators_create(p);
    if (!op) {
        taf_free(taf);
        grid_free(g);
        params_free(p);
        return 1;
    }
    
    ADI *adi = adi_create(p);
    if (!adi) {
        operators_free(op);
        taf_free(taf);
        grid_free(g);
        params_free(p);
        return 1;
    }
    
    Diagnostics *diag = diagnostics_create(p->Nsteps);
    if (!diag) {
        adi_free(adi);
        operators_free(op);
        taf_free(taf);
        grid_free(g);
        params_free(p);
        return 1;
    }
    
    // Alloca variabili di stato
    int M = p->Mx * p->My;
    double *C = (double*) malloc(M * sizeof(double));
    double *P = (double*) malloc(M * sizeof(double));
    double *Inh = (double*) malloc(M * sizeof(double));
    double *F = (double*) malloc(M * sizeof(double));
    
    if (!C || !P || !Inh || !F) {
        free(C); free(P); free(Inh); free(F);
        diagnostics_free(diag);
        adi_free(adi);
        operators_free(op);
        taf_free(taf);
        grid_free(g);
        params_free(p);
        return 1;
    }
    
    // Inizializza condizioni iniziali da griglia (grid coordinate X[], Y[])
    // MATLAB: C = p.C0 * 0.5 * (1 - tanh((X - p.a)/p.sigma_IC))
    // MATLAB: P = 0.1 + 0.01 * cos(2*pi*X) * cos(2*pi*Y)
    // MATLAB: Inh = 0.1 + 0.005 * cos(4*pi*X) * cos(4*pi*Y)
    // MATLAB: F = 1.0 + 0.01 * cos(pi*X) * cos(pi*Y)
    for (int j = 0; j < p->My; j++) {
        for (int i = 0; i < p->Mx; i++) {
            int idx = i + p->Mx * j;
            // Use the flattened grid index so the C initialization matches
            // MATLAB's X(i,j), Y(i,j) values point-by-point.
            double xi = g->X[idx];
            double eta = g->Y[idx];
            
            // C: tanh transizione
            C[idx] = p->C0 * 0.5 * (1.0 - tanh((xi - p->a) / p->sigma_IC));
            
            // P: cos(2*pi*X) * cos(2*pi*Y)
            P[idx] = 0.1 + 0.01 * cos(2.0*M_PI*xi) * cos(2.0*M_PI*eta);
            
            // Inh: cos(4*pi*X) * cos(4*pi*Y)
            Inh[idx] = 0.1 + 0.005 * cos(4.0*M_PI*xi) * cos(4.0*M_PI*eta);
            
            // F: cos(pi*X) * cos(pi*Y)
            F[idx] = 1.0 + 0.01 * cos(M_PI*xi) * cos(M_PI*eta);
        }
    }
    
    // Diagnostica iniziale
    diagnostics_record(diag, C, F, op, p, 0.0);
    
    // Strang Splitting Loop: reaction(τ/2) → diffusion(τ) → reaction(τ/2)
    double tau = p->tau;
    double tau_half = tau / 2.0;
    
    for (int n = 0; n < p->Nsteps; n++) {
        // Semi-passo reazione
        reaction_step(C, P, Inh, F, taf, op, p, tau_half);
        reaction_clamp_positive(C, P, Inh, F, M);
        
        // Passo diffusione ADI
        adi_step(C, p, adi, p->dC, tau);
        adi_step(P, p, adi, p->dP, tau);
        adi_step(Inh, p, adi, p->dI, tau);
        // F non diffonde (nota MATLAB)
        
        // Semi-passo reazione
        reaction_step(C, P, Inh, F, taf, op, p, tau_half);
        reaction_clamp_positive(C, P, Inh, F, M);
        
        // Diagnostica
        diagnostics_record(diag, C, F, op, p, (n+1)*tau);
    }
    
    // Stampa summary e salva diagnostics
    diagnostics_print_summary(diag, p);
    diagnostics_save_csv(diag, p, "output/csv/diagnostics_c.csv");
    save_solution_to_csv(C, P, Inh, F, p, "output/csv/solution_c");
    save_run_metadata(p, "output/csv/run_metadata.csv");
    
    // Cleanup
    free(C);
    free(P);
    free(Inh);
    free(F);
    diagnostics_free(diag);
    adi_free(adi);
    operators_free(op);
    taf_free(taf);
    grid_free(g);
    params_free(p);
    return 0;
}

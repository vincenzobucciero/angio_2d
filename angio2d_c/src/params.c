/**
 * @file params.c
 * @brief Parameter initialization (direct translation from default_params.m)
 */

#include "params.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

Params* params_init(void) {
    Params *p = (Params*) malloc(sizeof(Params));
    if (!p) {
        fprintf(stderr, "ERROR: Failed to allocate Params\n");
        return NULL;
    }
    
    /*
     * Single source of truth for the default run configuration.
     * If future developers want a different baseline experiment, the
     * physical and numerical parameters should be changed here.
     */
    /* Domain & grid */
    p->Lx = 1.0;
    p->Ly = 1.0;
    p->Mx = 64;
    p->My = 64;
    p->Tf = 0.5;
    
    /* Diffusion coefficients */
    p->dC = 0.001;
    p->dP = 0.001;
    p->dI = 0.001;
    
    /* Chemotaxis parameters */
    p->alpha1 = 0.4;   /* haptotaxis (ECM) */
    p->alpha2 = 0.3;   /* chemotaxis (inhibitor) */
    p->alpha3 = 0.5;   /* TAF */
    p->alpha4 = 0.1;   /* TAF saturation */
    
    /* Reaction kinetics */
    p->k1 = 0.1;   /* C proliferation */
    p->k2 = 0.3;   /* ECM degradation */
    p->k3 = 0.2;   /* P-Inh interaction */
    p->k4 = 0.4;   /* P production from T, C */
    p->k5 = 0.1;   /* P production from T */
    p->k6 = 0.2;   /* P decay */
    
    /* TAF field */
    p->epsilon = 1.0;
    
    /* Initial conditions */
    p->C0 = 1.0;
    p->a = 0.1;
    p->sigma_IC = 0.02;
    
    /* Adaptive time-stepping (CFL-based) */
    p->hx = p->Lx / (p->Mx - 1);
    p->hy = p->Ly / (p->My - 1);
    
    double alpha_max = fmax(fmax(p->alpha1, p->alpha2), p->alpha3);
    double v_max = alpha_max * 2.0 / p->hx;
    double tau_adv = p->hx / v_max;
    
    p->tau = 0.8 * tau_adv;
    p->Nsteps = (int) ceil(p->Tf / p->tau);
    p->tau = p->Tf / p->Nsteps;   /* Exact: Nsteps * tau == Tf */
    
    return p;
}


/* ========================================
   FUNZIONE: params_print()
   ======================================== */

void params_print(const Params *p) {
    if (!p) {
        fprintf(stderr, "ERROR: params_print received NULL pointer\n");
        return;
    }
    
    printf("\nParameters:\n");
    printf("  Grid:  %d x %d, Domain: [0,%.1f] x [0,%.1f]\n",
           p->Mx, p->My, p->Lx, p->Ly);
    printf("  Time:  Tf=%.2f, tau=%.6e, Nsteps=%d\n",
           p->Tf, p->tau, p->Nsteps);
    printf("  Diff:  dC=%.4f, dP=%.4f, dI=%.4f\n",
           p->dC, p->dP, p->dI);
    printf("  Chem:  alpha1=%.2f, alpha2=%.2f, alpha3=%.2f, alpha4=%.2f\n",
           p->alpha1, p->alpha2, p->alpha3, p->alpha4);
    printf("\n");
}

void params_free(Params *p) {
    if (p) free(p);
}

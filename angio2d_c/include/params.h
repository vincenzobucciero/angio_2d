#ifndef PARAMS_H
#define PARAMS_H

/**
 * @file params.h
 * @brief ANGIO2D parameter structure and initialization
 */

typedef struct {
    /* Domain & grid */
    int Mx, My;              /* Grid points (default: 64x64) */
    double Lx, Ly;           /* Domain size (default: 1x1) */
    double hx, hy;           /* Grid spacing (computed) */
    
    /* Time stepping */
    double Tf;               /* Final time (default: 0.5) */
    double tau;              /* CFL-adaptive timestep (computed) */
    int Nsteps;              /* Total steps (computed) */
    
    /* Diffusion coefficients */
    double dC, dP, dI;       /* (default: 0.001) */
    
    /* Chemotaxis parameters */
    double alpha1;           /* Haptotaxis/ECM (default: 0.4) */
    double alpha2;           /* Chemotaxis/inhibitor (default: 0.3) */
    double alpha3;           /* TAF (default: 0.5) */
    double alpha4;           /* TAF saturation (default: 0.1) */
    
    /* Reaction kinetics */
    double k1, k2, k3, k4, k5, k6;   /* (default: see params.c) */
    
    /* TAF field */
    double epsilon;          /* TAF sharpness (default: 1.0) */
    
    /* Initial conditions */
    double C0, a, sigma_IC;  /* C field IC parameters */
    
} Params;

Params* params_init(void);
void params_print(const Params *p);
void params_free(Params *p);

#endif // PARAMS_H

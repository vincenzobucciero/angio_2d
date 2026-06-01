#include "params.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

/*
 * Initialize and return a Params structure.
 *
 * Contains model physical parameters, numerical discretization
 * settings, and an estimated time step (CFL-based).
 *
 * Returns: pointer to initialized Params or NULL on error.
 */
Params* params_init(void) {
    Params *p = (Params*) malloc(sizeof(Params));      // Allocate Params
    if (!p) {                                          // Check allocation
        fprintf(stderr, "ERROR: Failed to allocate Params\n");
        return NULL;
    }

    /* Core model parameters (defaults mirror default_params.m) */
    p->Lx = 1.0;           // Domain length in x
    p->Ly = 1.0;           // Domain length in y
    p->Mx = 64;            // Grid nodes in x
    p->My = 64;            // Grid nodes in y
    p->Tf = 0.5;           // Final simulation time

    p->dC = 0.001;         // Diffusion C
    p->dP = 0.001;         // Diffusion P
    p->dI = 0.001;         // Diffusion Inh

    p->alpha1 = 0.4;       // Haptotaxis (ECM)
    p->alpha2 = 0.3;       // Chemotaxis (inhibitor)
    p->alpha3 = 0.5;       // Chemotaxis (TAF)
    p->alpha4 = 0.1;       // TAF saturation

    p->k1 = 0.1;           // Proliferation C
    p->k2 = 0.3;           // ECM degradation
    p->k3 = 0.2;           // P-Inh interaction
    p->k4 = 0.4;           // P production from C/TAF
    p->k5 = 0.1;           // P production from TAF
    p->k6 = 0.2;           // P decay

    p->epsilon = 1.0;      // Spatial parameter for TAF

    p->C0 = 1.0;           // Initial max C
    p->a = 0.1;            // Initial front position
    p->sigma_IC = 0.02;    // Initial front width

    /* Spatial discretization */
    p->hx = p->Lx / (p->Mx - 1);   // Grid spacing x
    p->hy = p->Ly / (p->My - 1);   // Grid spacing y

    /* CFL estimate for advective stability */
    double alpha_max = fmax(fmax(p->alpha1, p->alpha2), p->alpha3); // Max tactic coeff
    double v_max = alpha_max * 2.0 / p->hx;    // Estimated max velocity
    double tau_adv = p->hx / v_max;

    p->tau = 0.8 * tau_adv;                    // Time step with safety margin
    p->Nsteps = (int) ceil(p->Tf / p->tau);    // Number of time steps

    p->tau = p->Tf / p->Nsteps;                // Recalibrate so Nsteps*tau = Tf

    return p;                                  // Return initialized struct
}

/* Print a brief summary of main parameters (useful for debugging). */
void params_print(const Params *p) {
    if (!p) {                                      // Validate pointer
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

/* Free memory associated with Params. */
void params_free(Params *p) {
    if (p) free(p);
}

/*
 * Initialize Params from a minimal YAML config file.
 *
 * Expected minimal format:
 *   grids:
 *     - { Mx: 64, My: 64 }
 *     - { Mx: 128, My: 128 }
 *
 * Arguments:
 *   config_path: path to YAML file
 *   grid_index: index of the grid to use (0, 1, ...)
 *
 * Returns: Params* with Mx/My set from config (rest are defaults), or NULL on error.
 * Note: if config_path is NULL, falls back to params_init().
 */
Params* params_init_from_yaml(const char *config_path, int grid_index) {
    if (!config_path) {
        /* Fallback: default initialization */
        return params_init();
    }

    FILE *fp = fopen(config_path, "r");
    if (!fp) {
        fprintf(stderr, "ERROR: Cannot open config file '%s'\n", config_path);
        return NULL;
    }

    /* Read file line-by-line and look for grid entries */
    char line[256];
    int grid_count = 0;
    int found_mx = 0, found_my = 0;
    int mx = 64, my = 64;  /* Default */

    while (fgets(line, sizeof(line), fp)) {
        /* Skip comments and empty lines */
        if (line[0] == '#' || line[0] == '\n') continue;

        /* Look for pattern "- { Mx: <num>, My: <num> }" */
        if (strstr(line, "Mx:") && strstr(line, "My:")) {
            if (grid_count == grid_index) {
                /* Found target grid entry */
                if (sscanf(line, "    - { Mx: %d, My: %d }", &mx, &my) == 2) {
                    found_mx = 1;
                    found_my = 1;
                    break;
                }
                /* Alternative formats with fewer spaces */
                if (sscanf(line, "  - { Mx: %d, My: %d }", &mx, &my) == 2) {
                    found_mx = 1;
                    found_my = 1;
                    break;
                }
                if (sscanf(line, "- { Mx: %d, My: %d }", &mx, &my) == 2) {
                    found_mx = 1;
                    found_my = 1;
                    break;
                }
            }
            grid_count++;
        }
    }
    fclose(fp);

    if (!found_mx || !found_my) {
        fprintf(stderr, "ERROR: Grid index %d not found or malformed in '%s'\n", 
                grid_index, config_path);
        return NULL;
    }

    /* Allocate and initialize Params with grid from config */
    Params *p = (Params*) malloc(sizeof(Params));
    if (!p) {
        fprintf(stderr, "ERROR: Failed to allocate Params\n");
        return NULL;
    }

    /* Set grid from config */
    p->Mx = mx;
    p->My = my;

    /* Rest of params (defaults) */
    p->Lx = 1.0;
    p->Ly = 1.0;
    p->Tf = 0.5;

    p->dC = 0.001;
    p->dP = 0.001;
    p->dI = 0.001;

    p->alpha1 = 0.4;
    p->alpha2 = 0.3;
    p->alpha3 = 0.5;
    p->alpha4 = 0.1;

    p->k1 = 0.1;
    p->k2 = 0.3;
    p->k3 = 0.2;
    p->k4 = 0.4;
    p->k5 = 0.1;
    p->k6 = 0.2;

    p->epsilon = 1.0;

    p->C0 = 1.0;
    p->a = 0.1;
    p->sigma_IC = 0.02;

    /* Spatial discretization */
    p->hx = p->Lx / (p->Mx - 1);
    p->hy = p->Ly / (p->My - 1);

    /* CFL and temporal stepping */
    double alpha_max = fmax(fmax(p->alpha1, p->alpha2), p->alpha3);
    double v_max = alpha_max * 2.0 / p->hx;
    double tau_adv = p->hx / v_max;

    p->tau = 0.8 * tau_adv;
    p->Nsteps = (int) ceil(p->Tf / p->tau);
    p->tau = p->Tf / p->Nsteps;

    return p;
}

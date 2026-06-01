#define _XOPEN_SOURCE 600
#include "params.h"		
#include "grid.h"		
#include "taf.h"		
#include "operators.h"		
#include "reaction.h"		
#include "adi.h"		
#include "diagnostics.h"		
#include "output.h"		
#ifdef USE_CUDA
#include "adi_cuda.h"
#endif
#include <stdlib.h>		
#include <stdio.h>		
#include <string.h>
#include <errno.h>
#include <math.h>		
#include <sys/stat.h>		
#include <time.h>
#ifdef _OPENMP
#include <omp.h>
#endif

/*
 * Create the output directories required by the simulation.
 *
 * All generated files are written under output/ so each run stays self-contained.
 */
static void ensure_output_dirs(void) {
    mkdir("output", 0777);        // Main output directory
    mkdir("output/csv", 0777);     // CSV output directory
    mkdir("output/figures", 0777); // Figures output directory
}

/*
 * Main program entry point.
 *
 * Optional CLI arguments:
 *   --config <path>      : Path to YAML config file
 *   --grid-index <idx>   : Grid index in config (0, 1, 2, ...)
 *
 * Example:
 *   ./angio2d                                    # Default 64x64
 *   ./angio2d --config ../configs/benchmark.yaml --grid-index 1  # 128x128
 *
 * Overall flow:
 * 1) parse CLI arguments
 * 2) create output directories
 * 3) initialize params, grid, TAF, operators, ADI, diagnostics
 * 4) allocate and initialize state variables
 * 5) run the time loop with Strang splitting
 * 6) save results and release memory
 */
int main(int argc, char *argv[]) {
    /* Parse CLI arguments */
    const char *config_path = NULL;
    int grid_index = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--config") == 0 && i + 1 < argc) {
            config_path = argv[++i];
        } else if (strcmp(argv[i], "--grid-index") == 0 && i + 1 < argc) {
            grid_index = atoi(argv[++i]);
        }
    }

    ensure_output_dirs();           // Ensure the output directories exist

    /* Initialize params: use config if provided, else default */
    Params *p;
    if (config_path) {
        p = params_init_from_yaml(config_path, grid_index);
    } else {
        p = params_init();
    }
    
    if (!p) return 1;               // Exit if initialization fails
    
    Grid *g = grid_create(p);       // Build the uniform Cartesian grid
    if (!g) {		// Check for errors
        params_free(p);             // Free params
        return 1;                   // Exit
    }
    
    TAF *taf = taf_compute(p, g);   // Compute the TAF field and auxiliary quantities
    if (!taf) {		// Check for errors
        grid_free(g);               // Free grid
        params_free(p);             // Free params
        return 1;                   // Exit
    }
    
    Operators *op = operators_create(p);   // Build discrete operators
    if (!op) {		// Check for errors
        taf_free(taf);              // Free TAF
        grid_free(g);               // Free grid
        params_free(p);             // Free params
        return 1;                   // Exit
    }
    
    ADI *adi = adi_create(p);       // Allocate the ADI diffusion solver structure
    if (!adi) {		// Check for errors
        operators_free(op);         // Free operators
        taf_free(taf);              // Free TAF
        grid_free(g);               // Free grid
        params_free(p);             // Free params
        return 1;                   // Exit
    }
    
    Diagnostics *diag = diagnostics_create(p->Nsteps, p->Mx * p->My);   // Allocate time-series diagnostics
    if (!diag) {		// Check for errors
        adi_free(adi);              // Free ADI
        operators_free(op);         // Free operators
        taf_free(taf);              // Free TAF
        grid_free(g);               // Free grid
        params_free(p);             // Free params
        return 1;                   // Exit
    }
    
    int M = p->Mx * p->My;          // Total number of grid nodes

    double *C = (double*) malloc(M * sizeof(double));      // Endothelial cell density
    double *P = (double*) malloc(M * sizeof(double));      // Protease
    double *Inh = (double*) malloc(M * sizeof(double));    // Inhibitor
    double *F = (double*) malloc(M * sizeof(double));      // Extracellular matrix
    
    if (!C || !P || !Inh || !F) {   // Check state-variable allocation
        free(C);                   // Free C if allocated
        free(P);                   // Free P if allocated
        free(Inh);                 // Free Inh if allocated
        free(F);                   // Free F if allocated
        diagnostics_free(diag);    // Free diagnostics
        adi_free(adi);             // Free ADI
        operators_free(op);        // Free operators
        taf_free(taf);             // Free TAF
        grid_free(g);              // Free grid
        params_free(p);            // Free params
        return 1;                  // Exit with error
    }

    ReactionWorkspace *rws = reaction_workspace_create(M);
    if (!rws) {
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
        return 1;
    }
    
    // Initialize initial conditions from the grid coordinates X[] and Y[]
    // MATLAB: C = p.C0 * 0.5 * (1 - tanh((X - p.a)/p.sigma_IC))
    // MATLAB: P = 0.1 + 0.01 * cos(2*pi*X) * cos(2*pi*Y)
    // MATLAB: Inh = 0.1 + 0.005 * cos(4*pi*X) * cos(4*pi*Y)
    // MATLAB: F = 1.0 + 0.01 * cos(pi*X) * cos(pi*Y)
    #pragma omp parallel for collapse(2) if(p->Mx * p->My > 1024) schedule(static)
    for (int j = 0; j < p->My; j++) {        // Loop over y
        for (int i = 0; i < p->Mx; i++) {    // Loop over x
            int idx = i + p->Mx * j;         // Linear node index (i,j)

            double xi = g->X[idx];           // Current x coordinate
            double eta = g->Y[idx];          // Current y coordinate
            
            C[idx] = p->C0 * 0.5 * (1.0 - tanh((xi - p->a) / p->sigma_IC));   // Sigmoid initial profile for C
            
            P[idx] = 0.1 + 0.01 * cos(2.0*M_PI*xi) * cos(2.0*M_PI*eta);       // Initial perturbation for P
            
            Inh[idx] = 0.1 + 0.005 * cos(4.0*M_PI*xi) * cos(4.0*M_PI*eta);    // Initial perturbation for Inh
            
            F[idx] = 1.0 + 0.01 * cos(M_PI*xi) * cos(M_PI*eta);                // Initial perturbation for F
        }
    }
    
    diagnostics_record(diag, C, F, op, p, 0.0);   // Save initial diagnostics at t=0
    
    double tau = p->tau;              // Full time step
    double tau_half = tau / 2.0;      // Half time step
    int diag_stride = 1;
    const char *diag_stride_env = getenv("ANGIO2D_DIAG_STRIDE");
    if (diag_stride_env && *diag_stride_env) {
        char *endptr = NULL;
        long parsed = strtol(diag_stride_env, &endptr, 10);
        if (endptr != diag_stride_env && parsed > 0 && parsed <= 100000000L) {
            diag_stride = (int)parsed;
        } else {
            fprintf(stderr, "[DIAG] WARN: invalid ANGIO2D_DIAG_STRIDE='%s', using 1\n", diag_stride_env);
        }
    }
#ifdef USE_CUDA
    const char *backend = getenv("ANGIO2D_BACKEND");
    int use_cuda_backend = (backend && strcmp(backend, "cuda") == 0);
    int requested_cuda_backend = use_cuda_backend;
    const char *cuda_strict_env = getenv("ANGIO2D_CUDA_STRICT");
    /* Strict mode prevents silent CPU fallback when CUDA was explicitly requested. */
    int cuda_strict = (cuda_strict_env && strcmp(cuda_strict_env, "1") == 0);
    int fallback_to_cpu_happened = 0;
    int cuda_device_id = -1;
    int cuda_session_active = 0;
    char cuda_device_name[256];
    cuda_device_name[0] = '\0';
    if (use_cuda_backend && !diag_stride_env) {
        /* CUDA benchmark default: throttle expensive diagnostics copies/computation. */
        diag_stride = 256;
    }
    if (use_cuda_backend) {
        if (adi_cuda_session_init(C, P, Inh, F, taf, p) != 0) {
            if (cuda_strict) {
                /* Print a one-shot run banner even on early strict abort for post-mortem logs. */
                fprintf(stdout,
                        "[RUN MODE] requested_backend=%s effective_backend=%s cuda_device_id=%d cuda_gpu=\"%s\" adi_cuda_active=%s reaction_cpu=%s diagnostics_cpu=%s\n",
                        requested_cuda_backend ? "cuda" : "cpu",
                        "cpu",
                        -1,
                        "n/a",
                        "no",
                        "yes",
                        "yes");
                fflush(stdout);
                fprintf(stderr, "[CUDA] ERROR: session init failed and CUDA_STRICT=1, aborting run.\n");
                reaction_workspace_free(rws);
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
                return 2;
            } else {
                fprintf(stderr, "[CUDA] WARN: session init failed, fallback CPU path\n");
                use_cuda_backend = 0;
                fallback_to_cpu_happened = 1;
            }
        }
        if (use_cuda_backend) {
            (void)adi_cuda_get_device_info(&cuda_device_id, cuda_device_name, (int)sizeof(cuda_device_name), &cuda_session_active);
        }
    }
    /* One-shot execution mode banner used by benchmark logs and diagnostics tooling. */
    fprintf(stdout,
            "[RUN MODE] requested_backend=%s effective_backend=%s cuda_device_id=%d cuda_gpu=\"%s\" adi_cuda_active=%s reaction_cpu=%s diagnostics_cpu=%s\n",
            requested_cuda_backend ? "cuda" : "cpu",
            use_cuda_backend ? "cuda" : "cpu",
            cuda_device_id,
            (cuda_device_name[0] != '\0') ? cuda_device_name : "n/a",
            use_cuda_backend ? "yes" : "no",
            "yes",
            "yes");
#endif
    fprintf(stdout, "[DIAG] record stride = %d\n", diag_stride);
    fflush(stdout);
    
    /* Timing for the main loop */
    struct timespec t_start, t_end;
    clock_gettime(CLOCK_MONOTONIC, &t_start);
    
    for (int n = 0; n < p->Nsteps; n++) {   // Main time-stepping loop
        #ifdef USE_CUDA
        if (use_cuda_backend) {
            int cuda_rc = adi_cuda_session_step(p, tau, tau_half);
            if (cuda_rc != 0) {
                static int cuda_step_fallback_warned = 0;
                if (!cuda_step_fallback_warned) {
                    fprintf(stderr, "[CUDA] WARN: session step failed (rc=%d), switching to CPU fallback path.\n", cuda_rc);
                    cuda_step_fallback_warned = 1;
                }
                if (cuda_strict) {
                    fprintf(stderr, "[CUDA] ERROR: CUDA_STRICT=1, aborting on first session step failure.\n");
                    adi_cuda_session_finalize();
                    reaction_workspace_free(rws);
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
                    return 3;
                } else {
                    use_cuda_backend = 0;
                    fallback_to_cpu_happened = 1;
                }
            }
            if (!use_cuda_backend) {
                reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);
                reaction_clamp_positive(C, P, Inh, F, M);
                adi_step(C, p, adi, p->dC, tau);        // Fallback diffusion of C
                adi_step(P, p, adi, p->dP, tau);        // Fallback diffusion of P
                adi_step(Inh, p, adi, p->dI, tau);      // Fallback diffusion of Inh
                reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);
                reaction_clamp_positive(C, P, Inh, F, M);
            }
        } else {
            reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);   // First reaction half-step
            reaction_clamp_positive(C, P, Inh, F, M);                                 // Enforce non-negativity
            adi_step(C, p, adi, p->dC, tau);                                          // Diffusion of C
            adi_step(P, p, adi, p->dP, tau);                                          // Diffusion of P
            adi_step(Inh, p, adi, p->dI, tau);                                        // Diffusion of Inh
            reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);   // Second reaction half-step
            reaction_clamp_positive(C, P, Inh, F, M);                                 // Re-enforce non-negativity
        }
        #else
        reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);   // First reaction half-step
        reaction_clamp_positive(C, P, Inh, F, M);                                 // Enforce non-negativity
        adi_step(C, p, adi, p->dC, tau);                                          // Diffusion of C
        adi_step(P, p, adi, p->dP, tau);                                          // Diffusion of P
        adi_step(Inh, p, adi, p->dI, tau);                                        // Diffusion of Inh
        reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);   // Second reaction half-step
        reaction_clamp_positive(C, P, Inh, F, M);                                 // Re-enforce non-negativity
        #endif

        if (((n + 1) % diag_stride) == 0 || (n == p->Nsteps - 1)) {
            #ifdef USE_CUDA
            if (use_cuda_backend) {
                if (adi_cuda_session_copy_cf(C, F) != 0) {
                    fprintf(stderr, "[CUDA] WARN: copy C/F failed at step %d\n", n);
                }
            }
            #endif
            diagnostics_record(diag, C, F, op, p, (n+1)*tau);   // Save diagnostics at the new time
        }
    }
    
    clock_gettime(CLOCK_MONOTONIC, &t_end);
    double total_solver_time = (t_end.tv_sec - t_start.tv_sec) + 
                               (t_end.tv_nsec - t_start.tv_nsec) / 1.0e9;
    
    diagnostics_print_summary(diag, p);   // Print final simulation summary
#ifdef USE_CUDA
    if (use_cuda_backend) {
        (void)adi_cuda_session_copy_all(C, P, Inh, F);
        adi_cuda_session_finalize();
    }
    if (requested_cuda_backend && fallback_to_cpu_happened) {
        fprintf(stdout, "[CUDA] fallback_cpu_detected=yes\n");
    } else if (requested_cuda_backend) {
        fprintf(stdout, "[CUDA] fallback_cpu_detected=no\n");
    }
#endif
    diagnostics_save_csv(diag, p, "output/csv/diagnostics_c.csv");   // Save diagnostics to CSV
    save_solution_to_csv(C, P, Inh, F, p, "output/csv/solution_c");   // Save final solution
    save_run_metadata(p, "output/csv/run_metadata.csv");              // Save run metadata
    
    /* Save timing information */
    FILE *timing_file = fopen("output/csv/timing.csv", "w");
    if (timing_file) {
        fprintf(timing_file, "component,time_seconds\n");
        fprintf(timing_file, "total_solver_time,%.6f\n", total_solver_time);
        fclose(timing_file);
        printf("Total solver time: %.6f seconds\n", total_solver_time);
    }
    
    free(C);                      // Free C
    free(P);                      // Free P
    free(Inh);                    // Free Inh
    free(F);                      // Free F
    reaction_workspace_free(rws); // Free reaction workspace
    diagnostics_free(diag);       // Free diagnostics
    adi_free(adi);                // Free ADI structure
    operators_free(op);           // Free operators
    taf_free(taf);                // Free TAF
    grid_free(g);                 // Free grid
    params_free(p);               // Free params

    return 0;                    // Exit successfully
}

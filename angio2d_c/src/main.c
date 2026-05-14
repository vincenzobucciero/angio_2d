#define _XOPEN_SOURCE 600
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
#include <string.h>
#include <math.h>		
#include <sys/stat.h>		
#include <time.h>
#ifdef _OPENMP
#include <omp.h>
#endif

/*
 * Crea le directory di output necessarie per la simulazione.
 *
 * Tutti i file generati vengono salvati sotto output/
 * per mantenere ogni esecuzione auto-contenuta.
 */
static void ensure_output_dirs(void) {
    mkdir("output", 0777);		// Crea directory principale output
    mkdir("output/csv", 0777);		// Crea sottocartella per file CSV
    mkdir("output/figures", 0777);		// Crea sottocartella per figure
}

/*
 * Funzione principale del programma.
 *
 * Argomenti CLI (opzionali):
 *   --config <path>      : Path to YAML config file
 *   --grid-index <idx>   : Grid index in config (0, 1, 2, ...)
 *
 * Esempio:
 *   ./angio2d                                    # Default 64x64
 *   ./angio2d --config ../configs/benchmark.yaml --grid-index 1  # 128x128
 *
 * Flusso generale:
 * 1) parse CLI arguments
 * 2) crea directory di output
 * 3) inizializza parametri, griglia, TAF, operatori, ADI, diagnostica
 * 4) alloca e inizializza le variabili di stato
 * 5) esegue il ciclo temporale con Strang splitting
 * 6) salva risultati e libera memoria
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

    ensure_output_dirs();		// Assicura l'esistenza delle directory di output

    /* Initialize params: use config if provided, else default */
    Params *p;
    if (config_path) {
        p = params_init_from_yaml(config_path, grid_index);
    } else {
        p = params_init();
    }
    
    if (!p) return 1;		// Esce se l'inizializzazione fallisce
    
    Grid *g = grid_create(p);		// Costruisce la griglia cartesiana uniforme
    if (!g) {		// Controlla errore
        params_free(p);		// Libera parametri
        return 1;		// Esce
    }
    
    TAF *taf = taf_compute(p, g);		// Calcola campo TAF e quantità ausiliarie
    if (!taf) {		// Controlla errore
        grid_free(g);		// Libera griglia
        params_free(p);		// Libera parametri
        return 1;		// Esce
    }
    
    Operators *op = operators_create(p);		// Costruisce operatori discreti
    if (!op) {		// Controlla errore
        taf_free(taf);		// Libera TAF
        grid_free(g);		// Libera griglia
        params_free(p);		// Libera parametri
        return 1;		// Esce
    }
    
    ADI *adi = adi_create(p);		// Alloca struttura per il solver diffusivo ADI
    if (!adi) {		// Controlla errore
        operators_free(op);		// Libera operatori
        taf_free(taf);		// Libera TAF
        grid_free(g);		// Libera griglia
        params_free(p);		// Libera parametri
        return 1;		// Esce
    }
    
    Diagnostics *diag = diagnostics_create(p->Nsteps, p->Mx * p->My);		// Alloca diagnostica temporale
    if (!diag) {		// Controlla errore
        adi_free(adi);		// Libera ADI
        operators_free(op);		// Libera operatori
        taf_free(taf);		// Libera TAF
        grid_free(g);		// Libera griglia
        params_free(p);		// Libera parametri
        return 1;		// Esce
    }
    
    int M = p->Mx * p->My;		// Numero totale di nodi della griglia

    double *C = (double*) malloc(M * sizeof(double));		// Densità cellule endoteliali
    double *P = (double*) malloc(M * sizeof(double));		// Proteasi
    double *Inh = (double*) malloc(M * sizeof(double));		// Inibitore
    double *F = (double*) malloc(M * sizeof(double));		// Matrice extracellulare
    
    if (!C || !P || !Inh || !F) {		// Controlla allocazione delle variabili di stato
        free(C);		// Libera C se allocato
        free(P);		// Libera P se allocato
        free(Inh);		// Libera Inh se allocato
        free(F);		// Libera F se allocato
        diagnostics_free(diag);		// Libera diagnostica
        adi_free(adi);		// Libera ADI
        operators_free(op);		// Libera operatori
        taf_free(taf);		// Libera TAF
        grid_free(g);		// Libera griglia
        params_free(p);		// Libera parametri
        return 1;		// Esce con errore
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
    
    // Inizializza condizioni iniziali da griglia (grid coordinate X[], Y[])
    // MATLAB: C = p.C0 * 0.5 * (1 - tanh((X - p.a)/p.sigma_IC))
    // MATLAB: P = 0.1 + 0.01 * cos(2*pi*X) * cos(2*pi*Y)
    // MATLAB: Inh = 0.1 + 0.005 * cos(4*pi*X) * cos(4*pi*Y)
    // MATLAB: F = 1.0 + 0.01 * cos(pi*X) * cos(pi*Y)
    #pragma omp parallel for collapse(2) if(p->Mx * p->My > 1024) schedule(static)
    for (int j = 0; j < p->My; j++) {		// Loop su y
        for (int i = 0; i < p->Mx; i++) {		// Loop su x
            int idx = i + p->Mx * j;		// Indice lineare del nodo (i,j)

            double xi = g->X[idx];		// Coordinata x del nodo corrente
            double eta = g->Y[idx];		// Coordinata y del nodo corrente
            
            C[idx] = p->C0 * 0.5 * (1.0 - tanh((xi - p->a) / p->sigma_IC));		// Profilo iniziale sigmoide di C
            
            P[idx] = 0.1 + 0.01 * cos(2.0*M_PI*xi) * cos(2.0*M_PI*eta);		// Perturbazione iniziale di P
            
            Inh[idx] = 0.1 + 0.005 * cos(4.0*M_PI*xi) * cos(4.0*M_PI*eta);		// Perturbazione iniziale di Inh
            
            F[idx] = 1.0 + 0.01 * cos(M_PI*xi) * cos(M_PI*eta);		// Perturbazione iniziale di F
        }
    }
    
    diagnostics_record(diag, C, F, op, p, 0.0);		// Salva diagnostica iniziale al tempo t=0
    
    double tau = p->tau;		// Passo temporale completo
    double tau_half = tau / 2.0;		// Mezzo passo temporale
    
    /* Timing for main loop */
    struct timespec t_start, t_end;
    clock_gettime(CLOCK_MONOTONIC, &t_start);
    
    for (int n = 0; n < p->Nsteps; n++) {		// Ciclo temporale principale
        reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);		// Primo semi-passo di reazione
        reaction_clamp_positive(C, P, Inh, F, M);		// Impone non negatività
        
        adi_step(C, p, adi, p->dC, tau);		// Diffusione di C
        adi_step(P, p, adi, p->dP, tau);		// Diffusione di P
        adi_step(Inh, p, adi, p->dI, tau);		// Diffusione di Inh
        // F non diffonde		// La variabile F non ha termine diffusivo
        
        reaction_step_with_workspace(C, P, Inh, F, taf, op, p, tau_half, rws);		// Secondo semi-passo di reazione
        reaction_clamp_positive(C, P, Inh, F, M);		// Impone nuovamente non negatività
        
        diagnostics_record(diag, C, F, op, p, (n+1)*tau);		// Salva diagnostica al nuovo tempo
    }
    
    clock_gettime(CLOCK_MONOTONIC, &t_end);
    double total_solver_time = (t_end.tv_sec - t_start.tv_sec) + 
                               (t_end.tv_nsec - t_start.tv_nsec) / 1.0e9;
    
    diagnostics_print_summary(diag, p);		// Stampa riepilogo finale della simulazione
    diagnostics_save_csv(diag, p, "output/csv/diagnostics_c.csv");		// Salva diagnostica su CSV
    save_solution_to_csv(C, P, Inh, F, p, "output/csv/solution_c");		// Salva soluzione finale
    save_run_metadata(p, "output/csv/run_metadata.csv");		// Salva metadati dell'esecuzione
    
    /* Save timing information */
    FILE *timing_file = fopen("output/csv/timing.csv", "w");
    if (timing_file) {
        fprintf(timing_file, "component,time_seconds\n");
        fprintf(timing_file, "total_solver_time,%.6f\n", total_solver_time);
        fclose(timing_file);
        printf("Total solver time: %.6f seconds\n", total_solver_time);
    }
    
    free(C);		// Libera C
    free(P);		// Libera P
    free(Inh);		// Libera Inh
    free(F);		// Libera F
    reaction_workspace_free(rws);    // Libera workspace reazione
    diagnostics_free(diag);		// Libera diagnostica
    adi_free(adi);		// Libera struttura ADI
    operators_free(op);		// Libera operatori
    taf_free(taf);		// Libera TAF
    grid_free(g);		// Libera griglia
    params_free(p);		// Libera parametri

    return 0;		// Termina con successo
}

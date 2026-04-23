#ifndef OUTPUT_H
#define OUTPUT_H

#include "diagnostics.h"
#include "params.h"

/*
 * Salva la diagnostica temporale su file CSV.
 *
 * Il file contiene le colonne:
 *   t, mC, mF, Energy
 *
 * Input:
 *   diag     = struttura diagnostica
 *   p        = parametri della simulazione
 *   filename = nome del file di output
 */
void diagnostics_save_csv(const Diagnostics *diag, const Params *p,
                          const char *filename);

/*
 * Stampa a terminale un riepilogo della simulazione.
 *
 * Include:
 * - informazioni sulla griglia e sul tempo
 * - valori iniziali e finali di mC, mF, energia
 * - variazioni percentuali
 *
 * Input:
 *   diag = struttura diagnostica
 *   p    = parametri della simulazione
 */
void diagnostics_print_summary(const Diagnostics *diag, const Params *p);

/*
 * Salva i campi finali della simulazione in file CSV separati.
 *
 * I file prodotti sono:
 *   prefix_C.csv
 *   prefix_P.csv
 *   prefix_Inh.csv
 *   prefix_F.csv
 *
 * Input:
 *   C,P,Inh,F = campi finali
 *   p         = parametri della simulazione
 *   prefix    = prefisso dei file di output
 */
void save_solution_to_csv(const double *C, const double *P,
                          const double *Inh, const double *F,
                          const Params *p, const char *prefix);

/*
 * Salva i parametri principali della simulazione in formato CSV.
 *
 * Include:
 *   Mx, My, Lx, Ly, hx, hy, Tf, tau, Nsteps, epsilon
 *
 * Input:
 *   p        = parametri della simulazione
 *   filename = nome del file di output
 */
void save_run_metadata(const Params *p, const char *filename);

#endif // OUTPUT_H
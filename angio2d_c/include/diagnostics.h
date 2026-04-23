#ifndef DIAGNOSTICS_H
#define DIAGNOSTICS_H

#include "params.h"
#include "operators.h"

/*
 * Struttura per la diagnostica temporale della simulazione.
 *
 * Contiene:
 * - t   = tempi della simulazione
 * - mC  = massa totale delle cellule C
 * - mF  = massa totale della matrice F
 * - En  = energia del sistema
 *
 * - step = numero di timestep registrati
 */
typedef struct {
    double *t;		/* Tempo */
    double *mC;		/* Massa di C */
    double *mF;		/* Massa di F */
    double *En;		/* Energia */
    int step;		/* Contatore timestep */
} Diagnostics;

/*
 * Alloca e inizializza la struttura Diagnostics.
 *
 * Input:
 *   Nsteps = numero massimo di timestep previsti
 *
 * Output:
 *   puntatore a Diagnostics inizializzato
 *   oppure NULL in caso di errore
 */
Diagnostics* diagnostics_create(int Nsteps);

/*
 * Libera la memoria associata alla struttura Diagnostics.
 */
void diagnostics_free(Diagnostics *diag);

/*
 * Calcola l'integrale numerico di un campo 2D tramite regola del trapezio.
 *
 * Applica pesi:
 * - 1 nei nodi interni
 * - 1/2 sui bordi
 * - 1/4 agli angoli
 *
 * Input:
 *   u = campo discreto
 *   p = parametri della griglia
 *
 * Output:
 *   valore dell'integrale sul dominio
 */
double trap2d(const double *u, const Params *p);

/*
 * Registra i valori diagnostici al tempo corrente.
 *
 * Calcola e salva:
 * - tempo t
 * - massa di C
 * - massa di F
 * - energia del sistema
 *
 * Input:
 *   diag = struttura diagnostica
 *   C,F  = campi correnti
 *   op   = operatori discreti (per gradienti)
 *   p    = parametri
 *   t    = tempo corrente
 */
void diagnostics_record(Diagnostics *diag, const double *C, const double *F,
                        const Operators *op, const Params *p, double t);

#endif // DIAGNOSTICS_H
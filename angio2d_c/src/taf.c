#include "taf.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

/*
 * Calcola il campo TAF e le quantità ausiliarie associate.
 *
 * Per ogni nodo della griglia costruisce:
 * - T      = profilo del TAF
 * - Tx, Ty = gradienti analitici del TAF
 * - phi_x, phi_y = gradienti del potenziale ausiliario
 *
 * Input:
 *   p = parametri del modello
 *   g = griglia cartesiana
 *
 * Output:
 *   puntatore a struttura TAF inizializzata
 *   oppure NULL in caso di errore
 */
TAF* taf_compute(const Params *p, const Grid *g) {
    if (!p || !g) {		// Verifica validità dei puntatori in ingresso
        fprintf(stderr, "ERROR: taf_compute received NULL pointer\n");		// Stampa errore
        return NULL;		// Esce con errore
    }
    
    TAF *t = (TAF*) malloc(sizeof(TAF));		// Alloca struttura principale TAF
    if (!t) {		// Controlla allocazione
        fprintf(stderr, "ERROR: Failed to allocate TAF\n");		// Errore
        return NULL;		// Esce
    }
    
    int M = p->Mx * p->My;		// Numero totale di nodi della griglia
    
    t->T = (double*) malloc(M * sizeof(double));		// Campo TAF
    t->Tx = (double*) malloc(M * sizeof(double));		// Derivata del TAF in x
    t->Ty = (double*) malloc(M * sizeof(double));		// Derivata del TAF in y
    t->phi_x = (double*) malloc(M * sizeof(double));		// Componente x del potenziale ausiliario
    t->phi_y = (double*) malloc(M * sizeof(double));		// Componente y del potenziale ausiliario
    
    if (!t->T || !t->Tx || !t->Ty || !t->phi_x || !t->phi_y) {		// Verifica allocazioni
        fprintf(stderr, "ERROR: Failed to allocate TAF arrays\n");		// Stampa errore
        free(t->T);		// Libera T se allocato
        free(t->Tx);		// Libera Tx se allocato
        free(t->Ty);		// Libera Ty se allocato
        free(t->phi_x);		// Libera phi_x se allocato
        free(t->phi_y);		// Libera phi_y se allocato
        free(t);		// Libera struttura principale
        return NULL;		// Esce con errore
    }
    
    t->Mx = p->Mx;		// Salva numero nodi in x
    t->My = p->My;		// Salva numero nodi in y
    
    double inv_eps = 1.0 / p->epsilon;		// Precalcola 1/epsilon
    
    for (int ij = 0; ij < M; ij++) {		// Scorre tutti i nodi della griglia
        double dx = g->X[ij] - p->Lx;		// Distanza orizzontale dal centro del tumore
        double dy = g->Y[ij] - p->Ly / 2.0;		// Distanza verticale dal centro del tumore
        
        double r2 = dx*dx + dy*dy;		// Distanza quadratica dal centro
        t->T[ij] = exp(-inv_eps * r2);		// Profilo gaussiano del TAF
        
        t->Tx[ij] = -2.0 * inv_eps * dx * t->T[ij];		// Derivata analitica del TAF in x
        t->Ty[ij] = -2.0 * inv_eps * dy * t->T[ij];		// Derivata analitica del TAF in y
        
        double denom = 1.0 + p->alpha4 * t->T[ij];		// Denominatore del potenziale ausiliario
        t->phi_x[ij] = t->Tx[ij] / denom;		// Componente x del gradiente del potenziale
        t->phi_y[ij] = t->Ty[ij] / denom;		// Componente y del gradiente del potenziale
    }
    
    return t;		// Restituisce struttura TAF inizializzata
}

/*
 * Libera la memoria associata alla struttura TAF.
 *
 * Input:
 *   t = struttura TAF da deallocare
 */
void taf_free(TAF *t) {
    if (t) {		// Controlla validità del puntatore
        free(t->T);		// Libera campo TAF
        free(t->Tx);		// Libera derivata in x
        free(t->Ty);		// Libera derivata in y
        free(t->phi_x);		// Libera potenziale ausiliario in x
        free(t->phi_y);		// Libera potenziale ausiliario in y
        free(t);		// Libera struttura principale
    }
}
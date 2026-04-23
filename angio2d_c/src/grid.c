#include "grid.h"		// Definizione struct Grid e prototipi
#include <stdlib.h>		// malloc, free
#include <stdio.h>		// fprintf

/*
 * Crea e inizializza la griglia 2D.
 *
 * La funzione costruisce le coordinate della griglia cartesiana uniforme
 * corrispondente ai parametri del dominio:
 * - X = coordinate x di tutti i nodi
 * - Y = coordinate y di tutti i nodi
 *
 * Le coordinate sono memorizzate in formato vettoriale 1D con indice:
 *     idx = i + Mx * j
 *
 * Input:
 *   p = struttura dei parametri numerici
 *
 * Output:
 *   puntatore a una struttura Grid allocata e inizializzata
 *   oppure NULL in caso di errore
 */
Grid* grid_create(const Params *p) {
    if (!p) {		// Controlla che il puntatore ai parametri sia valido
        fprintf(stderr, "ERROR: grid_create received NULL Params\n");		// Stampa errore
        return NULL;		// Esce con errore
    }
    
    Grid *g = (Grid*) malloc(sizeof(Grid));		// Alloca struttura principale Grid
    if (!g) {		// Verifica allocazione
        fprintf(stderr, "ERROR: Failed to allocate Grid\n");		// Stampa errore
        return NULL;		// Esce
    }
    
    int M = p->Mx * p->My;		// Numero totale di nodi della griglia
    
    g->X = (double*) malloc(M * sizeof(double));		// Array coordinate x della griglia 2D
    g->Y = (double*) malloc(M * sizeof(double));		// Array coordinate y della griglia 2D
    
    if (!g->X || !g->Y) {		// Verifica allocazioni dei vettori coordinate
        fprintf(stderr, "ERROR: Failed to allocate coordinate arrays\n");		// Stampa errore
        free(g->X);		// Libera X se allocato
        free(g->Y);		// Libera Y se allocato
        free(g);		// Libera struttura principale
        return NULL;		// Esce con errore
    }
    
    g->Mx = p->Mx;		// Salva numero nodi in x
    g->My = p->My;		// Salva numero nodi in y
    g->hx = p->hx;		// Salva passo spaziale in x
    g->hy = p->hy;		// Salva passo spaziale in y
    
    // MATLAB: x = linspace(0, Lx, Mx)
    // Equivalente: x[i] = i * hx per i = 0..Mx-1
    double *x = (double*) malloc(p->Mx * sizeof(double));		// Vettore coordinate 1D in x
    double *y = (double*) malloc(p->My * sizeof(double));		// Vettore coordinate 1D in y
    
    for (int i = 0; i < p->Mx; i++) {		// Costruisce il vettore x
        x[i] = i * p->hx;		// Nodo i-esimo lungo x
    }
    for (int j = 0; j < p->My; j++) {		// Costruisce il vettore y
        y[j] = j * p->hy;		// Nodo j-esimo lungo y
    }
    
    // MATLAB: [X, Y] = meshgrid(x, y); X = X'; Y = Y';
    // Riempire 2D grid in ordine riga-major: idx = i + Mx*j
    for (int i = 0; i < p->Mx; i++) {		// Loop sui nodi x
        for (int j = 0; j < p->My; j++) {		// Loop sui nodi y
            int idx = i + p->Mx * j;		// Indice lineare del nodo (i,j)
            g->X[idx] = x[i];		// Coordinata x del nodo
            g->Y[idx] = y[j];		// Coordinata y del nodo
        }
    }
    
    free(x);		// Libera vettore temporaneo x
    free(y);		// Libera vettore temporaneo y
    
    return g;		// Restituisce griglia inizializzata
}

/*
 * Libera la memoria associata alla struttura Grid.
 *
 * Input:
 *   g = puntatore alla griglia da deallocare
 */
void grid_free(Grid *g) {
    if (g) {		// Controlla che il puntatore sia valido
        free(g->X);		// Libera array coordinate X
        free(g->Y);		// Libera array coordinate Y
        free(g);		// Libera struttura principale
    }
}
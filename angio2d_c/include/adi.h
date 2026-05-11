#ifndef ADI_H
#define ADI_H

#include "params.h"

/*
 * Struttura ADI (Alternating Direction Implicit).
 *
 * Contiene tutti i dati necessari per eseguire un passo diffusivo
 * con schema ADI 2D:
 *
 * - ax, bx, cx = coefficienti tridiagonali lungo x
 * - ay, by, cy = coefficienti tridiagonali lungo y
 *
 * - RHS  = termine noto primo semi-passo (implicito in x)
 * - RHS2 = termine noto secondo semi-passo (implicito in y)
 *
 * - U_star = soluzione intermedia dopo il primo sweep
 *
 * - Mx, My = dimensioni della griglia
 */
typedef struct {
    double *ax, *bx, *cx;		/* Matrice tridiagonale lungo x */
    double *ay, *by, *cy;		/* Matrice tridiagonale lungo y */
    
    double *RHS;			/* Termine noto primo semi-passo */
    double *RHS2;			/* Termine noto secondo semi-passo */
    
    double *U_star;			/* Soluzione intermedia */
    double *thomas_c_star;   /* Workspace Thomas per thread */
    double *thomas_d_star;   /* Workspace Thomas per thread */
    double *rhs_col_buffer;  /* Buffer colonne RHS per thread */
    double *sol_col_buffer;  /* Buffer colonne soluzione per thread */
    int max_threads;         /* Numero massimo thread supportati */
    int thomas_nmax;         /* Massima dimensione sistema Thomas */
    
    int Mx, My;			/* Dimensioni della griglia */
} ADI;

/*
 * Alloca e inizializza la struttura ADI.
 *
 * Input:
 *   p = parametri del modello
 *
 * Output:
 *   puntatore a ADI pronto all'uso
 *   oppure NULL in caso di errore
 */
ADI* adi_create(const Params *p);

/*
 * Libera tutta la memoria associata alla struttura ADI.
 */
void adi_free(ADI *adi);

/*
 * Risolve un sistema lineare tridiagonale usando il metodo di Thomas.
 *
 * Sistema:
 *   Ax = d
 *
 * dove A è definita da:
 *   a = sottodiagonale
 *   b = diagonale principale
 *   c = sovradiagonale
 *
 * Input:
 *   a, b, c = coefficienti tridiagonali
 *   d       = termine noto
 *   n       = dimensione sistema
 *
 * Output:
 *   x = soluzione del sistema
 */
void thomas_solve(const double *a, const double *b, const double *c,
                  const double *d, double *x, int n);

void thomas_solve_ws(const double *a, const double *b, const double *c,
                     const double *d, double *x, int n,
                     double *c_star, double *d_star);

/*
 * Esegue un passo diffusivo usando lo schema ADI.
 *
 * Risolve:
 *   ∂u/∂t = d Δu
 *
 * con schema Peaceman-Rachford:
 *   1) implicito in x, esplicito in y
 *   2) esplicito in x, implicito in y
 *
 * Input:
 *   u       = campo da aggiornare (in-place)
 *   p       = parametri della simulazione
 *   adi     = struttura ADI con buffer allocati
 *   d_coeff = coefficiente di diffusione
 *   tau     = passo temporale
 */
void adi_step(double *u, const Params *p, ADI *adi, double d_coeff, double tau);

#endif // ADI_H

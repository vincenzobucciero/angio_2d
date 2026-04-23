#include "params.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/*
 * Inizializza e restituisce la struttura Params.
 *
 * Contiene:
 * - parametri fisici del modello
 * - parametri numerici della discretizzazione
 * - passo temporale adattivo (CFL)
 *
 * Output:
 *   puntatore a Params inizializzato
 *   oppure NULL in caso di errore
 */
Params* params_init(void) {
    Params *p = (Params*) malloc(sizeof(Params));		// Alloca struttura Params
    if (!p) {		// Controlla allocazione
        fprintf(stderr, "ERROR: Failed to allocate Params\n");		// Errore
        return NULL;		// Esce
    }
    
    /*
     * Parametri principali del modello (equivalente default_params.m)
     */
    
    p->Lx = 1.0;		// Lunghezza dominio in x
    p->Ly = 1.0;		// Lunghezza dominio in y
    p->Mx = 64;		// Numero nodi in x
    p->My = 64;		// Numero nodi in y
    p->Tf = 0.5;		// Tempo finale simulazione
    
    p->dC = 0.001;		// Diffusione cellule C
    p->dP = 0.001;		// Diffusione proteasi P
    p->dI = 0.001;		// Diffusione inibitore Inh
    
    p->alpha1 = 0.4;		// Aptotassi (ECM)
    p->alpha2 = 0.3;		// Chemotassi (inibitore)
    p->alpha3 = 0.5;		// Chemotassi (TAF)
    p->alpha4 = 0.1;		// Saturazione TAF
    
    p->k1 = 0.1;		// Proliferazione C
    p->k2 = 0.3;		// Degradazione ECM
    p->k3 = 0.2;		// Interazione P-Inh
    p->k4 = 0.4;		// Produzione P da C/TAF
    p->k5 = 0.1;		// Produzione P da TAF
    p->k6 = 0.2;		// Decadimento P
    
    p->epsilon = 1.0;		// Parametro spaziale del TAF
    
    p->C0 = 1.0;		// Valore massimo iniziale C
    p->a = 0.1;		// Posizione fronte iniziale
    p->sigma_IC = 0.02;		// Larghezza fronte iniziale
    
    /*
     * Discretizzazione spaziale
     */
    p->hx = p->Lx / (p->Mx - 1);		// Passo griglia x
    p->hy = p->Ly / (p->My - 1);		// Passo griglia y
    
    /*
     * Stima CFL per stabilità (parte advettiva)
     */
    double alpha_max = fmax(fmax(p->alpha1, p->alpha2), p->alpha3);		// Massimo coefficiente tattico
    double v_max = alpha_max * 2.0 / p->hx;		// Velocità massima stimata
    double tau_adv = p->hx / v_max;		// Limite CFL
    
    p->tau = 0.8 * tau_adv;		// Passo temporale con margine sicurezza
    p->Nsteps = (int) ceil(p->Tf / p->tau);		// Numero passi temporali
    
    p->tau = p->Tf / p->Nsteps;		// Ricalibrazione: Nsteps * tau = Tf
    
    return p;		// Restituisce struttura inizializzata
}

/*
 * Stampa a video un riepilogo dei parametri principali.
 *
 * Utile per debug e verifica configurazione simulazione.
 */
void params_print(const Params *p) {
    if (!p) {		// Controlla validità puntatore
        fprintf(stderr, "ERROR: params_print received NULL pointer\n");		// Errore
        return;		// Esce
    }
    
    printf("\nParameters:\n");		// Titolo
    
    printf("  Grid:  %d x %d, Domain: [0,%.1f] x [0,%.1f]\n",
           p->Mx, p->My, p->Lx, p->Ly);		// Informazioni griglia
    
    printf("  Time:  Tf=%.2f, tau=%.6e, Nsteps=%d\n",
           p->Tf, p->tau, p->Nsteps);		// Informazioni temporali
    
    printf("  Diff:  dC=%.4f, dP=%.4f, dI=%.4f\n",
           p->dC, p->dP, p->dI);		// Coefficienti diffusione
    
    printf("  Chem:  alpha1=%.2f, alpha2=%.2f, alpha3=%.2f, alpha4=%.2f\n",
           p->alpha1, p->alpha2, p->alpha3, p->alpha4);		// Parametri tattici
    
    printf("\n");		// Riga vuota finale
}

/*
 * Libera la memoria associata alla struttura Params.
 */
void params_free(Params *p) {
    if (p) free(p);		// Libera struttura se valida
}
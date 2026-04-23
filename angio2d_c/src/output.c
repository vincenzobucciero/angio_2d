#include "output.h"
#include <stdio.h>

/*
 * Salva un singolo campo scalare in formato CSV.
 *
 * Il file contiene un solo valore per riga, nell'ordine lineare
 * in cui il campo è memorizzato in memoria.
 *
 * Input:
 *   field    = vettore del campo da salvare
 *   M        = numero totale di elementi
 *   filename = nome del file di output
 */
static void save_field_csv(const double *field, int M, const char *filename) {
    FILE *fp = fopen(filename, "w");		// Apre il file in scrittura
    if (!fp) {		// Controlla apertura file
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);		// Stampa errore
        return;		// Esce senza salvare
    }

    for (int i = 0; i < M; i++) {		// Scorre tutti gli elementi del campo
        fprintf(fp, "%.10e\n", field[i]);		// Scrive un valore per riga in formato scientifico
    }

    fclose(fp);		// Chiude il file
}

/*
 * Salva la diagnostica temporale in formato CSV.
 *
 * Il file contiene le colonne:
 *   t, mC, mF, Energy
 *
 * Input:
 *   diag     = struttura diagnostica
 *   p        = parametri del modello
 *   filename = nome del file di output
 */
void diagnostics_save_csv(const Diagnostics *diag, const Params *p,
                          const char *filename) {
    (void)p;		// Parametro non usato direttamente in questa funzione

    FILE *fp = fopen(filename, "w");		// Apre file CSV in scrittura
    if (!fp) {		// Controlla apertura file
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);		// Stampa errore
        return;		// Esce
    }
    
    fprintf(fp, "t,mC,mF,Energy\n");		// Scrive intestazione CSV
    for (int i = 0; i < diag->step; i++) {		// Scorre tutti gli step registrati
        fprintf(fp, "%.10e,%.10e,%.10e,%.10e\n",
                diag->t[i], diag->mC[i], diag->mF[i], diag->En[i]);		// Scrive una riga per timestep
    }

    fclose(fp);		// Chiude file
    printf("Diagnostics saved to %s (%d timesteps)\n", filename, diag->step);		// Messaggio informativo
}

/*
 * Salva la soluzione finale dei quattro campi in file CSV separati.
 *
 * I file prodotti sono:
 *   prefix_C.csv
 *   prefix_P.csv
 *   prefix_Inh.csv
 *   prefix_F.csv
 *
 * Input:
 *   C, P, Inh, F = campi finali
 *   p            = parametri della simulazione
 *   prefix       = prefisso comune dei file
 */
void save_solution_to_csv(const double *C, const double *P,
                          const double *Inh, const double *F,
                          const Params *p, const char *prefix) {
    int M = p->Mx * p->My;		// Numero totale di nodi
    char filename[256];		// Buffer per costruire i nomi file
    
    snprintf(filename, sizeof(filename), "%s_C.csv", prefix);		// Costruisce nome file per C
    save_field_csv(C, M, filename);		// Salva campo C
    
    snprintf(filename, sizeof(filename), "%s_P.csv", prefix);		// Costruisce nome file per P
    save_field_csv(P, M, filename);		// Salva campo P
    
    snprintf(filename, sizeof(filename), "%s_Inh.csv", prefix);		// Costruisce nome file per Inh
    save_field_csv(Inh, M, filename);		// Salva campo Inh
    
    snprintf(filename, sizeof(filename), "%s_F.csv", prefix);		// Costruisce nome file per F
    save_field_csv(F, M, filename);		// Salva campo F
    
    printf("Solution saved to %s_[CPIF].csv\n", prefix);		// Messaggio riepilogativo
}

/*
 * Salva i principali metadati della simulazione in un file CSV.
 *
 * Il file contiene una sola riga con:
 *   Mx, My, Lx, Ly, hx, hy, Tf, tau, Nsteps, epsilon
 *
 * Input:
 *   p        = parametri della simulazione
 *   filename = nome del file di output
 */
void save_run_metadata(const Params *p, const char *filename) {
    FILE *fp = fopen(filename, "w");		// Apre file metadata
    if (!fp) {		// Controlla apertura file
        fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);		// Stampa errore
        return;		// Esce
    }

    fprintf(fp, "Mx,My,Lx,Ly,hx,hy,Tf,tau,Nsteps,epsilon\n");		// Intestazione CSV
    fprintf(fp, "%d,%d,%.10e,%.10e,%.10e,%.10e,%.10e,%.10e,%d,%.10e\n",
            p->Mx, p->My, p->Lx, p->Ly, p->hx, p->hy,
            p->Tf, p->tau, p->Nsteps, p->epsilon);		// Scrive i parametri in una riga

    fclose(fp);		// Chiude file
    printf("Run metadata saved to %s\n", filename);		// Messaggio informativo
}

/*
 * Stampa a video un riepilogo finale della simulazione.
 *
 * Mostra:
 * - informazioni sulla griglia e sul tempo finale
 * - valori iniziali di mC, mF, E
 * - valori finali di mC, mF, E
 * - variazioni assolute e percentuali
 *
 * Input:
 *   diag = struttura diagnostica
 *   p    = parametri della simulazione
 */
void diagnostics_print_summary(const Diagnostics *diag, const Params *p) {
    if (diag->step == 0) {		// Verifica che esista almeno una registrazione
        printf("ERROR: No diagnostics recorded\n");		// Stampa errore
        return;		// Esce
    }
    
    printf("\n");		// Riga vuota iniziale
    printf("==== SOLVER SUMMARY ====\n");		// Titolo del riepilogo
    printf("Grid: %d × %d\n", p->Mx, p->My);		// Dimensione della griglia
    printf("Domain: [0, %.2f] × [0, %.2f]\n", p->Lx, p->Ly);		// Estensione del dominio
    printf("Final time: %.3f (tau=%.6e, Nsteps=%d)\n", p->Tf, p->tau, p->Nsteps);		// Parametri temporali

    printf("\n---- DIAGNOSTICS ----\n");		// Separatore sezione diagnostica
    printf("Timesteps recorded: %d\n", diag->step);		// Numero di timestep salvati

    printf("\nInitial state:\n");		// Sezione stato iniziale
    printf("  mC(0) = %.10e\n", diag->mC[0]);		// Massa iniziale di C
    printf("  mF(0) = %.10e\n", diag->mF[0]);		// Massa iniziale di F
    printf("  E(0)  = %.10e\n", diag->En[0]);		// Energia iniziale
    
    printf("\nFinal state:\n");		// Sezione stato finale
    printf("  mC(T) = %.10e\n", diag->mC[diag->step-1]);		// Massa finale di C
    printf("  mF(T) = %.10e\n", diag->mF[diag->step-1]);		// Massa finale di F
    printf("  E(T)  = %.10e\n", diag->En[diag->step-1]);		// Energia finale
    
    printf("\nChange:\n");		// Sezione variazioni
    printf("  ΔmC = %.10e (%.2f%%)\n",
           diag->mC[diag->step-1] - diag->mC[0],
           100.0*(diag->mC[diag->step-1] - diag->mC[0])/diag->mC[0]);		// Variazione assoluta e percentuale di mC

    printf("  ΔmF = %.10e (%.2f%%)\n",
           diag->mF[diag->step-1] - diag->mF[0],
           100.0*(diag->mF[diag->step-1] - diag->mF[0])/diag->mF[0]);		// Variazione assoluta e percentuale di mF

    printf("  ΔE  = %.10e (%.2f%%)\n",
           diag->En[diag->step-1] - diag->En[0],
           100.0*(diag->En[diag->step-1] - diag->En[0])/diag->En[0]);		// Variazione assoluta e percentuale di energia

    printf("\n");		// Riga vuota finale
}
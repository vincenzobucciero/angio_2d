#ifndef REACTION_H
#define REACTION_H

#include "params.h"
#include "grid.h"
#include "taf.h"
#include "operators.h"

/**
 * @file reaction.h
 * @brief Passo di reazione (Forward Euler)
 * 
 * MATLAB reaction_step:
 *   1. Calcola velocità: vx = α₂∇I - α₁∇F - α₃∇φ
 *   2. Calcola divergenza: div_v = α₂∇²I - α₁∇²F
 *   3. Calcola RHS:
 *      RC = vx*∂C/∂x + vy*∂C/∂y + div_v*C + k₁C(1-C)
 *      RP = -k₃PI + k₄TC + k₅T - k₆P
 *      RI = -k₃PI
 *      RF = -k₂PF
 *   4. Forward Euler: u_new = u_old + dt*RHS
 *   5. Clipping: max(u, 0)
 */

typedef struct {
    double *C_rhs, *P_rhs, *Inh_rhs, *F_rhs;  // RHS temporanei
    double *vx, *vy;                           // Velocità
    double *div_v;                             // Divergenza velocità
    double *lap_I, *lap_F;                     // Laplaciani
    double *gx_I, *gy_I;                       // Gradienti Inh
    double *gx_F, *gy_F;                       // Gradienti F
    double *gx_C, *gy_C;                       // Gradienti C
    int M;                                     // Mx*My
} ReactionWorkspace;

/**
 * Alloca workspace per reazione (temporanei)
 */
ReactionWorkspace* reaction_workspace_create(int M);

/**
 * Computa un passo di reazione (RHS solo, senza integrazione)
 * 
 * Input: C, P, Inh, F, TAF (precalcolati), operators, params
 * Output: RHS per ogni variabile
 */
void reaction_compute_rhs(ReactionWorkspace *ws,
                          const double *C, const double *P,
                          const double *Inh, const double *F,
                          const TAF *taf, const Operators *op,
                          const Params *p);

/**
 * Applica Forward Euler: u_new = u + dt * RHS
 * Aggiorna in-place C, P, Inh, F
 */
void reaction_euler_step(double *C, double *P, double *Inh, double *F,
                         const ReactionWorkspace *ws, double dt, int M);

/**
 * Clipping: max(u, 0) per garantire positività
 */
void reaction_clamp_positive(double *C, double *P, double *Inh, double *F, int M);

/**
 * Wrapper: reaction_step completo (RHS + Euler + clamp)
 */
void reaction_step(double *C, double *P, double *Inh, double *F,
                   const TAF *taf, const Operators *op,
                   const Params *p, double dt);

void reaction_step_with_workspace(double *C, double *P, double *Inh, double *F,
                                  const TAF *taf, const Operators *op,
                                  const Params *p, double dt,
                                  ReactionWorkspace *ws);

/**
 * Dealloca workspace
 */
void reaction_workspace_free(ReactionWorkspace *ws);

#endif // REACTION_H

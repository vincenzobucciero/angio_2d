#ifndef REACTION_H
#define REACTION_H

#include "params.h"
#include "grid.h"
#include "taf.h"
#include "operators.h"

/**
 * @file reaction.h
 * @brief Reaction step (Forward Euler)
 * 
 * MATLAB reaction_step:
 *   1. Compute velocity: vx = α₂∇I - α₁∇F - α₃∇φ
 *   2. Compute divergence: div_v = α₂∇²I - α₁∇²F
 *   3. Compute RHS:
 *      RC = vx*∂C/∂x + vy*∂C/∂y + div_v*C + k₁C(1-C)
 *      RP = -k₃PI + k₄TC + k₅T - k₆P
 *      RI = -k₃PI
 *      RF = -k₂PF
 *   4. Forward Euler: u_new = u_old + dt*RHS
 *   5. Clipping: max(u, 0)
 */

typedef struct {
    double *C_rhs, *P_rhs, *Inh_rhs, *F_rhs;   // Temporary RHS buffers
    double *vx, *vy;                           // Velocity
    double *div_v;                             // Velocity divergence
    double *lap_I, *lap_F;                     // Laplacians
    double *gx_I, *gy_I;                       // Inh gradients
    double *gx_F, *gy_F;                       // F gradients
    double *gx_C, *gy_C;                       // C gradients
    int M;                                     // Mx*My
} ReactionWorkspace;

/**
 * Allocate workspace for reaction computation (temporaries)
 */
ReactionWorkspace* reaction_workspace_create(int M);

/**
 * Compute a reaction step (RHS only, no time integration)
 * 
 * Input: C, P, Inh, F, TAF (precomputed), operators, params
 * Output: RHS for each variable
 */
void reaction_compute_rhs(ReactionWorkspace *ws,
                          const double *C, const double *P,
                          const double *Inh, const double *F,
                          const TAF *taf, const Operators *op,
                          const Params *p);

/**
 * Apply Forward Euler: u_new = u + dt * RHS
 * Update C, P, Inh, F in place
 */
void reaction_euler_step(double *C, double *P, double *Inh, double *F,
                         const ReactionWorkspace *ws, double dt, int M);

/**
 * Clipping: max(u, 0) to enforce positivity
 */
void reaction_clamp_positive(double *C, double *P, double *Inh, double *F, int M);

/**
 * Wrapper: full reaction_step (RHS + Euler + clamp)
 */
void reaction_step(double *C, double *P, double *Inh, double *F,
                   const TAF *taf, const Operators *op,
                   const Params *p, double dt);

void reaction_step_with_workspace(double *C, double *P, double *Inh, double *F,
                                  const TAF *taf, const Operators *op,
                                  const Params *p, double dt,
                                  ReactionWorkspace *ws);

/**
 * Deallocate workspace
 */
void reaction_workspace_free(ReactionWorkspace *ws);

#endif // REACTION_H

#ifndef ADI_CUDA_H
#define ADI_CUDA_H

#include "params.h"
#include "taf.h"

#ifdef __cplusplus
extern "C" {
#endif

/* CUDA ADI entrypoint (phase 3 kickoff).
 * Returns 0 on success, non-zero on failure/unavailable path.
 */
int adi_cuda_step(double *u, int Mx, int My, double hx, double hy, double d_coeff, double tau);
int adi_cuda_step_triplet(double *u1, double d1,
                          double *u2, double d2,
                          double *u3, double d3,
                          int Mx, int My, double hx, double hy, double tau);
int adi_cuda_session_init(const double *C, const double *P, const double *Inh, const double *F,
                          const TAF *taf, const Params *p);
int adi_cuda_session_step(const Params *p, double tau, double tau_half);
int adi_cuda_session_copy_cf(double *C, double *F);
int adi_cuda_session_copy_all(double *C, double *P, double *Inh, double *F);
void adi_cuda_session_finalize(void);
int adi_cuda_get_device_info(int *device_id, char *name_buf, int name_buf_len, int *session_active);

#ifdef __cplusplus
}
#endif

#endif

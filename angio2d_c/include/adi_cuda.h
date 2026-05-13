#ifndef ADI_CUDA_H
#define ADI_CUDA_H

#ifdef __cplusplus
extern "C" {
#endif

/* CUDA ADI entrypoint (phase 3 kickoff).
 * Returns 0 on success, non-zero on failure/unavailable path.
 */
int adi_cuda_step(double *u, int Mx, int My, double hx, double hy, double d_coeff, double tau);

#ifdef __cplusplus
}
#endif

#endif

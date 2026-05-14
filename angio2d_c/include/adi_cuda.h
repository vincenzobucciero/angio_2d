#ifndef ADI_CUDA_H
#define ADI_CUDA_H

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

#ifdef __cplusplus
}
#endif

#endif

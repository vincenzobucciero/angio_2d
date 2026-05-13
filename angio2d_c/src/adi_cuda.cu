#include "adi_cuda.h"

#include <cuda_runtime.h>
#include <cusparse.h>

/* Phase 3 kickoff: cuSPARSE-first scaffolding.
 * Real ADI x/y GPU sweeps will be implemented incrementally.
 */
int adi_cuda_step(double *u, int Mx, int My, double hx, double hy, double d_coeff, double tau) {
    (void)u;
    (void)Mx;
    (void)My;
    (void)hx;
    (void)hy;
    (void)d_coeff;
    (void)tau;

    int ndev = 0;
    if (cudaGetDeviceCount(&ndev) != cudaSuccess || ndev <= 0) {
        return 2;
    }

    cusparseHandle_t handle = nullptr;
    if (cusparseCreate(&handle) != CUSPARSE_STATUS_SUCCESS) {
        return 3;
    }
    cusparseDestroy(handle);

    /* Not implemented yet: signal caller to fallback to CPU ADI. */
    return 1;
}


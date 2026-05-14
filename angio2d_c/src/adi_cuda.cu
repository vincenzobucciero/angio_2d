#include "adi_cuda.h"

#include <cuda_runtime.h>
#include <math.h>

#define CUDA_BLOCK_SIZE 128

static double *d_u = NULL;
static double *d_rhs = NULL;
static double *d_u_star = NULL;
static double *d_rhs2 = NULL;
static double *d_cstar_rows = NULL;
static double *d_dstar_rows = NULL;
static double *d_cstar_cols = NULL;
static double *d_dstar_cols = NULL;

static int cached_Mx = 0;
static int cached_My = 0;

static void free_cuda_buffers(void) {
    cudaFree(d_dstar_cols);
    cudaFree(d_cstar_cols);
    cudaFree(d_dstar_rows);
    cudaFree(d_cstar_rows);
    cudaFree(d_rhs2);
    cudaFree(d_u_star);
    cudaFree(d_rhs);
    cudaFree(d_u);

    d_u = NULL;
    d_rhs = NULL;
    d_u_star = NULL;
    d_rhs2 = NULL;
    d_cstar_rows = NULL;
    d_dstar_rows = NULL;
    d_cstar_cols = NULL;
    d_dstar_cols = NULL;

    cached_Mx = 0;
    cached_My = 0;
}

static int ensure_cuda_buffers(int Mx, int My) {
    if (d_u != NULL && cached_Mx == Mx && cached_My == My) {
        return 0;
    }

    free_cuda_buffers();

    const int total = Mx * My;
    const size_t bytes = (size_t)total * sizeof(double);

    if (cudaMalloc((void**)&d_u, bytes) != cudaSuccess) goto fail;
    if (cudaMalloc((void**)&d_rhs, bytes) != cudaSuccess) goto fail;
    if (cudaMalloc((void**)&d_u_star, bytes) != cudaSuccess) goto fail;
    if (cudaMalloc((void**)&d_rhs2, bytes) != cudaSuccess) goto fail;

    if (cudaMalloc((void**)&d_cstar_rows, (size_t)My * (size_t)Mx * sizeof(double)) != cudaSuccess) goto fail;
    if (cudaMalloc((void**)&d_dstar_rows, (size_t)My * (size_t)Mx * sizeof(double)) != cudaSuccess) goto fail;
    if (cudaMalloc((void**)&d_cstar_cols, (size_t)Mx * (size_t)My * sizeof(double)) != cudaSuccess) goto fail;
    if (cudaMalloc((void**)&d_dstar_cols, (size_t)Mx * (size_t)My * sizeof(double)) != cudaSuccess) goto fail;

    cached_Mx = Mx;
    cached_My = My;

    return 0;

fail:
    free_cuda_buffers();
    return 1;
}

static __device__ inline double coeff_a(int k, int n, double r) {
    if (k == 0) return 0.0;
    if (k == n - 1) return -2.0 * r;
    return -r;
}

static __device__ inline double coeff_b(double r) {
    return 1.0 + 2.0 * r;
}

static __device__ inline double coeff_c(int k, int n, double r) {
    if (k == 0) return -2.0 * r;
    if (k == n - 1) return 0.0;
    return -r;
}

__global__ void build_rhs_y_kernel(
    const double *u,
    double *rhs,
    int Mx,
    int My,
    double ry
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = Mx * My;

    if (idx >= total) return;

    int i = idx % Mx;
    int j = idx / Mx;

    if (j == 0) {
        rhs[idx] = (1.0 - 2.0 * ry) * u[i + Mx * j]
                 + 2.0 * ry * u[i + Mx * (j + 1)];
    } else if (j == My - 1) {
        rhs[idx] = 2.0 * ry * u[i + Mx * (j - 1)]
                 + (1.0 - 2.0 * ry) * u[i + Mx * j];
    } else {
        rhs[idx] = ry * u[i + Mx * (j - 1)]
                 + (1.0 - 2.0 * ry) * u[i + Mx * j]
                 + ry * u[i + Mx * (j + 1)];
    }
}

__global__ void solve_rows_kernel(
    const double *rhs,
    double *u_star,
    double *c_star,
    double *d_star,
    int Mx,
    int My,
    double rx
) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= My) return;

    double *cs = c_star + j * Mx;
    double *ds = d_star + j * Mx;

    const int row = j * Mx;

    double b0 = coeff_b(rx);
    cs[0] = coeff_c(0, Mx, rx) / b0;
    ds[0] = rhs[row] / b0;

    for (int i = 1; i < Mx; i++) {
        double a = coeff_a(i, Mx, rx);
        double b = coeff_b(rx);
        double c = coeff_c(i, Mx, rx);

        double denom = b - a * cs[i - 1];

        if (i < Mx - 1) {
            cs[i] = c / denom;
        }

        ds[i] = (rhs[row + i] - a * ds[i - 1]) / denom;
    }

    u_star[row + Mx - 1] = ds[Mx - 1];

    for (int i = Mx - 2; i >= 0; i--) {
        u_star[row + i] = ds[i] - cs[i] * u_star[row + i + 1];
    }
}

__global__ void build_rhs_x_kernel(
    const double *u_star,
    double *rhs2,
    int Mx,
    int My,
    double rx
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = Mx * My;

    if (idx >= total) return;

    int i = idx % Mx;
    int j = idx / Mx;

    if (i == 0) {
        rhs2[idx] = (1.0 - 2.0 * rx) * u_star[i + Mx * j]
                  + 2.0 * rx * u_star[(i + 1) + Mx * j];
    } else if (i == Mx - 1) {
        rhs2[idx] = 2.0 * rx * u_star[(i - 1) + Mx * j]
                  + (1.0 - 2.0 * rx) * u_star[i + Mx * j];
    } else {
        rhs2[idx] = rx * u_star[(i - 1) + Mx * j]
                  + (1.0 - 2.0 * rx) * u_star[i + Mx * j]
                  + rx * u_star[(i + 1) + Mx * j];
    }
}

__global__ void solve_cols_kernel(
    const double *rhs2,
    double *u,
    double *c_star,
    double *d_star,
    int Mx,
    int My,
    double ry
) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= Mx) return;

    double *cs = c_star + i * My;
    double *ds = d_star + i * My;

    double b0 = coeff_b(ry);
    cs[0] = coeff_c(0, My, ry) / b0;
    ds[0] = rhs2[i] / b0;

    for (int j = 1; j < My; j++) {
        double a = coeff_a(j, My, ry);
        double b = coeff_b(ry);
        double c = coeff_c(j, My, ry);

        double denom = b - a * cs[j - 1];

        if (j < My - 1) {
            cs[j] = c / denom;
        }

        ds[j] = (rhs2[i + Mx * j] - a * ds[j - 1]) / denom;
    }

    u[i + Mx * (My - 1)] = ds[My - 1];

    for (int j = My - 2; j >= 0; j--) {
        u[i + Mx * j] = ds[j] - cs[j] * u[i + Mx * (j + 1)];
    }
}

int adi_cuda_step(double *u, int Mx, int My, double hx, double hy, double d_coeff, double tau) {
    if (!u || Mx <= 1 || My <= 1) {
        return 10;
    }

    int ndev = 0;
    cudaError_t err = cudaGetDeviceCount(&ndev);
    if (err != cudaSuccess || ndev <= 0) {
        return 2;
    }

    if (ensure_cuda_buffers(Mx, My) != 0) {
        return 11;
    }

    const int total = Mx * My;
    const size_t bytes = (size_t)total * sizeof(double);

    const double tau2 = tau / 2.0;
    const double rx = d_coeff * tau2 / (hx * hx);
    const double ry = d_coeff * tau2 / (hy * hy);

    const int blocks_cells = (total + CUDA_BLOCK_SIZE - 1) / CUDA_BLOCK_SIZE;
    const int blocks_rows = (My + CUDA_BLOCK_SIZE - 1) / CUDA_BLOCK_SIZE;
    const int blocks_cols = (Mx + CUDA_BLOCK_SIZE - 1) / CUDA_BLOCK_SIZE;

    if (cudaMemcpy(d_u, u, bytes, cudaMemcpyHostToDevice) != cudaSuccess) {
        return 12;
    }

    build_rhs_y_kernel<<<blocks_cells, CUDA_BLOCK_SIZE>>>(d_u, d_rhs, Mx, My, ry);
    if (cudaGetLastError() != cudaSuccess) return 13;

    solve_rows_kernel<<<blocks_rows, CUDA_BLOCK_SIZE>>>(d_rhs, d_u_star, d_cstar_rows, d_dstar_rows, Mx, My, rx);
    if (cudaGetLastError() != cudaSuccess) return 14;

    build_rhs_x_kernel<<<blocks_cells, CUDA_BLOCK_SIZE>>>(d_u_star, d_rhs2, Mx, My, rx);
    if (cudaGetLastError() != cudaSuccess) return 15;

    solve_cols_kernel<<<blocks_cols, CUDA_BLOCK_SIZE>>>(d_rhs2, d_u, d_cstar_cols, d_dstar_cols, Mx, My, ry);
    if (cudaGetLastError() != cudaSuccess) return 16;

    if (cudaDeviceSynchronize() != cudaSuccess) {
        return 17;
    }

    if (cudaMemcpy(u, d_u, bytes, cudaMemcpyDeviceToHost) != cudaSuccess) {
        return 18;
    }

    return 0;
}

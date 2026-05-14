#include "adi_cuda.h"
#include "adi_cuda_profiling.h"

#include <cuda_runtime.h>
#include <cusparse.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Extern declarations for profiling functions (implemented in adi_cuda_profiling.c) */
extern "C" {
extern ADI_ProfileData *g_adi_profile_data;
extern int g_adi_profile_count;
extern int g_adi_profile_max;
extern FILE *g_adi_profile_file;

extern void adi_cuda_profiling_init(int max_steps);
extern void adi_cuda_profiling_record(ADI_ProfileData data);
extern void adi_cuda_profiling_finalize(void);
}

/* Thomas solver kernel for tridiagonal systems
 * Solves ax[i]*x[i-1] + bx[i]*x[i] + cx[i]*x[i+1] = d[i]
 * for i = 0..n-1 with homogeneous Dirichlet BC
 */
__global__ void thomas_solve_batch_x(
    const double *a, const double *b, const double *c, const double *d,
    double *x, int n, int My, int Mx)
{
    /* Each block processes one row (j = blockIdx.x) */
    int j = blockIdx.x;
    if (j >= My) return;
    
    int tidx = threadIdx.x;
    int stride = blockDim.x;
    
    /* Forward sweep with padding to reduce bank conflicts */
    __shared__ double s_c[513];  /* c* stored in shared memory */
    __shared__ double s_d[513];  /* d* stored in shared memory */
    
    /* Initialize first element */
    if (tidx == 0) {
        s_c[0] = c[0] / b[0];
        s_d[0] = d[j * Mx + 0] / b[0];
    }
    __syncthreads();
    
    /* Forward elimination */
    for (int i = 1; i < n; i++) {
        if (tidx == 0) {
            double denom = b[i] - a[i] * s_c[i - 1];
            if (i < n - 1) {
                s_c[i] = c[i] / denom;
            }
            s_d[i] = (d[j * Mx + i] - a[i] * s_d[i - 1]) / denom;
        }
        __syncthreads();
    }
    
    /* Backward substitution (parallel reduction) */
    if (tidx == 0) {
        x[j * Mx + n - 1] = s_d[n - 1];
    }
    __syncthreads();
    
    for (int i = n - 2; i >= 0; i--) {
        if (tidx == 0) {
            x[j * Mx + i] = s_d[i] - s_c[i] * x[j * Mx + i + 1];
        }
        __syncthreads();
    }
}

/* Thomas solver kernel for tridiagonal systems (y-direction)
 * Each thread processes one column (i = blockIdx.x + threadIdx.x * blockDim.y)
 */
__global__ void thomas_solve_batch_y(
    const double *a, const double *b, const double *c, const double *d,
    double *x, int n, int Mx)
{
    /* Each thread processes one column (i) */
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= Mx) return;
    
    /* Use local arrays for c_star and d_star */
    double c_star[513];
    double d_star[513];
    
    /* Forward elimination */
    c_star[0] = c[0] / b[0];
    d_star[0] = d[0 * Mx + i] / b[0];
    
    for (int j = 1; j < n; j++) {
        double denom = b[j] - a[j] * c_star[j - 1];
        if (j < n - 1) {
            c_star[j] = c[j] / denom;
        }
        d_star[j] = (d[j * Mx + i] - a[j] * d_star[j - 1]) / denom;
    }
    
    /* Backward substitution */
    x[(n - 1) * Mx + i] = d_star[n - 1];
    for (int j = n - 2; j >= 0; j--) {
        x[j * Mx + i] = d_star[j] - c_star[j] * x[(j + 1) * Mx + i];
    }
}

/* RHS computation for x-sweep (implicit in x, explicit in y) */
__global__ void compute_rhs_x(
    const double *u, double *rhs,
    int Mx, int My, double ry)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= Mx * My) return;
    
    int i = idx % Mx;
    int j = idx / Mx;
    
    double rhs_val;
    if (j == 0) {
        rhs_val = (1.0 - 2.0 * ry) * u[idx] + 2.0 * ry * u[i + Mx * (j + 1)];
    } else if (j == My - 1) {
        rhs_val = 2.0 * ry * u[i + Mx * (j - 1)] + (1.0 - 2.0 * ry) * u[idx];
    } else {
        rhs_val = ry * u[i + Mx * (j - 1)] + (1.0 - 2.0 * ry) * u[idx] + ry * u[i + Mx * (j + 1)];
    }
    rhs[idx] = rhs_val;
}

/* RHS computation for y-sweep (implicit in y, explicit in x) */
__global__ void compute_rhs_y(
    const double *u, double *rhs,
    int Mx, int My, double rx)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= Mx * My) return;
    
    int i = idx % Mx;
    int j = idx / Mx;
    
    double rhs_val;
    if (i == 0) {
        rhs_val = (1.0 - 2.0 * rx) * u[idx] + 2.0 * rx * u[(i + 1) + Mx * j];
    } else if (i == Mx - 1) {
        rhs_val = 2.0 * rx * u[(i - 1) + Mx * j] + (1.0 - 2.0 * rx) * u[idx];
    } else {
        rhs_val = rx * u[(i - 1) + Mx * j] + (1.0 - 2.0 * rx) * u[idx] + rx * u[(i + 1) + Mx * j];
    }
    rhs[idx] = rhs_val;
}

/* ============================================================================
 * CUDA ADI solver context
 * ============================================================================ */

typedef struct {
    int Mx, My;
    int M;
    
    /* Device arrays */
    double *d_u, *d_rhs, *d_u_star;
    double *d_u_batch[3];
    double *d_ax, *d_bx, *d_cx;
    double *d_ay, *d_by, *d_cy;
    double *h_ax, *h_bx, *h_cx;
    double *h_ay, *h_by, *h_cy;
    
    /* cuSPARSE context */
    cusparseHandle_t cusparse_handle;
    
    /* Profiling */
    cudaEvent_t event_start, event_h2d, event_x_sweep, event_y_sweep, event_d2h, event_end;
} ADI_CUDA_Context;

static ADI_CUDA_Context g_adi_cuda_ctx = {0};
static int g_adi_cuda_initialized = 0;
static int g_adi_step_count = 0;

static void setup_coefficients_host(int Mx, int My, double hx, double hy, double d_coeff, double tau) {
    double tau2 = tau / 2.0;
    double rx = d_coeff * tau2 / (hx * hx);
    double ry = d_coeff * tau2 / (hy * hy);

    for (int i = 0; i < Mx; i++) {
        g_adi_cuda_ctx.h_ax[i] = -rx;
        g_adi_cuda_ctx.h_bx[i] = 1.0 + 2.0 * rx;
        g_adi_cuda_ctx.h_cx[i] = -rx;
    }
    g_adi_cuda_ctx.h_ax[0] = 0.0;
    g_adi_cuda_ctx.h_cx[0] = -2.0 * rx;
    g_adi_cuda_ctx.h_ax[Mx - 1] = -2.0 * rx;
    g_adi_cuda_ctx.h_cx[Mx - 1] = 0.0;

    for (int j = 0; j < My; j++) {
        g_adi_cuda_ctx.h_ay[j] = -ry;
        g_adi_cuda_ctx.h_by[j] = 1.0 + 2.0 * ry;
        g_adi_cuda_ctx.h_cy[j] = -ry;
    }
    g_adi_cuda_ctx.h_ay[0] = 0.0;
    g_adi_cuda_ctx.h_cy[0] = -2.0 * ry;
    g_adi_cuda_ctx.h_ay[My - 1] = -2.0 * ry;
    g_adi_cuda_ctx.h_cy[My - 1] = 0.0;
}

/* ============================================================================
 * CUDA initialization and cleanup
 * ============================================================================ */

static int adi_cuda_init(int Mx, int My) {
    if (g_adi_cuda_initialized) return 0;
    
    int M = Mx * My;
    cudaError_t err;
    
    g_adi_cuda_ctx.Mx = Mx;
    g_adi_cuda_ctx.My = My;
    g_adi_cuda_ctx.M = M;
    
    /* Allocate device memory */
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_u, M * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_u failed: %s\n", cudaGetErrorString(err));
        return 1;
    }
    
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_rhs, M * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_rhs failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        return 1;
    }
    
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_u_star, M * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_u_star failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        return 1;
    }

    for (int k = 0; k < 3; k++) {
        err = cudaMalloc((void**)&g_adi_cuda_ctx.d_u_batch[k], M * sizeof(double));
        if (err != cudaSuccess) {
            fprintf(stderr, "ERROR: cudaMalloc d_u_batch[%d] failed: %s\n", k, cudaGetErrorString(err));
            while (--k >= 0) cudaFree(g_adi_cuda_ctx.d_u_batch[k]);
            cudaFree(g_adi_cuda_ctx.d_u);
            cudaFree(g_adi_cuda_ctx.d_rhs);
            cudaFree(g_adi_cuda_ctx.d_u_star);
            return 1;
        }
    }
    
    /* Allocate coefficient arrays */
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_ax, Mx * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_ax failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        cudaFree(g_adi_cuda_ctx.d_u_star);
        return 1;
    }
    
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_bx, Mx * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_bx failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        cudaFree(g_adi_cuda_ctx.d_u_star);
        cudaFree(g_adi_cuda_ctx.d_ax);
        return 1;
    }
    
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_cx, Mx * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_cx failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        cudaFree(g_adi_cuda_ctx.d_u_star);
        cudaFree(g_adi_cuda_ctx.d_ax);
        cudaFree(g_adi_cuda_ctx.d_bx);
        return 1;
    }
    
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_ay, My * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_ay failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        cudaFree(g_adi_cuda_ctx.d_u_star);
        cudaFree(g_adi_cuda_ctx.d_ax);
        cudaFree(g_adi_cuda_ctx.d_bx);
        cudaFree(g_adi_cuda_ctx.d_cx);
        return 1;
    }
    
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_by, My * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_by failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        cudaFree(g_adi_cuda_ctx.d_u_star);
        cudaFree(g_adi_cuda_ctx.d_ax);
        cudaFree(g_adi_cuda_ctx.d_bx);
        cudaFree(g_adi_cuda_ctx.d_cx);
        cudaFree(g_adi_cuda_ctx.d_ay);
        return 1;
    }
    
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_cy, My * sizeof(double));
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMalloc d_cy failed: %s\n", cudaGetErrorString(err));
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        cudaFree(g_adi_cuda_ctx.d_u_star);
        cudaFree(g_adi_cuda_ctx.d_ax);
        cudaFree(g_adi_cuda_ctx.d_bx);
        cudaFree(g_adi_cuda_ctx.d_cx);
        cudaFree(g_adi_cuda_ctx.d_ay);
        cudaFree(g_adi_cuda_ctx.d_by);
        return 1;
    }
    
    /* Create cuSPARSE context */
    cusparseStatus_t status = cusparseCreate(&g_adi_cuda_ctx.cusparse_handle);
    if (status != CUSPARSE_STATUS_SUCCESS) {
        fprintf(stderr, "ERROR: cusparseCreate failed: %d\n", status);
        cudaFree(g_adi_cuda_ctx.d_u);
        cudaFree(g_adi_cuda_ctx.d_rhs);
        cudaFree(g_adi_cuda_ctx.d_u_star);
        cudaFree(g_adi_cuda_ctx.d_ax);
        cudaFree(g_adi_cuda_ctx.d_bx);
        cudaFree(g_adi_cuda_ctx.d_cx);
        cudaFree(g_adi_cuda_ctx.d_ay);
        cudaFree(g_adi_cuda_ctx.d_by);
        cudaFree(g_adi_cuda_ctx.d_cy);
        return 1;
    }
    
    /* Create CUDA events for profiling */
    cudaEventCreate(&g_adi_cuda_ctx.event_start);
    cudaEventCreate(&g_adi_cuda_ctx.event_h2d);
    cudaEventCreate(&g_adi_cuda_ctx.event_x_sweep);
    cudaEventCreate(&g_adi_cuda_ctx.event_y_sweep);
    cudaEventCreate(&g_adi_cuda_ctx.event_d2h);
    cudaEventCreate(&g_adi_cuda_ctx.event_end);
    
    g_adi_cuda_ctx.h_ax = (double*)malloc((size_t)Mx * sizeof(double));
    g_adi_cuda_ctx.h_bx = (double*)malloc((size_t)Mx * sizeof(double));
    g_adi_cuda_ctx.h_cx = (double*)malloc((size_t)Mx * sizeof(double));
    g_adi_cuda_ctx.h_ay = (double*)malloc((size_t)My * sizeof(double));
    g_adi_cuda_ctx.h_by = (double*)malloc((size_t)My * sizeof(double));
    g_adi_cuda_ctx.h_cy = (double*)malloc((size_t)My * sizeof(double));
    if (!g_adi_cuda_ctx.h_ax || !g_adi_cuda_ctx.h_bx || !g_adi_cuda_ctx.h_cx ||
        !g_adi_cuda_ctx.h_ay || !g_adi_cuda_ctx.h_by || !g_adi_cuda_ctx.h_cy) {
        fprintf(stderr, "ERROR: host coefficient allocation failed\n");
        return 1;
    }

    g_adi_cuda_initialized = 1;
    return 0;
}

static void adi_cuda_cleanup(void) {
    if (!g_adi_cuda_initialized) return;
    
    cudaFree(g_adi_cuda_ctx.d_u);
    cudaFree(g_adi_cuda_ctx.d_rhs);
    cudaFree(g_adi_cuda_ctx.d_u_star);
    for (int k = 0; k < 3; k++) {
        cudaFree(g_adi_cuda_ctx.d_u_batch[k]);
    }
    cudaFree(g_adi_cuda_ctx.d_ax);
    cudaFree(g_adi_cuda_ctx.d_bx);
    cudaFree(g_adi_cuda_ctx.d_cx);
    cudaFree(g_adi_cuda_ctx.d_ay);
    cudaFree(g_adi_cuda_ctx.d_by);
    cudaFree(g_adi_cuda_ctx.d_cy);
    
    if (g_adi_cuda_ctx.cusparse_handle) {
        cusparseDestroy(g_adi_cuda_ctx.cusparse_handle);
    }
    
    cudaEventDestroy(g_adi_cuda_ctx.event_start);
    cudaEventDestroy(g_adi_cuda_ctx.event_h2d);
    cudaEventDestroy(g_adi_cuda_ctx.event_x_sweep);
    cudaEventDestroy(g_adi_cuda_ctx.event_y_sweep);
    cudaEventDestroy(g_adi_cuda_ctx.event_d2h);
    cudaEventDestroy(g_adi_cuda_ctx.event_end);
    free(g_adi_cuda_ctx.h_ax);
    free(g_adi_cuda_ctx.h_bx);
    free(g_adi_cuda_ctx.h_cx);
    free(g_adi_cuda_ctx.h_ay);
    free(g_adi_cuda_ctx.h_by);
    free(g_adi_cuda_ctx.h_cy);
    
    g_adi_cuda_initialized = 0;
}

static int adi_cuda_diffuse_device_array(double *d_u, int Mx, int My, double hx, double hy, double d_coeff, double tau) {
    int M = Mx * My;
    double tau2 = tau / 2.0;
    double rx = d_coeff * tau2 / (hx * hx);
    double ry = d_coeff * tau2 / (hy * hy);

    setup_coefficients_host(Mx, My, hx, hy, d_coeff, tau);
    cudaMemcpy(g_adi_cuda_ctx.d_ax, g_adi_cuda_ctx.h_ax, Mx * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_bx, g_adi_cuda_ctx.h_bx, Mx * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_cx, g_adi_cuda_ctx.h_cx, Mx * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_ay, g_adi_cuda_ctx.h_ay, My * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_by, g_adi_cuda_ctx.h_by, My * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_cy, g_adi_cuda_ctx.h_cy, My * sizeof(double), cudaMemcpyHostToDevice);

    int block_size = 256;
    int grid_size = (M + block_size - 1) / block_size;
    compute_rhs_x<<<grid_size, block_size>>>(d_u, g_adi_cuda_ctx.d_rhs, Mx, My, ry);
    thomas_solve_batch_x<<<My, 1>>>(g_adi_cuda_ctx.d_ax, g_adi_cuda_ctx.d_bx, g_adi_cuda_ctx.d_cx,
                                    g_adi_cuda_ctx.d_rhs, g_adi_cuda_ctx.d_u_star, Mx, My, Mx);
    compute_rhs_y<<<grid_size, block_size>>>(g_adi_cuda_ctx.d_u_star, g_adi_cuda_ctx.d_rhs, Mx, My, rx);
    int grid_y = (Mx + 32 - 1) / 32;
    thomas_solve_batch_y<<<grid_y, 32>>>(g_adi_cuda_ctx.d_ay, g_adi_cuda_ctx.d_by, g_adi_cuda_ctx.d_cy,
                                         g_adi_cuda_ctx.d_rhs, d_u, My, Mx);
    return (cudaGetLastError() == cudaSuccess) ? 0 : 1;
}

/* ============================================================================
 * Main ADI step function (called from adi.c)
 * ============================================================================ */

int adi_cuda_step(double *u, int Mx, int My, double hx, double hy, double d_coeff, double tau) {
    if (!u || Mx <= 0 || My <= 0) {
        return 1;
    }
    
    /* Initialize CUDA context on first call */
    if (!g_adi_cuda_initialized) {
        if (adi_cuda_init(Mx, My) != 0) {
            return 1;  /* CUDA not available, fall back to CPU */
        }
        adi_cuda_profiling_init(1000);  /* Max 1000 ADI steps */
    }
    
    if (Mx != g_adi_cuda_ctx.Mx || My != g_adi_cuda_ctx.My) {
        fprintf(stderr, "ERROR: Grid size mismatch in adi_cuda_step\n");
        return 1;
    }
    
    int M = Mx * My;
    cudaError_t err;
    ADI_ProfileData prof;
    
    prof.step_number = g_adi_step_count++;
    prof.grid_size = M;
    
    /* Start profiling */
    cudaEventRecord(g_adi_cuda_ctx.event_start, 0);
    
    /* === PHASE 1: Host to Device copy === */
    err = cudaMemcpy(g_adi_cuda_ctx.d_u, u, M * sizeof(double), cudaMemcpyHostToDevice);
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMemcpy H2D failed: %s\n", cudaGetErrorString(err));
        return 1;
    }
    cudaEventRecord(g_adi_cuda_ctx.event_h2d, 0);
    
    /* === PHASE 2: Compute (all on device) === */
    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u, Mx, My, hx, hy, d_coeff, tau) != 0) {
        fprintf(stderr, "ERROR: CUDA kernel execution failed\n");
        return 1;
    }
    cudaEventRecord(g_adi_cuda_ctx.event_x_sweep, 0);
    cudaEventRecord(g_adi_cuda_ctx.event_y_sweep, 0);
    
    /* === PHASE 5: Device to Host copy === */
    err = cudaMemcpy(u, g_adi_cuda_ctx.d_u, M * sizeof(double), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: cudaMemcpy D2H failed: %s\n", cudaGetErrorString(err));
        return 1;
    }
    
    cudaEventRecord(g_adi_cuda_ctx.event_d2h, 0);
    
    /* === PHASE 6: Synchronization === */
    cudaDeviceSynchronize();
    cudaEventRecord(g_adi_cuda_ctx.event_end, 0);
    
    /* === Compute profiling metrics === */
    float ms_h2d, ms_x, ms_y, ms_d2h, ms_sync, ms_total;
    
    cudaEventElapsedTime(&ms_h2d, g_adi_cuda_ctx.event_start, g_adi_cuda_ctx.event_h2d);
    cudaEventElapsedTime(&ms_x, g_adi_cuda_ctx.event_h2d, g_adi_cuda_ctx.event_x_sweep);
    cudaEventElapsedTime(&ms_y, g_adi_cuda_ctx.event_x_sweep, g_adi_cuda_ctx.event_y_sweep);
    cudaEventElapsedTime(&ms_d2h, g_adi_cuda_ctx.event_y_sweep, g_adi_cuda_ctx.event_d2h);
    cudaEventElapsedTime(&ms_sync, g_adi_cuda_ctx.event_d2h, g_adi_cuda_ctx.event_end);
    cudaEventElapsedTime(&ms_total, g_adi_cuda_ctx.event_start, g_adi_cuda_ctx.event_end);
    
    prof.h2d_copy_ms = ms_h2d;
    prof.x_sweep_ms = ms_x;
    prof.y_sweep_ms = ms_y;
    prof.d2h_copy_ms = ms_d2h;
    prof.sync_time_ms = ms_sync;
    prof.total_ms = ms_total;
    
    /* Record profiling data */
    adi_cuda_profiling_record(prof);
    
    return 0;  /* Success */
}

int adi_cuda_step_triplet(double *u1, double d1,
                          double *u2, double d2,
                          double *u3, double d3,
                          int Mx, int My, double hx, double hy, double tau) {
    if (!u1 || !u2 || !u3 || Mx <= 0 || My <= 0) {
        return 1;
    }
    if (!g_adi_cuda_initialized) {
        if (adi_cuda_init(Mx, My) != 0) {
            return 1;
        }
        adi_cuda_profiling_init(1000);
    }
    if (Mx != g_adi_cuda_ctx.Mx || My != g_adi_cuda_ctx.My) {
        return 1;
    }

    const int M = Mx * My;
    cudaError_t err;

    err = cudaMemcpy(g_adi_cuda_ctx.d_u_batch[0], u1, M * sizeof(double), cudaMemcpyHostToDevice);
    if (err != cudaSuccess) return 1;
    err = cudaMemcpy(g_adi_cuda_ctx.d_u_batch[1], u2, M * sizeof(double), cudaMemcpyHostToDevice);
    if (err != cudaSuccess) return 1;
    err = cudaMemcpy(g_adi_cuda_ctx.d_u_batch[2], u3, M * sizeof(double), cudaMemcpyHostToDevice);
    if (err != cudaSuccess) return 1;

    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u_batch[0], Mx, My, hx, hy, d1, tau) != 0) return 1;
    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u_batch[1], Mx, My, hx, hy, d2, tau) != 0) return 1;
    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u_batch[2], Mx, My, hx, hy, d3, tau) != 0) return 1;

    err = cudaMemcpy(u1, g_adi_cuda_ctx.d_u_batch[0], M * sizeof(double), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess) return 1;
    err = cudaMemcpy(u2, g_adi_cuda_ctx.d_u_batch[1], M * sizeof(double), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess) return 1;
    err = cudaMemcpy(u3, g_adi_cuda_ctx.d_u_batch[2], M * sizeof(double), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess) return 1;

    cudaDeviceSynchronize();

    /* Keep compatibility with profiling parser by recording 3 synthetic steps. */
    for (int k = 0; k < 3; k++) {
        ADI_ProfileData prof = {0};
        prof.step_number = g_adi_step_count++;
        prof.grid_size = M;
        prof.total_ms = 0.0f;
        adi_cuda_profiling_record(prof);
    }
    return 0;
}

/* Cleanup hook - call this at program exit */
__attribute__((destructor))
static void adi_cuda_cleanup_atexit(void) {
    if (g_adi_cuda_initialized) {
        adi_cuda_profiling_finalize();
        adi_cuda_cleanup();
    }
}

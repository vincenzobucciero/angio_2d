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
    double *d_ax, *d_bx, *d_cx;
    double *d_ay, *d_by, *d_cy;
    
    /* cuSPARSE context */
    cusparseHandle_t cusparse_handle;
    
    /* Profiling */
    cudaEvent_t event_start, event_h2d, event_x_sweep, event_y_sweep, event_d2h, event_end;
} ADI_CUDA_Context;

static ADI_CUDA_Context g_adi_cuda_ctx = {0};
static int g_adi_cuda_initialized = 0;
static int g_adi_step_count = 0;

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
    
    g_adi_cuda_initialized = 1;
    return 0;
}

static void adi_cuda_cleanup(void) {
    if (!g_adi_cuda_initialized) return;
    
    cudaFree(g_adi_cuda_ctx.d_u);
    cudaFree(g_adi_cuda_ctx.d_rhs);
    cudaFree(g_adi_cuda_ctx.d_u_star);
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
    
    g_adi_cuda_initialized = 0;
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
    
    /* === PHASE 2: Setup coefficients === */
    double tau2 = tau / 2.0;
    double rx = d_coeff * tau2 / (hx * hx);
    double ry = d_coeff * tau2 / (hy * hy);
    
    /* Setup x-coefficients on CPU (could be on GPU if needed) */
    double *ax = (double*)malloc(Mx * sizeof(double));
    double *bx = (double*)malloc(Mx * sizeof(double));
    double *cx = (double*)malloc(Mx * sizeof(double));
    
    for (int i = 0; i < Mx; i++) {
        ax[i] = -rx;
        bx[i] = 1.0 + 2.0 * rx;
        cx[i] = -rx;
    }
    ax[0] = 0.0;
    cx[0] = -2.0 * rx;
    ax[Mx - 1] = -2.0 * rx;
    cx[Mx - 1] = 0.0;
    
    /* Setup y-coefficients on CPU */
    double *ay = (double*)malloc(My * sizeof(double));
    double *by = (double*)malloc(My * sizeof(double));
    double *cy = (double*)malloc(My * sizeof(double));
    
    for (int j = 0; j < My; j++) {
        ay[j] = -ry;
        by[j] = 1.0 + 2.0 * ry;
        cy[j] = -ry;
    }
    ay[0] = 0.0;
    cy[0] = -2.0 * ry;
    ay[My - 1] = -2.0 * ry;
    cy[My - 1] = 0.0;
    
    /* Copy coefficients to device */
    cudaMemcpy(g_adi_cuda_ctx.d_ax, ax, Mx * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_bx, bx, Mx * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_cx, cx, Mx * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_ay, ay, My * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_by, by, My * sizeof(double), cudaMemcpyHostToDevice);
    cudaMemcpy(g_adi_cuda_ctx.d_cy, cy, My * sizeof(double), cudaMemcpyHostToDevice);
    
    free(ax); free(bx); free(cx);
    free(ay); free(by); free(cy);
    
    /* === PHASE 3: X-SWEEP === */
    /* Compute RHS for x-sweep */
    int block_size = 256;
    int grid_size = (M + block_size - 1) / block_size;
    compute_rhs_x<<<grid_size, block_size>>>(g_adi_cuda_ctx.d_u, g_adi_cuda_ctx.d_rhs, Mx, My, ry);
    
    /* Solve tridiagonal systems along x (row-wise) */
    thomas_solve_batch_x<<<My, 1>>>(g_adi_cuda_ctx.d_ax, g_adi_cuda_ctx.d_bx, g_adi_cuda_ctx.d_cx,
                                     g_adi_cuda_ctx.d_rhs, g_adi_cuda_ctx.d_u_star, Mx, My, Mx);
    
    cudaEventRecord(g_adi_cuda_ctx.event_x_sweep, 0);
    
    /* === PHASE 4: Y-SWEEP === */
    /* Compute RHS for y-sweep */
    compute_rhs_y<<<grid_size, block_size>>>(g_adi_cuda_ctx.d_u_star, g_adi_cuda_ctx.d_rhs, Mx, My, rx);
    
    /* Solve tridiagonal systems along y (column-wise) */
    int grid_y = (Mx + 32 - 1) / 32;
    thomas_solve_batch_y<<<grid_y, 32>>>(g_adi_cuda_ctx.d_ay, g_adi_cuda_ctx.d_by, g_adi_cuda_ctx.d_cy,
                                         g_adi_cuda_ctx.d_rhs, g_adi_cuda_ctx.d_u, My, Mx);
    
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

/* Cleanup hook - call this at program exit */
__attribute__((destructor))
static void adi_cuda_cleanup_atexit(void) {
    if (g_adi_cuda_initialized) {
        adi_cuda_profiling_finalize();
        adi_cuda_cleanup();
    }
}


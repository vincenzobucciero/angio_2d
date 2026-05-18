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
    extern __shared__ double s_tmp[];
    double *s_c = s_tmp;
    double *s_d = s_tmp + n;
    
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
    /* One block solves one column to avoid per-thread fixed-size stacks. */
    int i = blockIdx.x;
    if (i >= Mx) return;
    if (threadIdx.x != 0) return;
    extern __shared__ double s_tmp[];
    double *c_star = s_tmp;
    double *d_star = s_tmp + n;
    
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

__global__ void reaction_half_step_kernel(
    const double *C, const double *P, const double *Inh, const double *F,
    double *C_out, double *P_out, double *Inh_out, double *F_out,
    const double *T, const double *phi_x, const double *phi_y,
    int Mx, int My,
    double inv_hx2, double inv_hy2, double inv_2hx, double inv_2hy,
    double alpha1, double alpha2, double alpha3,
    double k1, double k2, double k3, double k4, double k5, double k6,
    double dt)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int M = Mx * My;
    if (idx >= M) return;

    int i = idx % Mx;
    int j = idx / Mx;

    int im = (i == 0) ? 1 : (i - 1);
    int ip = (i == Mx - 1) ? (Mx - 2) : (i + 1);
    int jm = (j == 0) ? 1 : (j - 1);
    int jp = (j == My - 1) ? (My - 2) : (j + 1);

    double gx_I = (i == 0 || i == Mx - 1) ? 0.0 : (Inh[ip + Mx * j] - Inh[im + Mx * j]) * inv_2hx;
    double gy_I = (j == 0 || j == My - 1) ? 0.0 : (Inh[i + Mx * jp] - Inh[i + Mx * jm]) * inv_2hy;
    double gx_F = (i == 0 || i == Mx - 1) ? 0.0 : (F[ip + Mx * j] - F[im + Mx * j]) * inv_2hx;
    double gy_F = (j == 0 || j == My - 1) ? 0.0 : (F[i + Mx * jp] - F[i + Mx * jm]) * inv_2hy;
    double gx_C = (i == 0 || i == Mx - 1) ? 0.0 : (C[ip + Mx * j] - C[im + Mx * j]) * inv_2hx;
    double gy_C = (j == 0 || j == My - 1) ? 0.0 : (C[i + Mx * jp] - C[i + Mx * jm]) * inv_2hy;

    double lap_I = ((Inh[im + Mx * j] - 2.0 * Inh[idx] + Inh[ip + Mx * j]) * inv_hx2) +
                   ((Inh[i + Mx * jm] - 2.0 * Inh[idx] + Inh[i + Mx * jp]) * inv_hy2);
    double lap_F = ((F[im + Mx * j] - 2.0 * F[idx] + F[ip + Mx * j]) * inv_hx2) +
                   ((F[i + Mx * jm] - 2.0 * F[idx] + F[i + Mx * jp]) * inv_hy2);

    double vx = alpha2 * gx_I - alpha1 * gx_F - alpha3 * phi_x[idx];
    double vy = alpha2 * gy_I - alpha1 * gy_F - alpha3 * phi_y[idx];
    double div_v = alpha2 * lap_I - alpha1 * lap_F;

    double c = C[idx];
    double p = P[idx];
    double inh = Inh[idx];
    double f = F[idx];
    double t = T[idx];

    double C_rhs = vx * gx_C + vy * gy_C + div_v * c + k1 * c * (1.0 - c);
    double P_rhs = -k3 * p * inh + k4 * t * c + k5 * t - k6 * p;
    double I_rhs = -k3 * p * inh;
    double F_rhs = -k2 * p * f;

    double c_new = c + dt * C_rhs;
    double p_new = p + dt * P_rhs;
    double i_new = inh + dt * I_rhs;
    double f_new = f + dt * F_rhs;

    C_out[idx] = (c_new < 0.0) ? 0.0 : c_new;
    P_out[idx] = (p_new < 0.0) ? 0.0 : p_new;
    Inh_out[idx] = (i_new < 0.0) ? 0.0 : i_new;
    F_out[idx] = (f_new < 0.0) ? 0.0 : f_new;
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
    double *d_f;
    double *d_tmp_c, *d_tmp_p, *d_tmp_i, *d_tmp_f;
    double *d_taf_T, *d_taf_phi_x, *d_taf_phi_y;
    double *d_ax, *d_bx, *d_cx;
    double *d_ay, *d_by, *d_cy;
    double *d_ax_fields[3], *d_bx_fields[3], *d_cx_fields[3];
    double *d_ay_fields[3], *d_by_fields[3], *d_cy_fields[3];
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
static int g_cuda_session_active = 0;
static int g_cuda_profiling_initialized = 0;

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

static int upload_coefficients_device(double *d_ax, double *d_bx, double *d_cx,
                                      double *d_ay, double *d_by, double *d_cy,
                                      int Mx, int My, double hx, double hy, double d_coeff, double tau) {
    setup_coefficients_host(Mx, My, hx, hy, d_coeff, tau);
    if (cudaMemcpy(d_ax, g_adi_cuda_ctx.h_ax, Mx * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(d_bx, g_adi_cuda_ctx.h_bx, Mx * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(d_cx, g_adi_cuda_ctx.h_cx, Mx * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(d_ay, g_adi_cuda_ctx.h_ay, My * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(d_by, g_adi_cuda_ctx.h_by, My * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(d_cy, g_adi_cuda_ctx.h_cy, My * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    return 0;
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
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_f, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_tmp_c, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_tmp_p, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_tmp_i, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_tmp_f, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_taf_T, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_taf_phi_x, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    err = cudaMalloc((void**)&g_adi_cuda_ctx.d_taf_phi_y, M * sizeof(double));
    if (err != cudaSuccess) return 1;
    
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

    for (int k = 0; k < 3; k++) {
        if (cudaMalloc((void**)&g_adi_cuda_ctx.d_ax_fields[k], Mx * sizeof(double)) != cudaSuccess) return 1;
        if (cudaMalloc((void**)&g_adi_cuda_ctx.d_bx_fields[k], Mx * sizeof(double)) != cudaSuccess) return 1;
        if (cudaMalloc((void**)&g_adi_cuda_ctx.d_cx_fields[k], Mx * sizeof(double)) != cudaSuccess) return 1;
        if (cudaMalloc((void**)&g_adi_cuda_ctx.d_ay_fields[k], My * sizeof(double)) != cudaSuccess) return 1;
        if (cudaMalloc((void**)&g_adi_cuda_ctx.d_by_fields[k], My * sizeof(double)) != cudaSuccess) return 1;
        if (cudaMalloc((void**)&g_adi_cuda_ctx.d_cy_fields[k], My * sizeof(double)) != cudaSuccess) return 1;
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
    cudaFree(g_adi_cuda_ctx.d_f);
    cudaFree(g_adi_cuda_ctx.d_tmp_c);
    cudaFree(g_adi_cuda_ctx.d_tmp_p);
    cudaFree(g_adi_cuda_ctx.d_tmp_i);
    cudaFree(g_adi_cuda_ctx.d_tmp_f);
    cudaFree(g_adi_cuda_ctx.d_taf_T);
    cudaFree(g_adi_cuda_ctx.d_taf_phi_x);
    cudaFree(g_adi_cuda_ctx.d_taf_phi_y);
    cudaFree(g_adi_cuda_ctx.d_ax);
    cudaFree(g_adi_cuda_ctx.d_bx);
    cudaFree(g_adi_cuda_ctx.d_cx);
    cudaFree(g_adi_cuda_ctx.d_ay);
    cudaFree(g_adi_cuda_ctx.d_by);
    cudaFree(g_adi_cuda_ctx.d_cy);
    for (int k = 0; k < 3; k++) {
        cudaFree(g_adi_cuda_ctx.d_ax_fields[k]);
        cudaFree(g_adi_cuda_ctx.d_bx_fields[k]);
        cudaFree(g_adi_cuda_ctx.d_cx_fields[k]);
        cudaFree(g_adi_cuda_ctx.d_ay_fields[k]);
        cudaFree(g_adi_cuda_ctx.d_by_fields[k]);
        cudaFree(g_adi_cuda_ctx.d_cy_fields[k]);
    }
    
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

static int adi_cuda_diffuse_device_array(double *d_u, int Mx, int My, double hx, double hy, double d_coeff, double tau,
                                         double *d_ax, double *d_bx, double *d_cx,
                                         double *d_ay, double *d_by, double *d_cy,
                                         float *ms_x, float *ms_y) {
    int M = Mx * My;
    double tau2 = tau / 2.0;
    double rx = d_coeff * tau2 / (hx * hx);
    double ry = d_coeff * tau2 / (hy * hy);

    cudaEventRecord(g_adi_cuda_ctx.event_start, 0);
    int block_size = 256;
    int grid_size = (M + block_size - 1) / block_size;
    size_t shmem_x = (size_t)(2 * Mx) * sizeof(double);
    size_t shmem_y = (size_t)(2 * My) * sizeof(double);
    compute_rhs_x<<<grid_size, block_size>>>(d_u, g_adi_cuda_ctx.d_rhs, Mx, My, ry);
    thomas_solve_batch_x<<<My, 1, shmem_x>>>(d_ax, d_bx, d_cx,
                                    g_adi_cuda_ctx.d_rhs, g_adi_cuda_ctx.d_u_star, Mx, My, Mx);
    cudaEventRecord(g_adi_cuda_ctx.event_x_sweep, 0);
    compute_rhs_y<<<grid_size, block_size>>>(g_adi_cuda_ctx.d_u_star, g_adi_cuda_ctx.d_rhs, Mx, My, rx);
    thomas_solve_batch_y<<<Mx, 1, shmem_y>>>(d_ay, d_by, d_cy,
                                         g_adi_cuda_ctx.d_rhs, d_u, My, Mx);
    cudaEventRecord(g_adi_cuda_ctx.event_y_sweep, 0);
    cudaDeviceSynchronize();
    if (ms_x) cudaEventElapsedTime(ms_x, g_adi_cuda_ctx.event_start, g_adi_cuda_ctx.event_x_sweep);
    if (ms_y) cudaEventElapsedTime(ms_y, g_adi_cuda_ctx.event_x_sweep, g_adi_cuda_ctx.event_y_sweep);
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "ERROR: adi_cuda_diffuse_device_array failed: %s (Mx=%d My=%d)\n",
                cudaGetErrorString(err), Mx, My);
        return 1;
    }
    return 0;
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
        g_cuda_profiling_initialized = 1;
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
    if (upload_coefficients_device(g_adi_cuda_ctx.d_ax, g_adi_cuda_ctx.d_bx, g_adi_cuda_ctx.d_cx,
                                   g_adi_cuda_ctx.d_ay, g_adi_cuda_ctx.d_by, g_adi_cuda_ctx.d_cy,
                                   Mx, My, hx, hy, d_coeff, tau) != 0) {
        return 1;
    }
    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u, Mx, My, hx, hy, d_coeff, tau,
                                      g_adi_cuda_ctx.d_ax, g_adi_cuda_ctx.d_bx, g_adi_cuda_ctx.d_cx,
                                      g_adi_cuda_ctx.d_ay, g_adi_cuda_ctx.d_by, g_adi_cuda_ctx.d_cy,
                                      &prof.x_sweep_ms, &prof.y_sweep_ms) != 0) {
        fprintf(stderr, "ERROR: CUDA kernel execution failed\n");
        return 1;
    }
    
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
    ms_x = prof.x_sweep_ms;
    ms_y = prof.y_sweep_ms;
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
        g_cuda_profiling_initialized = 1;
    }
    if (Mx != g_adi_cuda_ctx.Mx || My != g_adi_cuda_ctx.My) {
        return 1;
    }

    const int M = Mx * My;
    cudaError_t err;

    double *u_host[3] = {u1, u2, u3};
    double *d_u[3] = {g_adi_cuda_ctx.d_u_batch[0], g_adi_cuda_ctx.d_u_batch[1], g_adi_cuda_ctx.d_u_batch[2]};
    double d_coeff[3] = {d1, d2, d3};
    for (int k = 0; k < 3; k++) {
        ADI_ProfileData prof = {0};
        float ms_x = 0.0f, ms_y = 0.0f;
        cudaEventRecord(g_adi_cuda_ctx.event_start, 0);
        err = cudaMemcpy(d_u[k], u_host[k], M * sizeof(double), cudaMemcpyHostToDevice);
        if (err != cudaSuccess) return 1;
        cudaEventRecord(g_adi_cuda_ctx.event_h2d, 0);
        if (upload_coefficients_device(g_adi_cuda_ctx.d_ax, g_adi_cuda_ctx.d_bx, g_adi_cuda_ctx.d_cx,
                                       g_adi_cuda_ctx.d_ay, g_adi_cuda_ctx.d_by, g_adi_cuda_ctx.d_cy,
                                       Mx, My, hx, hy, d_coeff[k], tau) != 0) return 1;
        if (adi_cuda_diffuse_device_array(d_u[k], Mx, My, hx, hy, d_coeff[k], tau,
                                          g_adi_cuda_ctx.d_ax, g_adi_cuda_ctx.d_bx, g_adi_cuda_ctx.d_cx,
                                          g_adi_cuda_ctx.d_ay, g_adi_cuda_ctx.d_by, g_adi_cuda_ctx.d_cy,
                                          &ms_x, &ms_y) != 0) return 1;
        err = cudaMemcpy(u_host[k], d_u[k], M * sizeof(double), cudaMemcpyDeviceToHost);
        if (err != cudaSuccess) return 1;
        cudaEventRecord(g_adi_cuda_ctx.event_d2h, 0);
        cudaDeviceSynchronize();
        cudaEventRecord(g_adi_cuda_ctx.event_end, 0);
        cudaEventElapsedTime(&prof.h2d_copy_ms, g_adi_cuda_ctx.event_start, g_adi_cuda_ctx.event_h2d);
        prof.x_sweep_ms = ms_x;
        prof.y_sweep_ms = ms_y;
        cudaEventElapsedTime(&prof.d2h_copy_ms, g_adi_cuda_ctx.event_y_sweep, g_adi_cuda_ctx.event_d2h);
        cudaEventElapsedTime(&prof.sync_time_ms, g_adi_cuda_ctx.event_d2h, g_adi_cuda_ctx.event_end);
        cudaEventElapsedTime(&prof.total_ms, g_adi_cuda_ctx.event_start, g_adi_cuda_ctx.event_end);
        prof.step_number = g_adi_step_count++;
        prof.grid_size = M;
        adi_cuda_profiling_record(prof);
    }
    return 0;
}

static void swap_ptr(double **a, double **b) {
    double *tmp = *a;
    *a = *b;
    *b = tmp;
}

int adi_cuda_session_init(const double *C, const double *P, const double *Inh, const double *F,
                          const TAF *taf, const Params *p) {
    if (!C || !P || !Inh || !F || !taf || !p) return 1;
    if (!g_adi_cuda_initialized && adi_cuda_init(p->Mx, p->My) != 0) return 1;
    if (!g_cuda_profiling_initialized) {
        adi_cuda_profiling_init(p->Nsteps + 8);
        g_cuda_profiling_initialized = 1;
    }
    int M = p->Mx * p->My;
    if (cudaMemcpy(g_adi_cuda_ctx.d_u_batch[0], C, M * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(g_adi_cuda_ctx.d_u_batch[1], P, M * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(g_adi_cuda_ctx.d_u_batch[2], Inh, M * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(g_adi_cuda_ctx.d_f, F, M * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(g_adi_cuda_ctx.d_taf_T, taf->T, M * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(g_adi_cuda_ctx.d_taf_phi_x, taf->phi_x, M * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (cudaMemcpy(g_adi_cuda_ctx.d_taf_phi_y, taf->phi_y, M * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) return 1;
    if (upload_coefficients_device(g_adi_cuda_ctx.d_ax_fields[0], g_adi_cuda_ctx.d_bx_fields[0], g_adi_cuda_ctx.d_cx_fields[0],
                                   g_adi_cuda_ctx.d_ay_fields[0], g_adi_cuda_ctx.d_by_fields[0], g_adi_cuda_ctx.d_cy_fields[0],
                                   p->Mx, p->My, p->hx, p->hy, p->dC, p->tau) != 0) return 1;
    if (upload_coefficients_device(g_adi_cuda_ctx.d_ax_fields[1], g_adi_cuda_ctx.d_bx_fields[1], g_adi_cuda_ctx.d_cx_fields[1],
                                   g_adi_cuda_ctx.d_ay_fields[1], g_adi_cuda_ctx.d_by_fields[1], g_adi_cuda_ctx.d_cy_fields[1],
                                   p->Mx, p->My, p->hx, p->hy, p->dP, p->tau) != 0) return 1;
    if (upload_coefficients_device(g_adi_cuda_ctx.d_ax_fields[2], g_adi_cuda_ctx.d_bx_fields[2], g_adi_cuda_ctx.d_cx_fields[2],
                                   g_adi_cuda_ctx.d_ay_fields[2], g_adi_cuda_ctx.d_by_fields[2], g_adi_cuda_ctx.d_cy_fields[2],
                                   p->Mx, p->My, p->hx, p->hy, p->dI, p->tau) != 0) return 1;
    g_cuda_session_active = 1;
    return 0;
}

int adi_cuda_session_step(const Params *p, double tau, double tau_half) {
    if (!g_cuda_session_active || !p) return 1;
    int M = p->Mx * p->My;
    int block_size = 256;
    int grid_size = (M + block_size - 1) / block_size;
    reaction_half_step_kernel<<<grid_size, block_size>>>(
        g_adi_cuda_ctx.d_u_batch[0], g_adi_cuda_ctx.d_u_batch[1], g_adi_cuda_ctx.d_u_batch[2], g_adi_cuda_ctx.d_f,
        g_adi_cuda_ctx.d_tmp_c, g_adi_cuda_ctx.d_tmp_p, g_adi_cuda_ctx.d_tmp_i, g_adi_cuda_ctx.d_tmp_f,
        g_adi_cuda_ctx.d_taf_T, g_adi_cuda_ctx.d_taf_phi_x, g_adi_cuda_ctx.d_taf_phi_y,
        p->Mx, p->My, 1.0 / (p->hx * p->hx), 1.0 / (p->hy * p->hy), 0.5 / p->hx, 0.5 / p->hy,
        p->alpha1, p->alpha2, p->alpha3, p->k1, p->k2, p->k3, p->k4, p->k5, p->k6, tau_half);
    swap_ptr(&g_adi_cuda_ctx.d_u_batch[0], &g_adi_cuda_ctx.d_tmp_c);
    swap_ptr(&g_adi_cuda_ctx.d_u_batch[1], &g_adi_cuda_ctx.d_tmp_p);
    swap_ptr(&g_adi_cuda_ctx.d_u_batch[2], &g_adi_cuda_ctx.d_tmp_i);
    swap_ptr(&g_adi_cuda_ctx.d_f, &g_adi_cuda_ctx.d_tmp_f);
    cudaError_t kerr = cudaGetLastError();
    if (kerr != cudaSuccess) {
        fprintf(stderr, "ERROR: reaction_half_step_kernel (pre-ADI) failed: %s\n", cudaGetErrorString(kerr));
        return 1;
    }

    float ms_x = 0.0f, ms_y = 0.0f;
    ADI_ProfileData prof = {0};
    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u_batch[0], p->Mx, p->My, p->hx, p->hy, p->dC, tau,
                                      g_adi_cuda_ctx.d_ax_fields[0], g_adi_cuda_ctx.d_bx_fields[0], g_adi_cuda_ctx.d_cx_fields[0],
                                      g_adi_cuda_ctx.d_ay_fields[0], g_adi_cuda_ctx.d_by_fields[0], g_adi_cuda_ctx.d_cy_fields[0],
                                      &ms_x, &ms_y) != 0) return 1;
    prof.step_number = g_adi_step_count++;
    prof.grid_size = M;
    prof.h2d_copy_ms = 0.0f;
    prof.x_sweep_ms = ms_x;
    prof.y_sweep_ms = ms_y;
    prof.d2h_copy_ms = 0.0f;
    prof.sync_time_ms = 0.0f;
    prof.total_ms = ms_x + ms_y;
    adi_cuda_profiling_record(prof);
    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u_batch[1], p->Mx, p->My, p->hx, p->hy, p->dP, tau,
                                      g_adi_cuda_ctx.d_ax_fields[1], g_adi_cuda_ctx.d_bx_fields[1], g_adi_cuda_ctx.d_cx_fields[1],
                                      g_adi_cuda_ctx.d_ay_fields[1], g_adi_cuda_ctx.d_by_fields[1], g_adi_cuda_ctx.d_cy_fields[1],
                                      &ms_x, &ms_y) != 0) return 1;
    prof.step_number = g_adi_step_count++;
    prof.h2d_copy_ms = 0.0f;
    prof.x_sweep_ms = ms_x;
    prof.y_sweep_ms = ms_y;
    prof.d2h_copy_ms = 0.0f;
    prof.sync_time_ms = 0.0f;
    prof.total_ms = ms_x + ms_y;
    adi_cuda_profiling_record(prof);
    if (adi_cuda_diffuse_device_array(g_adi_cuda_ctx.d_u_batch[2], p->Mx, p->My, p->hx, p->hy, p->dI, tau,
                                      g_adi_cuda_ctx.d_ax_fields[2], g_adi_cuda_ctx.d_bx_fields[2], g_adi_cuda_ctx.d_cx_fields[2],
                                      g_adi_cuda_ctx.d_ay_fields[2], g_adi_cuda_ctx.d_by_fields[2], g_adi_cuda_ctx.d_cy_fields[2],
                                      &ms_x, &ms_y) != 0) return 1;
    prof.step_number = g_adi_step_count++;
    prof.h2d_copy_ms = 0.0f;
    prof.x_sweep_ms = ms_x;
    prof.y_sweep_ms = ms_y;
    prof.d2h_copy_ms = 0.0f;
    prof.sync_time_ms = 0.0f;
    prof.total_ms = ms_x + ms_y;
    adi_cuda_profiling_record(prof);

    reaction_half_step_kernel<<<grid_size, block_size>>>(
        g_adi_cuda_ctx.d_u_batch[0], g_adi_cuda_ctx.d_u_batch[1], g_adi_cuda_ctx.d_u_batch[2], g_adi_cuda_ctx.d_f,
        g_adi_cuda_ctx.d_tmp_c, g_adi_cuda_ctx.d_tmp_p, g_adi_cuda_ctx.d_tmp_i, g_adi_cuda_ctx.d_tmp_f,
        g_adi_cuda_ctx.d_taf_T, g_adi_cuda_ctx.d_taf_phi_x, g_adi_cuda_ctx.d_taf_phi_y,
        p->Mx, p->My, 1.0 / (p->hx * p->hx), 1.0 / (p->hy * p->hy), 0.5 / p->hx, 0.5 / p->hy,
        p->alpha1, p->alpha2, p->alpha3, p->k1, p->k2, p->k3, p->k4, p->k5, p->k6, tau_half);
    swap_ptr(&g_adi_cuda_ctx.d_u_batch[0], &g_adi_cuda_ctx.d_tmp_c);
    swap_ptr(&g_adi_cuda_ctx.d_u_batch[1], &g_adi_cuda_ctx.d_tmp_p);
    swap_ptr(&g_adi_cuda_ctx.d_u_batch[2], &g_adi_cuda_ctx.d_tmp_i);
    swap_ptr(&g_adi_cuda_ctx.d_f, &g_adi_cuda_ctx.d_tmp_f);
    kerr = cudaGetLastError();
    if (kerr != cudaSuccess) {
        fprintf(stderr, "ERROR: reaction_half_step_kernel (post-ADI) failed: %s\n", cudaGetErrorString(kerr));
        return 1;
    }
    return 0;
}

int adi_cuda_session_copy_cf(double *C, double *F) {
    if (!g_cuda_session_active || !C || !F) return 1;
    int M = g_adi_cuda_ctx.M;
    if (cudaMemcpy(C, g_adi_cuda_ctx.d_u_batch[0], M * sizeof(double), cudaMemcpyDeviceToHost) != cudaSuccess) return 1;
    if (cudaMemcpy(F, g_adi_cuda_ctx.d_f, M * sizeof(double), cudaMemcpyDeviceToHost) != cudaSuccess) return 1;
    return 0;
}

int adi_cuda_session_copy_all(double *C, double *P, double *Inh, double *F) {
    if (!g_cuda_session_active || !C || !P || !Inh || !F) return 1;
    int M = g_adi_cuda_ctx.M;
    if (cudaMemcpy(C, g_adi_cuda_ctx.d_u_batch[0], M * sizeof(double), cudaMemcpyDeviceToHost) != cudaSuccess) return 1;
    if (cudaMemcpy(P, g_adi_cuda_ctx.d_u_batch[1], M * sizeof(double), cudaMemcpyDeviceToHost) != cudaSuccess) return 1;
    if (cudaMemcpy(Inh, g_adi_cuda_ctx.d_u_batch[2], M * sizeof(double), cudaMemcpyDeviceToHost) != cudaSuccess) return 1;
    if (cudaMemcpy(F, g_adi_cuda_ctx.d_f, M * sizeof(double), cudaMemcpyDeviceToHost) != cudaSuccess) return 1;
    return 0;
}

int adi_cuda_get_device_info(int *device_id, char *name_buf, int name_buf_len, int *session_active) {
    /* Lightweight runtime introspection for startup run banner in main.c. */
    int dev = -1;
    cudaDeviceProp prop;
    if (cudaGetDevice(&dev) != cudaSuccess) return 1;
    if (cudaGetDeviceProperties(&prop, dev) != cudaSuccess) return 1;
    if (device_id) *device_id = dev;
    if (session_active) *session_active = g_cuda_session_active;
    if (name_buf && name_buf_len > 0) {
        int i = 0;
        for (; i < name_buf_len - 1 && prop.name[i] != '\0'; i++) {
            name_buf[i] = prop.name[i];
        }
        name_buf[i] = '\0';
    }
    return 0;
}

void adi_cuda_session_finalize(void) {
    g_cuda_session_active = 0;
    if (g_cuda_profiling_initialized) {
        adi_cuda_profiling_finalize();
        g_cuda_profiling_initialized = 0;
    }
}

/* Cleanup hook - call this at program exit */
__attribute__((destructor))
static void adi_cuda_cleanup_atexit(void) {
    if (g_adi_cuda_initialized) {
        if (g_cuda_profiling_initialized) {
            adi_cuda_profiling_finalize();
            g_cuda_profiling_initialized = 0;
        }
        adi_cuda_cleanup();
    }
}

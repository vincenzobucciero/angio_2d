#ifndef ADI_CUDA_PROFILING_H
#define ADI_CUDA_PROFILING_H

#include <stdio.h>
#include <stdlib.h>

/* Profiling data for a single ADI step */
typedef struct {
    float h2d_copy_ms;         /* Host->Device memory copy time */
    float x_sweep_ms;          /* X-sweep kernel time */
    float y_sweep_ms;          /* Y-sweep kernel time */
    float d2h_copy_ms;         /* Device->Host memory copy time */
    float sync_time_ms;        /* Synchronization overhead */
    float total_ms;            /* Total time for this ADI step */
    int grid_size;             /* Grid size (Mx * My) */
    int step_number;           /* Step number in simulation */
} ADI_ProfileData;

#ifdef __cplusplus
extern "C" {
#endif

/* Global profiling context */
extern ADI_ProfileData *g_adi_profile_data;
extern int g_adi_profile_count;
extern int g_adi_profile_max;
extern FILE *g_adi_profile_file;

/* Initialize profiling */
void adi_cuda_profiling_init(int max_steps);
void adi_cuda_profiling_record(ADI_ProfileData data);
void adi_cuda_profiling_finalize(void);

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif

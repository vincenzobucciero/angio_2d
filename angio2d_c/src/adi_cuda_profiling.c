#include "adi_cuda_profiling.h"

/* Make symbols visible to C++ code */
#ifdef __cplusplus
extern "C" {
#endif

ADI_ProfileData *g_adi_profile_data = NULL;
int g_adi_profile_count = 0;
int g_adi_profile_max = 0;
FILE *g_adi_profile_file = NULL;

void adi_cuda_profiling_init(int max_steps) {
    g_adi_profile_max = max_steps * 3;  /* 3 fields (C, P, Inh) per step */
    g_adi_profile_data = (ADI_ProfileData*)malloc(g_adi_profile_max * sizeof(ADI_ProfileData));
    g_adi_profile_count = 0;
    
    /* Open log file */
    g_adi_profile_file = fopen("output/cuda_profiling_log.txt", "w");
    if (g_adi_profile_file) {
        fprintf(g_adi_profile_file, "ADI CUDA Profiling Log\n");
        fprintf(g_adi_profile_file, "======================\n\n");
        fprintf(g_adi_profile_file, "step,grid_size,h2d_copy_ms,x_sweep_ms,y_sweep_ms,d2h_copy_ms,sync_ms,total_ms\n");
        fflush(g_adi_profile_file);
    }
}

void adi_cuda_profiling_record(ADI_ProfileData data) {
    if (g_adi_profile_count < g_adi_profile_max) {
        g_adi_profile_data[g_adi_profile_count] = data;
        g_adi_profile_count++;
        
        if (g_adi_profile_file) {
            fprintf(g_adi_profile_file, "%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n",
                    data.step_number,
                    data.grid_size,
                    data.h2d_copy_ms,
                    data.x_sweep_ms,
                    data.y_sweep_ms,
                    data.d2h_copy_ms,
                    data.sync_time_ms,
                    data.total_ms);
            fflush(g_adi_profile_file);
        }
    }
}

void adi_cuda_profiling_finalize(void) {
    if (g_adi_profile_file) {
        fprintf(g_adi_profile_file, "\n\nSummary Statistics\n");
        fprintf(g_adi_profile_file, "===================\n");
        
        if (g_adi_profile_count > 0) {
            float total_h2d = 0, total_x = 0, total_y = 0, total_d2h = 0, total_sync = 0, total = 0;
            
            for (int i = 0; i < g_adi_profile_count; i++) {
                total_h2d += g_adi_profile_data[i].h2d_copy_ms;
                total_x += g_adi_profile_data[i].x_sweep_ms;
                total_y += g_adi_profile_data[i].y_sweep_ms;
                total_d2h += g_adi_profile_data[i].d2h_copy_ms;
                total_sync += g_adi_profile_data[i].sync_time_ms;
                total += g_adi_profile_data[i].total_ms;
            }
            
            fprintf(g_adi_profile_file, "Total ADI calls: %d\n", g_adi_profile_count);
            fprintf(g_adi_profile_file, "Total H2D copy:   %.4f ms (%.1f%%)\n", total_h2d, 100.0*total_h2d/total);
            fprintf(g_adi_profile_file, "Total X-sweep:    %.4f ms (%.1f%%)\n", total_x, 100.0*total_x/total);
            fprintf(g_adi_profile_file, "Total Y-sweep:    %.4f ms (%.1f%%)\n", total_y, 100.0*total_y/total);
            fprintf(g_adi_profile_file, "Total D2H copy:   %.4f ms (%.1f%%)\n", total_d2h, 100.0*total_d2h/total);
            fprintf(g_adi_profile_file, "Total sync:       %.4f ms (%.1f%%)\n", total_sync, 100.0*total_sync/total);
            fprintf(g_adi_profile_file, "Total runtime:    %.4f ms\n", total);
            fprintf(g_adi_profile_file, "\nAverage per call:\n");
            fprintf(g_adi_profile_file, "  H2D: %.4f ms\n", total_h2d / g_adi_profile_count);
            fprintf(g_adi_profile_file, "  X-sweep: %.4f ms\n", total_x / g_adi_profile_count);
            fprintf(g_adi_profile_file, "Y-sweep: %.4f ms\n", total_y / g_adi_profile_count);
            fprintf(g_adi_profile_file, "  D2H: %.4f ms\n", total_d2h / g_adi_profile_count);
            fprintf(g_adi_profile_file, "  Sync: %.4f ms\n", total_sync / g_adi_profile_count);
            fprintf(g_adi_profile_file, "  Total: %.4f ms\n", total / g_adi_profile_count);
        }
        
        fclose(g_adi_profile_file);
    }
    
    if (g_adi_profile_data) {
        free(g_adi_profile_data);
    }
}

#ifdef __cplusplus
}  /* extern "C" */
#endif

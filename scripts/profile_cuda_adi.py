#!/usr/bin/env python3
"""
CUDA ADI Profiling Script for ANGIO2D HPC

Compiles and profiles the CUDA ADI solver on HPC.
- Responsibly limited to small/medium grids
- Generates detailed profiling reports
- No saturation or excessive resource use
"""

import os
import sys
import subprocess
import json
import csv
import argparse
import time
from pathlib import Path
from datetime import datetime

class CUDAProfiler:
    def __init__(self, project_dir="/home/c.coppola/projects/angio_2d"):
        self.project_dir = Path(project_dir)
        self.angio2d_dir = self.project_dir / "angio2d_c"
        self.results_dir = self.project_dir / "results" / "cuda_profiling"
        self.results_dir.mkdir(parents=True, exist_ok=True)
        
    def compile_cuda(self):
        """Compile ANGIO2D with CUDA support"""
        print("[COMPILE] Building ANGIO2D with CUDA support...")
        os.chdir(self.angio2d_dir)
        
        result = subprocess.run([
            "make", "cuda",
            "NVCC=nvcc",
            "CUDA_NVCCFLAGS=-O2 -arch=sm_70"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        
        if result.returncode != 0:
            print("[ERROR] CUDA compilation failed!")
            print(result.stderr)
            return False
            
        print("[COMPILE] Build successful ✓")
        return True
    
    def compile_openmp(self):
        """Compile ANGIO2D with OpenMP for comparison"""
        print("[COMPILE] Building ANGIO2D with OpenMP...")
        os.chdir(self.angio2d_dir)
        
        result = subprocess.run([
            "make", "openmp"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        
        if result.returncode != 0:
            print("[ERROR] OpenMP compilation failed!")
            print(result.stderr)
            return False
            
        print("[COMPILE] Build successful ✓")
        return True
    
    def run_benchmark(self, binary, grid_config, name, backend=None):
        """Run a single benchmark"""
        grid_size = grid_config["size"]
        nsteps = grid_config["steps"]
        
        print(f"[BENCHMARK] Running {name} ({grid_size}x{grid_size}, {nsteps} steps)...")
        
        # Create temporary output directory
        temp_output = self.results_dir / f"run_{name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        temp_output.mkdir(parents=True, exist_ok=True)
        
        # Prepare config file (format: - { Mx: X, My: Y } on one line)
        config_path = temp_output / "benchmark.yaml"
        with open(config_path, 'w') as f:
            f.write(f"grid:\n  - {{ Mx: {grid_size}, My: {grid_size} }}\n")
        
        # Run benchmark
        env = os.environ.copy()
        if backend == "cuda":
            env["ANGIO2D_BACKEND"] = "cuda"
            print(f"[BENCHMARK] CUDA backend enabled (ANGIO2D_BACKEND=cuda)")
        
        # Measure wall time
        t_start = time.time()
        
        result = subprocess.run([
            str(binary),
            "--config", str(config_path),
            "--grid-index", "0"
        ], cwd=temp_output, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, env=env, timeout=3600)
        
        t_end = time.time()
        wall_time = t_end - t_start
        
        if result.returncode != 0:
            print(f"[ERROR] Benchmark failed: {result.stderr}")
            return None
        
        # Check for CUDA fallback warning in stderr
        if backend == "cuda" and "falling back to CPU ADI" in result.stderr:
            print(f"[WARNING] CUDA fallback detected! Check GPU or CUDA implementation.")
            print(result.stderr)
        
        # Extract profiling data
        result_data = {
            "name": name,
            "grid_size": grid_size,
            "nsteps": nsteps,
            "wall_time": wall_time,
            "backend": backend or "cpu",
            "output_dir": str(temp_output)
        }
        
        # Parse CUDA profiling log if it exists
        cuda_prof_file = temp_output / "cuda_profiling_log.txt"
        if cuda_prof_file.exists():
            result_data["cuda_profile"] = self._parse_cuda_profile(cuda_prof_file)
            print(f"[BENCHMARK] CUDA profiling data found ✓")
        
        # Parse timing file if it exists
        timing_file = temp_output / "csv" / "timing.csv"
        if timing_file.exists():
            result_data["solver_time"] = self._parse_timing(timing_file)
        
        print(f"[BENCHMARK] Completed in {wall_time:.2f}s ✓")
        return result_data
    
    def _parse_cuda_profile(self, log_file):
        """Parse CUDA profiling log"""
        data = {"lines": []}
        in_summary = False
        
        with open(log_file, 'r') as f:
            for line in f:
                line = line.strip()
                if "Summary Statistics" in line:
                    in_summary = True
                    continue
                    
                if in_summary and "," in line and "step" not in line:
                    parts = line.split(',')
                    if len(parts) >= 2:
                        data["lines"].append({
                            "field": parts[0],
                            "value": parts[1] if len(parts) > 1 else ""
                        })
        
        return data
    
    def _parse_timing(self, timing_file):
        """Parse timing CSV file"""
        timing = {}
        with open(timing_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                timing[row['component']] = float(row['time_seconds'])
        return timing
    
    def generate_report(self, results):
        """Generate profiling report"""
        report_file = self.results_dir / "profiling_summary.md"
        
        print(f"[REPORT] Generating {report_file}...")
        
        with open(report_file, 'w') as f:
            f.write("# CUDA ADI Profiling Report\n\n")
            f.write(f"Generated: {datetime.now().isoformat()}\n\n")
            
            f.write("## Benchmark Results\n\n")
            f.write("| Grid | Backend | Wall Time (s) | Solver Time (s) | Speedup |\n")
            f.write("|------|---------|---------------|-----------------|----------|\n")
            
            # Organize results by grid size
            by_grid = {}
            for result in results:
                key = result["grid_size"]
                if key not in by_grid:
                    by_grid[key] = {}
                by_grid[key][result["backend"]] = result
            
            # Generate comparison table
            for grid_size in sorted(by_grid.keys()):
                backends = by_grid[grid_size]
                
                for backend, result in backends.items():
                    solver_time = result.get("solver_time", {}).get("total_solver_time", result["wall_time"])
                    
                    # Calculate speedup vs OpenMP
                    speedup = "-"
                    if backend == "cuda" and "cpu" in backends:
                        cpu_time = backends.get("cpu", backends.get("openmp", {})).get("wall_time", 1.0)
                        if cpu_time > 0:
                            speedup = f"{cpu_time / result['wall_time']:.2f}x"
                    
                    f.write(f"| {grid_size}x{grid_size} | {backend.upper():6s} | {result['wall_time']:13.2f} | "
                           f"{solver_time:15.2f} | {speedup:8s} |\n")
            
            f.write("\n## CUDA Profiling Details\n\n")
            
            # CUDA-specific details
            for result in results:
                if result["backend"] == "cuda" and "cuda_profile" in result:
                    f.write(f"### Grid {result['grid_size']}x{result['grid_size']}\n\n")
                    f.write("```\n")
                    for item in result["cuda_profile"]["lines"]:
                        f.write(f"{item['field']:20s} {item['value']}\n")
                    f.write("```\n\n")
            
            f.write("\n## Analysis\n\n")
            f.write("### Observations\n")
            f.write("- See detailed results in `results/cuda_profiling/`\n")
            f.write("- Profiling logs: `cuda_profiling_log.txt` in each run directory\n")
            f.write("- Timing data: `csv/timing.csv` in each run directory\n")
        
        print(f"[REPORT] Report saved ✓")
    
    def run_profiling_suite(self):
        """Run complete profiling suite"""
        print("="*60)
        print("ANGIO2D CUDA ADI Profiling Suite")
        print("="*60)
        
        # Check for GPU availability
        try:
            result = subprocess.run(["nvidia-smi", "-L"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=5)
            if result.returncode == 0 and "GPU" in result.stdout:
                print(f"✓ GPU detected: {result.stdout.split(chr(10))[0]}\n")
            else:
                print("⚠️  WARNING: GPU not detected locally")
                print("   This is expected on login nodes.")
                print("   GPU testing requires HPC execution via sbatch.\n")
        except:
            print("⚠️  nvidia-smi not found - GPU may not be available\n")
        
        # Compile
        if not self.compile_cuda():
            print("[ERROR] Failed to compile CUDA")
            return False
        
        if not self.compile_openmp():
            print("[ERROR] Failed to compile OpenMP")
            return False
        
        # Define benchmark configurations (responsibly limited)
        configs = [
            {"size": 64, "steps": 10, "name": "small"},
            {"size": 128, "steps": 10, "name": "medium"},
            {"size": 256, "steps": 5, "name": "large"},
        ]
        
        results = []
        
        # Run CUDA benchmarks
        cuda_binary = self.angio2d_dir / "bin" / "angio2d_cuda"
        for config in configs:
            result = self.run_benchmark(cuda_binary, config, f"cuda_{config['name']}", backend="cuda")
            if result:
                results.append(result)
            time.sleep(2)  # Cooling off period
        
        # Run OpenMP benchmarks for comparison
        openmp_binary = self.angio2d_dir / "bin" / "angio2d_openmp"
        for config in configs:
            result = self.run_benchmark(openmp_binary, config, f"openmp_{config['name']}", backend=None)
            if result:
                results.append(result)
            time.sleep(2)  # Cooling off period
        
        # Generate report
        if results:
            self.generate_report(results)
        
        print("="*60)
        print("Profiling Complete")
        print("="*60)
        
        return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CUDA ADI Profiling for ANGIO2D")
    parser.add_argument("--project-dir", default="/home/c.coppola/projects/angio_2d",
                       help="Project directory")
    
    args = parser.parse_args()
    
    profiler = CUDAProfiler(project_dir=args.project_dir)
    success = profiler.run_profiling_suite()
    
    sys.exit(0 if success else 1)

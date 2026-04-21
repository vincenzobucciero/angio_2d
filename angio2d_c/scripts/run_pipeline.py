#!/usr/bin/env python3
"""
ANGIO2D C Solver - Complete Pipeline Orchestrator

This script automates the entire workflow:
  1. Clean previous build artifacts and outputs
  2. Compile the C solver (ADI-based 2D reaction-diffusion)
  3. Run the solver (generates diagnostics and solution CSVs)
  4. Generate comparison figures vs MATLAB reference
  5. Compute image similarity metrics
  6. Clean up temporary data files

Usage:
    python scripts/run_pipeline.py

Output:
    - Figures: output-c/ and output/ (both contain identical PNGs)
    - Diagnostics: diagnostics_c.csv (time-series of mass/energy)
    - Logs: Console output with detailed progress

Environment:
    - Compiler: cc (Xcode clang on macOS)
    - Python: venv at ../../../.venv (numpy, matplotlib, pillow)
"""

from pathlib import Path
import subprocess
import shutil
import time
import sys

BASE_DIR = Path(__file__).resolve().parents[1]
ROOT_DIR = BASE_DIR.parent
VENV_PY = ROOT_DIR / ".venv" / "bin" / "python"
OUT_DIR = BASE_DIR / "output-c"
SOLUTION_FILES = [
    BASE_DIR / "solution_c_C.csv",
    BASE_DIR / "solution_c_P.csv",
    BASE_DIR / "solution_c_Inh.csv",
    BASE_DIR / "solution_c_F.csv",
]

# ANSI color codes for terminal output
class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


def print_header(text: str):
    """Print a bold section header."""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.CYAN}{text:^70}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.ENDC}\n")


def print_step(step_num: int, total_steps: int, description: str):
    """Print a numbered step."""
    print(f"{Colors.BLUE}[{step_num}/{total_steps}]{Colors.ENDC} {description}")


def print_success(message: str):
    """Print a success message."""
    print(f"{Colors.GREEN}✓{Colors.ENDC} {message}")


def print_error(message: str):
    """Print an error message."""
    print(f"{Colors.RED}✗{Colors.ENDC} {message}")


def print_info(message: str):
    """Print an informational message."""
    print(f"{Colors.YELLOW}→{Colors.ENDC} {message}")


def run(cmd, cwd, description: str = ""):
    """Execute a command with progress reporting."""
    if description:
        print_info(description)
    print(f"  $ {' '.join(cmd)}\n")
    
    start = time.time()
    proc = subprocess.run(cmd, cwd=cwd)
    elapsed = time.time() - start
    
    if proc.returncode != 0:
        print_error(f"Command failed with exit code {proc.returncode}")
        raise SystemExit(proc.returncode)
    
    print(f"  {Colors.GREEN}[OK]{Colors.ENDC} Completed in {elapsed:.2f}s\n")


def clean_output_dir():
    """Clean output directories before pipeline execution."""
    print_info(f"Cleaning {OUT_DIR.name}...")
    OUT_DIR.mkdir(exist_ok=True)
    for item in OUT_DIR.iterdir():
        if item.is_file() or item.is_symlink():
            item.unlink()
        elif item.is_dir():
            shutil.rmtree(item)
    print_success(f"Cleaned {OUT_DIR.name}\n")


def remove_solution_csv():
    """Remove temporary solution CSV files after plotting."""
    print_info("Cleaning temporary solution CSV files...")
    removed_count = 0
    for csv_file in SOLUTION_FILES:
        if csv_file.exists():
            csv_file.unlink()
            removed_count += 1
    print_success(f"Removed {removed_count} temporary files\n")


def main():
    print_header("ANGIO2D C Solver Pipeline")
    print(f"Working directory: {BASE_DIR}\n")
    
    total_steps = 7
    step = 1
    
    # Step 1: Clean
    print_step(step, total_steps, "Preparing environment")
    clean_output_dir()
    step += 1
    
    # Step 2: Clean build
    print_step(step, total_steps, "Cleaning previous build artifacts")
    run(["make", "clean"], BASE_DIR, "Removing build/ directory...")
    step += 1
    
    # Step 3: Compile
    print_step(step, total_steps, "Compiling C solver")
    run(["make"], BASE_DIR, "Compiling from source (src/*.c) with cc...")
    step += 1
    
    # Step 4: Execute solver
    print_step(step, total_steps, "Executing ADI solver")
    run(
        [str(BASE_DIR / "build" / "angio2d")],
        BASE_DIR,
        "Running 2D reaction-diffusion solver (2481 timesteps)...",
    )
    step += 1
    
    # Step 5: Generate figures
    print_step(step, total_steps, "Generating comparison figures")
    run(
        [str(VENV_PY), "scripts/plot_results.py"],
        BASE_DIR,
        "Creating 4 publication-ready figures from solver output...",
    )
    step += 1
    
    # Step 6: Clean temporary files
    print_step(step, total_steps, "Cleaning temporary data")
    remove_solution_csv()
    step += 1
    
    # Step 7: Compare with MATLAB
    print_step(step, total_steps, "Computing image similarity metrics")
    run(
        [str(VENV_PY), "scripts/compare_with_matlab.py"],
        BASE_DIR,
        "Comparing C output against MATLAB reference images...",
    )
    step += 1
    
    # Final summary
    print_header("Pipeline Completed Successfully")
    print(f"{Colors.GREEN}{Colors.BOLD}✓ All steps executed without errors{Colors.ENDC}\n")
    print(f"Output files:")
    print(f"  • {OUT_DIR}/")
    print(f"\nFigures generated:")
    print(f"  1. figure_1_campi_2d_t_f.jpeg (2D concentration/activation heatmaps)")
    print(f"  2. figure_2_diagnostica_temporale.jpeg (temporal dynamics)")
    print(f"  3. figure_3_sezioni_1d.jpeg (1D cross-sections)")
    print(f"  4. figure_4_campo_taf.jpeg (TAF field with streamlines)\n")
    print(f"Next: View results in VS Code or compare metrics with MATLAB reference.\n")
    
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print_error("Pipeline interrupted by user")
        sys.exit(1)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        sys.exit(1)

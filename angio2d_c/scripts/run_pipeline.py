#!/usr/bin/env python3
"""
ANGIO2D C Solver - Complete Pipeline Orchestrator

Automatizza l'intero workflow:
  1. pulizia output e build precedenti
  2. compilazione del solver C
  3. esecuzione del solver
  4. generazione figure
  5. confronto opzionale con riferimento MATLAB
"""

from pathlib import Path      # Gestione percorsi
import importlib.util         # Controllo dipendenze Python
import os                     # Variabili d'ambiente
import subprocess             # Esecuzione comandi esterni
import shutil                 # Rimozione directory/file
import time                   # Timing esecuzione step
import sys                    # Accesso interprete e uscita

BASE_DIR = Path(__file__).resolve().parents[1]   # Root progetto
OUT_DIR = BASE_DIR / "output"                    # Directory output


# Colori ANSI per output leggibile a terminale
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
    """Stampa un'intestazione di sezione."""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.CYAN}{text:^70}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.ENDC}\n")


def print_step(step_num: int, total_steps: int, description: str):
    """Stampa uno step numerato della pipeline."""
    print(f"{Colors.BLUE}[{step_num}/{total_steps}]{Colors.ENDC} {description}")


def print_success(message: str):
    """Stampa un messaggio di successo."""
    print(f"{Colors.GREEN}✓{Colors.ENDC} {message}")


def print_error(message: str):
    """Stampa un messaggio di errore."""
    print(f"{Colors.RED}✗{Colors.ENDC} {message}")


def print_info(message: str):
    """Stampa un messaggio informativo."""
    print(f"{Colors.YELLOW}→{Colors.ENDC} {message}")


def resolve_python() -> str:
    """Seleziona l'interprete Python da usare."""
    env_python = os.environ.get("ANGIO2D_PYTHON")   # Override opzionale via env
    if env_python:
        return env_python
    return sys.executable   # Default: interprete corrente


def ensure_python_dependencies() -> None:
    """Controlla la presenza delle dipendenze Python richieste."""
    missing = []

    module_map = {
        "numpy": "numpy",
        "matplotlib": "matplotlib",
        "PIL": "pillow",
    }

    for module_name, package_name in module_map.items():
        if importlib.util.find_spec(module_name) is None:
            missing.append(package_name)

    if missing:
        joined = ", ".join(missing)
        print_error(f"Missing Python dependencies: {joined}")
        print("Install them with: pip install -r requirements.txt")
        raise SystemExit(1)


def run(cmd, cwd, description: str = ""):
    """Esegue un comando critico e termina in caso di errore."""
    if description:
        print_info(description)

    print(f"  $ {' '.join(cmd)}\n")   # Mostra comando eseguito
    
    start = time.time()
    proc = subprocess.run(cmd, cwd=cwd)   # Esegue comando
    elapsed = time.time() - start
    
    if proc.returncode != 0:
        print_error(f"Command failed with exit code {proc.returncode}")
        raise SystemExit(proc.returncode)
    
    print(f"  {Colors.GREEN}[OK]{Colors.ENDC} Completed in {elapsed:.2f}s\n")


def run_optional(cmd, cwd, description: str = ""):
    """Esegue un comando opzionale senza fermare la pipeline se fallisce."""
    if description:
        print_info(description)

    print(f"  $ {' '.join(cmd)}\n")
    
    start = time.time()
    proc = subprocess.run(cmd, cwd=cwd)
    elapsed = time.time() - start

    if proc.returncode != 0:
        print(f"  {Colors.YELLOW}[SKIP]{Colors.ENDC} Optional step exited with code {proc.returncode} in {elapsed:.2f}s\n")
        return

    print(f"  {Colors.GREEN}[OK]{Colors.ENDC} Completed in {elapsed:.2f}s\n")


def clean_output_dir():
    """Pulisce completamente la directory output."""
    print_info(f"Cleaning {OUT_DIR.name}...")
    OUT_DIR.mkdir(exist_ok=True)

    for item in OUT_DIR.iterdir():
        if item.is_file() or item.is_symlink():
            item.unlink()   # Rimuove file/symlink
        elif item.is_dir():
            shutil.rmtree(item)   # Rimuove directory ricorsivamente

    print_success(f"Cleaned {OUT_DIR.name}\n")


def main():
    python_cmd = resolve_python()   # Determina interprete Python
    ensure_python_dependencies()    # Verifica dipendenze richieste

    print_header("ANGIO2D C Solver Pipeline")
    print(f"Working directory: {BASE_DIR}\n")
    print(f"Python interpreter: {python_cmd}\n")
    
    total_steps = 7
    step = 1
    
    # Step 1: pulizia output
    print_step(step, total_steps, "Preparing environment")
    clean_output_dir()
    step += 1
    
    # Step 2: pulizia build
    print_step(step, total_steps, "Cleaning previous build artifacts")
    run(["make", "clean"], BASE_DIR, "Removing build/ directory...")
    step += 1
    
    # Step 3: compilazione
    print_step(step, total_steps, "Compiling C solver")
    run(["make"], BASE_DIR, "Compiling from source (src/*.c) with cc...")
    step += 1
    
    # Step 4: esecuzione solver
    print_step(step, total_steps, "Executing ADI solver")
    run(
        [str(BASE_DIR / "build" / "angio2d")],
        BASE_DIR,
        "Running 2D reaction-diffusion solver (2481 timesteps)...",
    )
    step += 1
    
    # Step 5: generazione figure
    print_step(step, total_steps, "Generating comparison figures")
    run(
        [python_cmd, "scripts/plot_results.py"],
        BASE_DIR,
        "Creating 4 publication-ready figures from solver output...",
    )
    step += 1
    
    # Step 6: confronto diagnostica con MATLAB
    print_step(step, total_steps, "Comparing diagnostics against MATLAB")
    run_optional(
        [python_cmd, "scripts/compare_diagnostics.py"],
        BASE_DIR,
        "Comparing diagnostics if both C and MATLAB CSV files are available...",
    )
    step += 1

    # Step 7: confronto campi finali e immagini
    print_step(step, total_steps, "Comparing outputs against MATLAB")
    run_optional(
        [python_cmd, "scripts/compare_fields.py"],
        BASE_DIR,
        "Comparing final fields if both C and MATLAB CSV files are available...",
    )
    run_optional(
        [python_cmd, "scripts/compare_with_matlab.py"],
        BASE_DIR,
        "Comparing C figures against MATLAB reference images when available...",
    )
    step += 1
    
    # Riepilogo finale
    print_header("Pipeline Completed Successfully")
    print(f"{Colors.GREEN}{Colors.BOLD}✓ All steps executed without errors{Colors.ENDC}\n")

    print(f"Output files:")
    print(f"  • {OUT_DIR}/")
    print(f"  • {OUT_DIR / 'csv'}/")
    print(f"  • {OUT_DIR / 'figures'}/")
    
    print(f"\nFigures generated:")
    print(f"  1. figure_1_campi_2d_t_f.jpeg (2D concentration/activation heatmaps)")
    print(f"  2. figure_2_diagnostica_temporale.jpeg (temporal dynamics)")
    print(f"  3. figure_3_sezioni_1d.jpeg (1D cross-sections)")
    print(f"  4. figure_4_campo_taf.jpeg (TAF field with streamlines)\n")

    print(f"Next: View results in VS Code or compare metrics with MATLAB reference.\n")
    
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())   # Avvia pipeline
    except KeyboardInterrupt:
        print_error("Pipeline interrupted by user")
        sys.exit(1)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        sys.exit(1)
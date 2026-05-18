include build_config.mk
BUILDDIR = build
PYTHON ?= python3
BINDIR = bin

SRCS = src/params.c src/grid.c src/taf.c src/operators.c src/reaction.c src/adi.c src/diagnostics.c src/output.c src/main.c src/adi_cuda_profiling.c
OBJS = $(SRCS:src/%.c=$(BUILDDIR)/%.o)
CUDA_SRCS = src/adi_cuda.cu
CUDA_OBJS = $(CUDA_SRCS:src/%.cu=$(BUILDDIR)/%.o)
ALL_OBJS = $(OBJS) $(if $(filter 1,$(USE_CUDA)),$(CUDA_OBJS),)

.PHONY: all clean run figures compare check-env check-python serial openmp cuda check-cuda-env

all: $(BUILDDIR)/angio2d

$(BUILDDIR)/angio2d: $(ALL_OBJS)
	@mkdir -p $(BUILDDIR)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

$(BUILDDIR)/%.o: src/%.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(BUILDDIR)/%.o: src/%.cu
	@mkdir -p $(BUILDDIR)
	$(NVCC) $(CUDA_NVCCFLAGS) $(CPPFLAGS) -I include -c $< -o $@

check-env:
	@command -v $(CC) >/dev/null 2>&1 || { echo "ERROR: compiler '$(CC)' not found. Install a C compiler or run 'make CC=<compiler>'."; exit 1; }
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "ERROR: python interpreter '$(PYTHON)' not found. Use 'make PYTHON=<python>' or create a virtual environment."; exit 1; }

check-python: check-env
	@$(PYTHON) -c "import numpy, matplotlib, PIL" >/dev/null 2>&1 || { echo "ERROR: missing Python dependencies for '$(PYTHON)'. Run 'pip install -r requirements.txt' (or 'pip install -r angio2d_c/requirements.txt' from repo root)."; exit 1; }

clean:
	rm -rf $(BUILDDIR) $(BINDIR)

run: check-env $(BUILDDIR)/angio2d
	./$(BUILDDIR)/angio2d

figures: check-python
	$(PYTHON) scripts/plot_results.py

compare: check-python
	$(PYTHON) scripts/compare_diagnostics.py
	$(PYTHON) scripts/compare_fields.py
	$(PYTHON) scripts/compare_with_matlab.py

serial:
	$(MAKE) clean
	@mkdir -p $(BINDIR)
	$(MAKE) USE_OPENMP=0 USE_CUDA=0 all
	cp $(BUILDDIR)/angio2d $(BINDIR)/angio2d_serial

openmp:
	@mkdir -p $(BINDIR)
	$(MAKE) USE_OPENMP=1 USE_CUDA=0 all
	cp $(BUILDDIR)/angio2d $(BINDIR)/angio2d_openmp

check-cuda-env:
	@command -v $(NVCC) >/dev/null 2>&1 || { echo "ERROR: nvcc not found"; exit 1; }

cuda: check-cuda-env
	@mkdir -p $(BINDIR) $(BUILDDIR)
	$(MAKE) USE_OPENMP=1 USE_CUDA=1 $(BUILDDIR)/angio2d CUDA_NVCCFLAGS="$(CUDA_NVCCFLAGS)"
	cp $(BUILDDIR)/angio2d $(BINDIR)/angio2d_cuda

all-variants: clean
	@mkdir -p $(BINDIR)
	@echo "Building serial..."
	$(MAKE) USE_OPENMP=0 USE_CUDA=0 $(BUILDDIR)/angio2d
	cp $(BUILDDIR)/angio2d $(BINDIR)/angio2d_serial
	@echo "Building OpenMP..."
	$(MAKE) USE_OPENMP=1 USE_CUDA=0 $(BUILDDIR)/angio2d
	cp $(BUILDDIR)/angio2d $(BINDIR)/angio2d_openmp
	@echo "Building CUDA..."
	$(MAKE) USE_OPENMP=1 USE_CUDA=1 $(BUILDDIR)/angio2d
	cp $(BUILDDIR)/angio2d $(BINDIR)/angio2d_cuda
	@echo "All variants built successfully!"
	@ls -lh $(BINDIR)/

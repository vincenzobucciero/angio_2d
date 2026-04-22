include build_config.mk
BUILDDIR = build
PYTHON ?= python3

SRCS = src/params.c src/grid.c src/taf.c src/operators.c src/reaction.c src/adi.c src/diagnostics.c src/output.c src/main.c
OBJS = $(SRCS:src/%.c=$(BUILDDIR)/%.o)

.PHONY: all clean run figures compare pipeline check-env check-python

all: $(BUILDDIR)/angio2d

$(BUILDDIR)/angio2d: $(OBJS)
	@mkdir -p $(BUILDDIR)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

$(BUILDDIR)/%.o: src/%.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

check-env:
	@command -v $(CC) >/dev/null 2>&1 || { echo "ERROR: compiler '$(CC)' not found. Install a C compiler or run 'make CC=<compiler>'."; exit 1; }
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "ERROR: python interpreter '$(PYTHON)' not found. Use 'make PYTHON=<python>' or create a virtual environment."; exit 1; }

check-python: check-env
	@$(PYTHON) -c "import numpy, matplotlib, PIL" >/dev/null 2>&1 || { echo "ERROR: missing Python dependencies for '$(PYTHON)'. Run 'pip install -r requirements.txt' (or 'pip install -r angio2d_c/requirements.txt' from repo root)."; exit 1; }

clean:
	rm -rf $(BUILDDIR)

run: check-env $(BUILDDIR)/angio2d
	./$(BUILDDIR)/angio2d

figures: check-python
	$(PYTHON) scripts/plot_results.py

compare: check-python
	$(PYTHON) scripts/compare_diagnostics.py
	$(PYTHON) scripts/compare_fields.py
	$(PYTHON) scripts/compare_with_matlab.py

pipeline: check-python
	$(PYTHON) scripts/run_pipeline.py

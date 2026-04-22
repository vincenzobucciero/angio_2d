include build_config.mk
BUILDDIR = build
PYTHON ?= python3

SRCS = src/params.c src/grid.c src/taf.c src/operators.c src/reaction.c src/adi.c src/diagnostics.c src/output.c src/main.c
OBJS = $(SRCS:src/%.c=$(BUILDDIR)/%.o)

.PHONY: all clean run figures compare pipeline

all: $(BUILDDIR)/angio2d

$(BUILDDIR)/angio2d: $(OBJS)
	@mkdir -p $(BUILDDIR)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

$(BUILDDIR)/%.o: src/%.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILDDIR)

run: $(BUILDDIR)/angio2d
	./$(BUILDDIR)/angio2d

figures:
	$(PYTHON) scripts/plot_results.py

compare:
	$(PYTHON) scripts/compare_diagnostics.py
	$(PYTHON) scripts/compare_fields.py
	$(PYTHON) scripts/compare_with_matlab.py

pipeline:
	$(PYTHON) scripts/run_pipeline.py

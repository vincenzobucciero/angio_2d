include build_config.mk
BUILDDIR = build

SRCS = src/params.c src/grid.c src/taf.c src/operators.c src/reaction.c src/adi.c src/diagnostics.c src/output.c src/main.c
OBJS = $(SRCS:src/%.c=$(BUILDDIR)/%.o)

.PHONY: all clean

all: $(BUILDDIR)/angio2d

$(BUILDDIR)/angio2d: $(OBJS)
	@mkdir -p $(BUILDDIR)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

$(BUILDDIR)/%.o: src/%.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILDDIR)

CC ?= cc
CSTD ?= -std=c99
WARN_FLAGS ?= -Wall -Wextra -Wpedantic
OPT_FLAGS ?= -O2
USE_OPENMP ?= 0
OPENMP_CFLAGS ?= -fopenmp
OPENMP_LDFLAGS ?= -fopenmp
CPPFLAGS += -I include
CFLAGS += $(CSTD) $(WARN_FLAGS) $(OPT_FLAGS)
LDFLAGS ?=
LDLIBS += -lm

ifeq ($(USE_OPENMP),1)
  CFLAGS += $(OPENMP_CFLAGS)
  LDFLAGS += $(OPENMP_LDFLAGS)
endif

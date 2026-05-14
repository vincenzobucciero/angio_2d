CC ?= cc
NVCC ?= nvcc
CSTD ?= -std=c99
WARN_FLAGS ?= -Wall -Wextra -Wpedantic
OPT_FLAGS ?= -O2
USE_OPENMP ?= 0
USE_CUDA ?= 0
OPENMP_CFLAGS ?= -fopenmp
OPENMP_LDFLAGS ?= -fopenmp
CUDA_CFLAGS ?= -DUSE_CUDA
CUDA_NVCCFLAGS ?= -O2
CUDA_INCLUDES ?=
CUDA_LDFLAGS ?= -L/opt/share/libs/nvidia/cuda-12.8.0/lib64
CUDA_LIBS ?= -lcudart -lcusparse
CPPFLAGS += -I include
CFLAGS += $(CSTD) $(WARN_FLAGS) $(OPT_FLAGS)
LDFLAGS ?=
LDLIBS += -lm

ifeq ($(USE_OPENMP),1)
  CFLAGS += $(OPENMP_CFLAGS)
  LDFLAGS += $(OPENMP_LDFLAGS)
endif

ifeq ($(USE_CUDA),1)
  CFLAGS += $(CUDA_CFLAGS)
  CPPFLAGS += $(CUDA_INCLUDES)
  LDFLAGS += $(CUDA_LDFLAGS)
  LDLIBS += $(CUDA_LIBS)
endif

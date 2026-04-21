CC ?= gcc
CSTD ?= -std=c99
WARN_FLAGS ?= -Wall -Wextra -Wpedantic
OPT_FLAGS ?= -O2
CPPFLAGS += -I include
CFLAGS += $(CSTD) $(WARN_FLAGS) $(OPT_FLAGS)
LDFLAGS ?=
LDLIBS += -lm

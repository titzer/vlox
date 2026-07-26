# Vlox: a Lox bytecode VM in Virgil, compiling to WebAssembly.
#
#   make                      build bin/vlox for this host
#   make test                 build, then run every test suite
#   make test SUITE=vlox      run one suite (lox, vlox, bytecode)
#   make TARGET=x86-64-linux  cross-compile to any Virgil target
#   make bench BENCH=<dir>    run the Crafting Interpreters benchmarks
#   make clean                remove build output
#
# VIRGIL_LOC must point at a Virgil checkout; it defaults to ~/virgil.

VIRGIL_LOC ?= $(HOME)/virgil

# Host target, unless the caller overrides TARGET.
UNAME := $(shell uname -sm)
ifeq ($(UNAME),Darwin arm64)
  HOST := x86-64-darwin
else ifeq ($(UNAME),Darwin x86_64)
  HOST := x86-64-darwin
else ifeq ($(UNAME),Linux x86_64)
  HOST := x86-64-linux
else ifeq ($(UNAME),Linux aarch64)
  HOST := arm64-linux
endif
TARGET ?= $(HOST)

V3C   := $(VIRGIL_LOC)/bin/v3c-$(TARGET)
SRC   := $(wildcard src/*.v3)
LIBS   = $(shell sed 's|^|$(VIRGIL_LOC)/|' DEPS)   # the lib/util files listed in DEPS
BIN   := bin/vlox
SUITE ?=

.PHONY: all test bench clean check-virgil

all: $(BIN)

$(BIN): $(SRC) DEPS | check-virgil
	@mkdir -p bin
	@echo "building $(BIN) for $(TARGET)"
	@$(V3C) -output=bin -program-name=vlox $(LIBS) $(SRC)

check-virgil:
	@test -n "$(TARGET)" || { \
	  echo "make: unknown host '$(UNAME)'; pass TARGET=<virgil target>"; exit 1; }
	@test -x "$(V3C)" || { \
	  echo "make: no Virgil compiler at $(V3C)"; \
	  echo "      set VIRGIL_LOC to your Virgil checkout, or TARGET to a supported target"; \
	  exit 1; }

test: $(BIN)
	@./test/all.bash $(SUITE)

# The Crafting Interpreters benchmarks are not part of this repo; point BENCH at a
# checkout of it to run them.
BENCH ?= $(HOME)/craftinginterpreters/test/benchmark
bench: $(BIN)
	@test -d "$(BENCH)" || { echo "make: no benchmarks at $(BENCH); set BENCH=<dir>"; exit 1; }
	@for b in $(BENCH)/*.lox; do \
	  printf '%-20s ' "$$(basename $$b .lox)"; \
	  ./$(BIN) $$b | tail -1; \
	done

clean:
	@rm -rf bin

#!/usr/bin/env bash
# Run every Vlox test suite.
#
#   ./test/all.bash                 run everything
#   ./test/all.bash lox vlox        run only the named suites
#   ./test/all.bash -v              verbose (list every test)
#
# Suites:
#   lox       the Crafting Interpreters reference suite, imported verbatim
#   vlox      tests written for Vlox, covering its own design decisions
#   bytecode  golden-file tests over the disassembled Wasm bytecode
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
VLOX=${VLOX:-$ROOT/bin/vlox}

if [ ! -x "$VLOX" ]; then
	echo "test: no interpreter at $VLOX; run ./build.sh first" >&2
	exit 1
fi

VERBOSE=()
SUITES=()
for arg in "$@"; do
	case "$arg" in
		-v|--verbose) VERBOSE+=("-v");;
		*) SUITES+=("$arg");;
	esac
done
[ ${#SUITES[@]} -eq 0 ] && SUITES=(lox vlox bytecode)

status=0
for suite in "${SUITES[@]}"; do
	echo "=== $suite ==="
	case "$suite" in
		bytecode)
			VLOX="$VLOX" "$HERE/bytecode/run.bash" || status=1
			;;
		*)
			if [ ! -d "$HERE/$suite" ]; then
				echo "test: no such suite '$suite'" >&2
				status=1
				continue
			fi
			python3 "$HERE/runner.py" -i "$VLOX" ${VERBOSE+"${VERBOSE[@]}"} "$HERE/$suite" || status=1
			;;
	esac
done
exit $status

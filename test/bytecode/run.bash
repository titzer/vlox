#!/usr/bin/env bash
# Golden-file tests for the emitted bytecode. Each cases/<name>.lox is disassembled
# and compared against expected/<name>.wat. Run with -u to update the goldens after
# an intentional codegen change.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VLOX=${VLOX:-$HERE/../../bin/vlox}
UPDATE=0
[ "${1:-}" = "-u" ] && UPDATE=1

if [ ! -x "$VLOX" ]; then
	echo "bytecode: no interpreter at $VLOX; run ./build.sh first" >&2
	exit 1
fi

mkdir -p "$HERE/expected"
pass=0; fail=0
for case in "$HERE"/cases/*.lox; do
	name=$(basename "$case" .lox)
	golden="$HERE/expected/$name.wat"
	actual=$("$VLOX" --disassemble "$case" 2>&1)
	if [ $UPDATE = 1 ]; then
		printf '%s\n' "$actual" > "$golden"
		echo "updated $name.wat"
		continue
	fi
	if [ ! -f "$golden" ]; then
		echo "FAIL $name (no golden file; run ./run.bash -u)"
		fail=$((fail + 1))
	elif printf '%s\n' "$actual" | diff -u "$golden" - > "/tmp/vlox-bc-diff.$$"; then
		pass=$((pass + 1))
	else
		echo "FAIL $name"
		sed 's/^/     /' "/tmp/vlox-bc-diff.$$"
		fail=$((fail + 1))
	fi
	rm -f "/tmp/vlox-bc-diff.$$"
done
if [ $UPDATE = 1 ]; then exit 0; fi
echo "$pass/$((pass + fail)) bytecode goldens matched"
[ $fail = 0 ]

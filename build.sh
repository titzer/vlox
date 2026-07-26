#!/usr/bin/env bash
# Build vlox. With no arguments, builds a native binary for the host platform.
#   ./build.sh            native binary  -> bin/vlox
#   ./build.sh <target>   e.g. x86-64-linux, jar, wasm-wasi1
set -e
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VIRGIL_LOC=${VIRGIL_LOC:-$HOME/virgil}
[ -d "$VIRGIL_LOC" ] || { echo "build.sh: set VIRGIL_LOC to your Virgil checkout" >&2; exit 1; }

detect_host() {
	case "$(uname -sm)" in
		"Darwin arm64"|"Darwin x86_64") echo x86-64-darwin;;
		"Linux x86_64") echo x86-64-linux;;
		"Linux aarch64") echo arm64-linux;;
		*) echo "build.sh: unknown host $(uname -sm)" >&2; exit 1;;
	esac
}
TARGET=${1:-$(detect_host)}
DEPS=$(sed "s|^|$VIRGIL_LOC/|" "$HERE/DEPS" | tr '\n' ' ')
SRC="$HERE/src/*.v3"

mkdir -p "$HERE/bin"
echo "building bin/vlox for $TARGET"
"$VIRGIL_LOC/bin/v3c-$TARGET" -output="$HERE/bin" -program-name=vlox $DEPS $SRC

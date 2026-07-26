#!/usr/bin/env python3
"""Vlox test runner.

Reads expectations out of the .lox source itself, in the format the Crafting
Interpreters suite uses, so that the imported reference tests and the Vlox-specific
tests run through exactly the same harness:

    // expect: <line of stdout>
    // expect runtime error: <message>        -> exit 70, message on stderr,
                                                 plus a stack trace naming this line
    // Error at 'tok': <message>              -> exit 65, compile error on this line
    // [line N] Error: <message>              -> exit 65, compile error on line N
    // nontest                                -> not a test, skip the file

A `SKIP` file in a directory lists (one per line, `#` for comments) test files under
that directory that do not apply to Vlox, with the reason.
"""

import os
import re
import subprocess
import sys

EXPECT_OUTPUT = re.compile(r"// expect: ?(.*)")
EXPECT_ERROR = re.compile(r"// (Error.*)")
EXPECT_ERROR_LINE = re.compile(r"// \[((java|c) )?line (\d+)\] (Error.*)")
EXPECT_RUNTIME_ERROR = re.compile(r"// expect runtime error: (.+)")
SYNTAX_ERROR = re.compile(r"\[.*line (\d+)\] (Error.+)")
STACK_TRACE = re.compile(r"\[line (\d+)\]")
NONTEST = re.compile(r"// nontest")

GREEN, RED, YELLOW, GRAY, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[90m", "\033[0m"


def color(s, c):
    return f"{c}{s}{RESET}" if sys.stdout.isatty() else str(s)


class Test:
    def __init__(self, path):
        self.path = path
        self.output = []           # (line_number, expected_text)
        self.compile_errors = set()
        self.runtime_error = None
        self.runtime_error_line = 0
        self.exit_code = 0
        self.failures = []

    def parse(self):
        """Return False if the file is not a test."""
        with open(self.path) as f:
            lines = f.read().split("\n")
        for n, line in enumerate(lines, start=1):
            if NONTEST.search(line):
                return False
            m = EXPECT_OUTPUT.search(line)
            if m:
                self.output.append((n, m.group(1)))
                continue
            m = EXPECT_ERROR.search(line)
            if m:
                self.compile_errors.add(f"[{n}] {m.group(1)}")
                self.exit_code = 65
                continue
            m = EXPECT_ERROR_LINE.search(line)
            if m:
                # The reference suite tags a few errors as jlox- or clox-specific.
                # Vlox is a bytecode VM, so it follows the "c" expectations.
                if m.group(2) in (None, "c"):
                    self.compile_errors.add(f"[{m.group(3)}] {m.group(4)}")
                    self.exit_code = 65
                continue
            m = EXPECT_RUNTIME_ERROR.search(line)
            if m:
                self.runtime_error = m.group(1)
                self.runtime_error_line = n
                self.exit_code = 70
        if self.compile_errors and self.runtime_error:
            self.fail("test declares both a compile error and a runtime error")
        return True

    def run(self, interpreter, extra_args):
        proc = subprocess.run([interpreter] + extra_args + [self.path],
                              capture_output=True, text=True)
        out = proc.stdout.split("\n")
        err = proc.stderr.split("\n")
        if out and out[-1] == "":
            out.pop()
        if err and err[-1] == "":
            err.pop()

        if self.runtime_error:
            self.check_runtime_error(err)
        else:
            self.check_compile_errors(err)
        if proc.returncode != self.exit_code:
            self.fail(f"expected exit code {self.exit_code}, got {proc.returncode}")
            for line in err[:10]:
                self.fail(f"  stderr: {line}")
        self.check_output(out)
        return self.failures

    def check_runtime_error(self, err):
        if len(err) < 2:
            self.fail(f"expected runtime error '{self.runtime_error}' and got none")
            return
        if err[0] != self.runtime_error:
            self.fail(f"expected runtime error '{self.runtime_error}'")
            self.fail(f"                   got '{err[0]}'")
        for line in err[1:]:
            m = STACK_TRACE.search(line)
            if m:
                if int(m.group(1)) != self.runtime_error_line:
                    self.fail(f"expected runtime error on line "
                              f"{self.runtime_error_line}, was on line {m.group(1)}")
                return
        self.fail("expected a stack trace, got: " + " / ".join(err[1:]))

    def check_compile_errors(self, err):
        found = set()
        for line in err:
            m = SYNTAX_ERROR.search(line)
            if m:
                e = f"[{m.group(1)}] {m.group(2)}"
                if e in self.compile_errors:
                    found.add(e)
                else:
                    self.fail(f"unexpected error: {line}")
            elif line != "":
                self.fail(f"unexpected output on stderr: {line}")
        for e in sorted(self.compile_errors - found):
            self.fail(f"missing expected error: {e}")

    def check_output(self, out):
        for i, line in enumerate(out):
            if i >= len(self.output):
                self.fail(f"got output '{line}' when none was expected")
                continue
            n, expected = self.output[i]
            if expected != line:
                self.fail(f"expected output '{expected}' on line {n}, got '{line}'")
        for n, expected in self.output[len(out):]:
            self.fail(f"missing expected output '{expected}' on line {n}")

    def fail(self, message):
        self.failures.append(message)


def load_skips(root):
    """Map of relative-path -> reason, from SKIP files anywhere under {root}."""
    skips = {}
    for dirpath, _, filenames in os.walk(root):
        if "SKIP" not in filenames:
            continue
        with open(os.path.join(dirpath, "SKIP")) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                name, _, reason = line.partition(":")
                skips[os.path.normpath(os.path.join(dirpath, name.strip()))] = reason.strip()
    return skips


def main(argv):
    interpreter = None
    extra_args = []
    roots = []
    verbose = False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("-i", "--interpreter"):
            i += 1
            interpreter = argv[i]
        elif a in ("-a", "--arg"):
            i += 1
            extra_args.append(argv[i])
        elif a in ("-v", "--verbose"):
            verbose = True
        else:
            roots.append(a)
        i += 1

    here = os.path.dirname(os.path.abspath(__file__))
    if interpreter is None:
        interpreter = os.path.join(os.path.dirname(here), "bin", "vlox")
    if not os.path.isfile(interpreter):
        print(f"runner: no interpreter at {interpreter}; run ./build.sh first")
        return 1
    if not roots:
        roots = [here]

    skips = load_skips(here)
    paths = []
    for root in roots:
        if os.path.isfile(root):
            paths.append(os.path.abspath(root))
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames.sort()
            for name in sorted(filenames):
                if name.endswith(".lox"):
                    paths.append(os.path.abspath(os.path.join(dirpath, name)))

    passed = failed = skipped = 0
    for path in paths:
        rel = os.path.relpath(path, here)
        norm = os.path.normpath(path)
        skip_reason = None
        for prefix, reason in skips.items():
            if norm == prefix or norm.startswith(prefix + os.sep):
                skip_reason = reason
                break
        if skip_reason is not None:
            skipped += 1
            if verbose:
                print(f"{color('SKIP', YELLOW)} {rel} {color('(' + skip_reason + ')', GRAY)}")
            continue
        test = Test(path)
        if not test.parse():
            skipped += 1
            continue
        failures = test.run(interpreter, extra_args)
        if failures:
            failed += 1
            print(f"{color('FAIL', RED)} {rel}")
            for f in failures:
                print(f"     {f}")
        else:
            passed += 1
            if verbose:
                print(f"{color('PASS', GREEN)} {rel}")

    total = passed + failed
    print(f"{color(passed, GREEN)}/{total} passed, "
          f"{color(failed, RED)} failed, {color(skipped, YELLOW)} skipped")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

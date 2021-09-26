#!/bin/bash

swift test --enable-code-coverage
echo ""

BIN="$(swift build --show-bin-path)"
FILE="$(find ${BIN} -name '*.xctest')"
COV="$(dirname "$(realpath "$(which swift)")")/llvm-cov"

if [[ "$OSTYPE" == "darwin"* ]]; then
    FILE="${FILE}/Contents/MacOS/$(basename $FILE .xctest)"
    COV="$(xcrun -f llvm-cov)"
fi

$COV show "${FILE}" -instr-profile="${BIN}/codecov/default.profdata" -ignore-filename-regex=".build|Tests" -show-branch-summary=0 -show-instantiations=0 -line-coverage-lt=100

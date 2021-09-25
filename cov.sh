#!/bin/bash

swift test --enable-code-coverage
echo ""

BIN="$(swift build --show-bin-path)"
FILE="$(find ${BIN} -name '*.xctest')"

if [[ "$OSTYPE" == "darwin"* ]]; then
    FILE="${FILE}/Contents/MacOS/$(basename $FILE .xctest)"
fi

$(xcrun -f llvm-cov) show "${FILE}" -instr-profile="${BIN}/codecov/default.profdata" -ignore-filename-regex=".build|Tests" -show-branch-summary=0 -show-instantiations=0 -line-coverage-lt=100

#!/bin/bash

# Detect architecture
ARCH=$(uname -m)
OS_ARCH="${ARCH}-apple-macosx"

# Find the test binary
BINARY_PATH=$(ls .build/${OS_ARCH}/debug/SwiftGeneticsPackageTests.xctest/Contents/MacOS/SwiftGeneticsPackageTests 2>/dev/null)

if [ -z "$BINARY_PATH" ]; then
    echo "Error: Could not find test binary at .build/${OS_ARCH}/debug/SwiftGeneticsPackageTests.xctest/Contents/MacOS/SwiftGeneticsPackageTests"
    echo "Ensure you have run 'swift test --enable-code-coverage' first."
    exit 1
fi

PROFDATA_PATH=".build/${OS_ARCH}/debug/codecov/default.profdata"

if [ ! -f "$PROFDATA_PATH" ]; then
    echo "Error: Could not find profile data at $PROFDATA_PATH"
    exit 1
fi

# Create output directory
mkdir -p coverage_report

# Generate HTML report
echo "Generating HTML coverage report..."
xcrun llvm-cov show \
    "$BINARY_PATH" \
    -instr-profile="$PROFDATA_PATH" \
    -format=html \
    -output-dir=coverage_report \
    -ignore-filename-regex=".build/|Tests/"

echo "Report generated at coverage_report/index.html"

# Generate terminal summary
echo ""
echo "Coverage Summary:"
xcrun llvm-cov report \
    "$BINARY_PATH" \
    -instr-profile="$PROFDATA_PATH" \
    -ignore-filename-regex=".build/|Tests/"

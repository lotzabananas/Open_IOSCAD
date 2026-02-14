#!/bin/bash
# Build OpeniOSCAD and run Maestro E2E tests.
# Requires: Maestro CLI installed (brew install maestro)
# Usage: ./MaestroTests/scripts/build_and_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLOWS_DIR="$PROJECT_DIR/MaestroTests/flows"

echo "=== OpeniOSCAD E2E Tests ==="
echo "Project: $PROJECT_DIR"
echo ""

# Step 1: Build for simulator
echo ">>> Building app for simulator..."
xcodebuild \
    -project "$PROJECT_DIR/OpeniOSCAD.xcodeproj" \
    -scheme OpeniOSCAD \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -quiet \
    build

echo ">>> Build succeeded"
echo ""

# Step 2: Boot simulator
SIMULATOR_NAME="iPhone 16"
echo ">>> Booting simulator: $SIMULATOR_NAME"
xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
sleep 2

# Step 3: Install the app
echo ">>> Installing app..."
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "OpeniOSCAD.app" -path "*/Build/Products/Debug-iphonesimulator/*" | head -1)
if [ -z "$BUILT_APP" ]; then
    echo "ERROR: Could not find built app. Build may have failed."
    exit 1
fi
xcrun simctl install booted "$BUILT_APP"

# Step 4: Run Maestro flows
echo ""
echo ">>> Running Maestro E2E tests..."
PASS=0
FAIL=0
TOTAL=0

for flow in "$FLOWS_DIR"/*.yaml; do
    TOTAL=$((TOTAL + 1))
    FLOW_NAME=$(basename "$flow" .yaml)
    echo -n "  [$TOTAL] $FLOW_NAME... "

    if maestro test "$flow" --no-ansi 2>/dev/null; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "=== Results ==="
echo "Total: $TOTAL  Pass: $PASS  Fail: $FAIL"

if [ $FAIL -gt 0 ]; then
    echo ">>> SOME TESTS FAILED"
    exit 1
else
    echo ">>> ALL TESTS PASSED"
fi

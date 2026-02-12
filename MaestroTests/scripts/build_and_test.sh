#!/bin/bash
set -e

xcodebuild \
  -scheme 'OpeniOSCAD' \
  -project 'OpeniOSCAD.xcodeproj' \
  -configuration Debug \
  -sdk 'iphonesimulator' \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  -quiet

xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/OpeniOSCAD.app

maestro test MaestroTests/flows/
maestro test MaestroTests/flows/regression/

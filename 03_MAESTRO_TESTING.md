# OpeniOSCAD — Maestro E2E Testing Spec

## Setup

Maestro tests run against iOS Simulator builds (.app). Real device testing is not supported by Maestro on iOS — simulator only.

### Prerequisites
- Xcode with iOS Simulator runtimes
- Maestro CLI: `curl -Ls "https://get.maestro.mobile.dev" | bash`
- Facebook IDB: `brew tap facebook/fb && brew install facebook/fb/idb-companion`

### Build & Run Script

```bash
#!/bin/bash
# MaestroTests/scripts/build_and_test.sh
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
```

### GitHub Actions CI

```yaml
# .github/workflows/maestro.yml
name: Maestro E2E Tests
on: [pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Install Maestro
        run: curl -Ls "https://get.maestro.mobile.dev" | bash
      - name: Install IDB
        run: brew tap facebook/fb && brew install facebook/fb/idb-companion
      - name: Build and Test
        run: ./MaestroTests/scripts/build_and_test.sh
      - name: Upload results on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: maestro-results
          path: ~/.maestro/tests/
```

## Accessibility ID Convention

Every interactive UI element MUST have an accessibility identifier for Maestro to find it. Convention:

```
toolbar_add_button
toolbar_edit_button
toolbar_script_button
toolbar_customizer_button
menu_export
menu_export_stl
menu_export_3mf
feature_tree_item_{index}
feature_tree_item_{index}_eye
param_slider_{param_name}
param_picker_{param_name}
param_field_{param_name}
viewport_view
script_editor_view
undo_button
redo_button
```

Set these in SwiftUI with `.accessibilityIdentifier("toolbar_add_button")`.

## Test Flows

### 01_app_launch.yaml
Verify app opens to a clean state with viewport and toolbar visible.
```yaml
appId: com.openioscad.app
---
- launchApp
- assertVisible:
    id: "viewport_view"
- assertVisible:
    id: "toolbar_add_button"
- assertVisible:
    id: "toolbar_edit_button"
- assertVisible:
    id: "toolbar_script_button"
```

### 02_add_cube.yaml
Add a cube via GUI, verify it appears in viewport and feature tree, verify script is written.
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_add_button"
- assertVisible: "Cube"
- assertVisible: "Cylinder"
- assertVisible: "Sphere"
- tapOn: "Cube"
- assertVisible:
    id: "feature_tree_item_0"
# Verify script was written
- tapOn:
    id: "toolbar_script_button"
- assertVisible: "cube("
```

### 03_add_cylinder.yaml
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_add_button"
- tapOn: "Cylinder"
- assertVisible:
    id: "feature_tree_item_0"
- tapOn:
    id: "toolbar_script_button"
- assertVisible: "cylinder("
```

### 04_script_editor_toggle.yaml
Toggle script editor on and off.
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_script_button"
- assertVisible:
    id: "script_editor_view"
- tapOn:
    id: "toolbar_script_button"
- assertNotVisible:
    id: "script_editor_view"
```

### 05_customizer_sliders.yaml
Open a file with customizer variables, verify sliders appear.
```yaml
appId: com.openioscad.app
---
- launchApp
# Write a script with customizer variables
- tapOn:
    id: "toolbar_script_button"
- clearText
- inputText: |
    width = 40; // [10:100]
    cube([width, 20, 10]);
- tapOn:
    id: "toolbar_customizer_button"
- assertVisible: "width"
- assertVisible:
    id: "param_slider_width"
```

### 06_modify_parameter.yaml
Change a customizer parameter, verify model updates.
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_script_button"
- clearText
- inputText: |
    size = 20; // [5:50]
    cube(size);
- tapOn:
    id: "toolbar_customizer_button"
- assertVisible:
    id: "param_slider_size"
# Interact with slider (swipe right to increase)
- swipe:
    id: "param_slider_size"
    direction: "RIGHT"
    duration: 500
# Model should still be rendered (no crash)
- assertVisible:
    id: "viewport_view"
```

### 07_export_stl.yaml
Create geometry and export to STL.
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_add_button"
- tapOn: "Cube"
- tapOn:
    id: "menu_export"
- tapOn: "STL"
- assertVisible: "Export Complete"
```

### 08_feature_tree_select.yaml
Tap a feature tree item, verify selection highlight.
```yaml
appId: com.openioscad.app
---
- launchApp
# Add two primitives
- tapOn:
    id: "toolbar_add_button"
- tapOn: "Cube"
- tapOn:
    id: "toolbar_add_button"
- tapOn: "Cylinder"
# Verify both in tree
- assertVisible:
    id: "feature_tree_item_0"
- assertVisible:
    id: "feature_tree_item_1"
# Select the first one
- tapOn:
    id: "feature_tree_item_0"
```

### 09_undo_redo.yaml
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_add_button"
- tapOn: "Cube"
- assertVisible:
    id: "feature_tree_item_0"
# Undo
- tapOn:
    id: "undo_button"
- assertNotVisible:
    id: "feature_tree_item_0"
# Redo
- tapOn:
    id: "redo_button"
- assertVisible:
    id: "feature_tree_item_0"
```

### 10_open_scad_file.yaml
Open a .scad file and verify it renders.
```yaml
appId: com.openioscad.app
---
- launchApp
# This test assumes a .scad file is pre-loaded in the app's documents
# via test setup or by typing script directly
- tapOn:
    id: "toolbar_script_button"
- clearText
- inputText: |
    difference() {
        cube([30, 30, 10], center=true);
        cylinder(h=12, r=8, center=true, $fn=32);
    }
- tapOn:
    id: "toolbar_script_button"
# Should render without crash
- assertVisible:
    id: "viewport_view"
```

### regression/boolean_edge_cases.yaml
Test that complex boolean operations don't crash.
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_script_button"
- clearText
- inputText: |
    // Nested booleans
    difference() {
        union() {
            cube([20, 20, 20], center=true);
            sphere(r=12, $fn=24);
        }
        for (i = [0:2]) {
            rotate([0, 0, i * 120])
                translate([8, 0, 0])
                    cylinder(h=30, r=3, center=true, $fn=16);
        }
    }
- tapOn:
    id: "toolbar_script_button"
# Should render without crash (wait for complex evaluation)
- extendedWaitUntil:
    visible:
      id: "viewport_view"
    timeout: 10000
```

### regression/large_model_performance.yaml
Test that a model with many features doesn't hang the UI.
```yaml
appId: com.openioscad.app
---
- launchApp
- tapOn:
    id: "toolbar_script_button"
- clearText
- inputText: |
    // Grid of cylinders
    for (x = [0:5:50]) {
        for (y = [0:5:50]) {
            translate([x, y, 0])
                cylinder(h=10, r=2, $fn=16);
        }
    }
- tapOn:
    id: "toolbar_script_button"
# UI should remain responsive
- extendedWaitUntil:
    visible:
      id: "viewport_view"
    timeout: 15000
- tapOn:
    id: "toolbar_add_button"
# If we can still tap buttons, the UI didn't freeze
- assertVisible: "Cube"
```

## Test Fixture Files

Store real `.scad` files from Thingiverse/Printables in `TestFixtures/thingiverse_samples/` for both unit tests and Maestro tests. Good candidates:

1. A simple parametric box with lid (customizer variables)
2. A parametric phone stand
3. A gridfinity base (complex for loops)
4. A gear generator (heavy math, modules)
5. A simple vase (rotate_extrude)
6. A name tag with text() (will fail gracefully until v2.0)
7. A threaded bolt (complex geometry)
8. A hinge (assembly-like, multiple parts)
9. A cable clip (real-world simple utility)
10. A parametric enclosure (difference, lots of customizer vars)

These serve double duty: unit tests verify parse/eval correctness, and Maestro tests verify the app doesn't crash when opening them.

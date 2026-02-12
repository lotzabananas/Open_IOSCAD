# OpeniOSCAD — Vision & Architecture

## What This Is

OpeniOSCAD is a free, open-source (MIT), native iOS parametric CAD app. Every model is backed by an OpenSCAD-compatible script. GUI tools write script; the engine rebuilds geometry from script; the feature tree, 3D viewport, and script editor are three synchronized views of the same `.scad` text file.

## Decided — Do Not Revisit

- **Name:** OpeniOSCAD
- **License:** MIT, public GitHub repo
- **Price:** Free. No IAP, no subscription, no paid tiers.
- **Platform:** iPhone primary. iPad fast-follow (same codebase, adaptive layout).
- **Language:** 100% Swift + Metal. No C++ dependencies in v1. No Python. No WASM.
- **File format:** `.scad` (OpenSCAD-compatible). Extensions via structured comments.
- **Script is authoritative:** GUI writes script. Engine reads script. Never the reverse.
- **OpenSCAD compatibility:** Superset. Standard `.scad` files must open. Exports must work in desktop OpenSCAD.
- **Design philosophy:** Accessible AND serious. Progressive disclosure. Respect user intelligence.

## Core Architecture Principle

The script is the single source of truth. Always.

```
User taps "Add Cube" in GUI
        |
        v
App writes `cube([10,10,10]);` into the script text
        |
        v
Script engine re-parses and re-evaluates
        |
        v
Geometry kernel produces triangle mesh
        |
        v
Metal renderer displays updated model + Feature tree updates
```

The model is NEVER stored independently of the script. Undo = revert script text. Save = save the `.scad` file. Share = send the `.scad` file. Feature reorder = move a script block. Suppress = comment out a script block.

## System Architecture

Three Swift packages + one app target. Packages have zero UIKit/SwiftUI dependencies.

```
iOS App (SwiftUI)
  |-- Views: Viewport, FeatureTree, ScriptEditor, ParameterPanel, Toolbar
  |-- ViewModels: ModelViewModel, SketchViewModel
  |
SCADEngine (Swift Package) -- OpenSCAD interpreter
  |-- Lexer -> Parser -> AST -> Evaluator
  |-- CustomizerExtractor (generates param UI from // [min:max] annotations)
  |-- FeatureAnnotationParser (parses // @feature comments)
  |
GeometryKernel (Swift Package) -- geometry engine
  |-- Primitives (cube, cylinder, sphere, cone, polyhedron)
  |-- CSG (union, difference, intersection)
  |-- Transforms (translate, rotate, scale, mirror)
  |-- Extrude (linear_extrude, rotate_extrude)
  |-- Mesh (TriangleMesh data structure, tessellation, optimization)
  |-- Export (STL, 3MF, OBJ)
  |
Renderer (Swift Package + Metal)
  |-- Metal shaders, render pipeline, camera, selection highlighting
```

## OpenSCAD Compatibility: Superset Strategy

Any `.scad` file from Thingiverse/Printables should parse and render. Files created in OpeniOSCAD export to valid `.scad` that desktop OpenSCAD can open.

OpeniOSCAD adds features via structured comments that desktop OpenSCAD ignores:

```scad
width = 40;  // [10:100] Bracket width
height = 25; // [10:50] Bracket height

// @feature "Base Plate"
difference() {
    cube([width, height, 3]);
    // @feature "Mounting Hole"
    translate([width/2, height/2, -1])
        cylinder(h=5, d=5);
}
```

Desktop OpenSCAD sees `// @feature` as a plain comment. OpeniOSCAD parses it for the feature tree. 100% cross-compatible.

For sketch operations (v1.5+, no OpenSCAD equivalent), emit CSG fallback with sketch in comment:
```scad
// @sketch XY { rect(center=[0,0], w=40, h=25); }
// @extrude 3
cube([40, 25, 3], center=true);  // OpenSCAD sees this
```

### Compatibility Matrix

v1.0: cube, cylinder, sphere, polyhedron, union, difference, intersection, translate, rotate, scale, mirror, linear_extrude (twist/scale/slices), rotate_extrude, module/function, for/if/let/each, customizer variables, import STL/3MF, color, children()/$children, $fn/$fa/$fs, echo/assert

v1.5: projection
v2.0: text(), minkowski, hull
v2.5: surface()

## UI/UX Design

### iPhone Layout
```
+---------------------------+
|  +---------------------+  |
|  |   3D Viewport       |  |  <- Primary, always visible
|  |   (Metal render)    |  |     Pinch/pan/orbit
|  +---------------------+  |
|  +---------------------+  |
|  |  Feature Tree       |  |  <- Collapsible bottom panel
|  +---------------------+  |
|  | [+]    [pen]  [<>]  |  |  <- 3 primary actions
|  +---------------------+  |
+---------------------------+
```

### Modal States
1. Model Mode — 3D viewport + feature tree + toolbar
2. Sketch Mode (v1.5) — 2D orthographic canvas + sketch tools + constraints
3. Script Mode — Full-screen code editor
4. Parameter Mode — Auto-generated customizer sliders from annotated vars

### Progressive Disclosure
Level 1 (immediate): [+] Add (Cube/Cylinder/Sphere/Sketch), Edit (context-sensitive), Script toggle
Level 2 (explore): Long-press for full library, face/edge selection shows relevant ops, tree swipe actions
Level 3 (power): Patterns, assemblies, export settings, custom modules

### Gestures
1-finger drag: Orbit (model) / Pan (sketch)
2-finger pinch: Zoom
2-finger drag: Pan
Tap: Select
Double-tap: Edit feature/dimension
Long-press: Context menu
3-finger swipe up: Toggle script editor

### Constraint Visualization (v1.5 — "make it feel like a game")
Under-constrained: Pulsing colored arrows show free DOFs, draggable
Fully constrained: Green outline, subtle celebration animation
Over-constrained: Red highlights, tap to see conflicts and remove

### Script Editor
Syntax highlighting, autocomplete, inline errors with line numbers, code folding, jump-to-feature, jump-to-3D, unified undo/redo

### Feature Tree
Tap: select + highlight + jump to script. Long-press drag: reorder. Swipe left: suppress/delete. Eye icon: comment/uncomment. Tap value: inline edit. Tap name: rename.

## Export Formats

v1.0: .scad (native), STL, 3MF, OBJ
v1.5: SVG
v2.0: STEP AP214
v2.5: DXF
v3.0: PDF engineering drawings

## Performance Targets

Simple extrude: <5ms (iPhone 15), <15ms (iPhone 12)
Complex boolean (<10K faces): <50ms / <150ms
Full rebuild (<50 features): <500ms / <1.5s
Display tessellation: <16ms (60fps) / <33ms (30fps)
Script parse+eval: <100ms / <300ms
STL export (100K tris): <1s / <3s

## Design Philosophy

Most CAD apps are unapproachable not because engineering is hard but because the UI is bad. Decades of dogma: 200-icon toolbars, 6-deep modal dialogs, right-click menus that change with invisible state.

Every UI decision asks: "Is this complexity necessary, or is it dogma?"

- Progressive disclosure over feature dumps. Show 3 tools, let users discover 30.
- The model teaches the language. Every GUI action writes readable script.
- Constraints are visible, not hidden. Show DOFs as draggable handles.
- Undo is fearless. The script IS the undo history.
- Respect the user's intelligence. Don't hide the script. Give real tools, make them learnable.
- We underestimate people. A hobbyist and an engineer need the same tool. The difference is disclosure, not capability.

## Development Phases

Phase 1 (Foundation): Parse .scad -> evaluate -> render 3D -> export STL. Customizer panel.
Phase 2 (GUI Bridge): GUI writes script. Bidirectional feature tree. Undo/redo. Incremental eval.
Phase 3 (Sketch): 2D constraint solver. Sketch -> extrude/cut/revolve.
Phase 4 (BREP): Fillet, chamfer, shell, draft. STEP export.
Phase 5 (Polish): Patterns, assemblies, 2D drawings. App Store launch.

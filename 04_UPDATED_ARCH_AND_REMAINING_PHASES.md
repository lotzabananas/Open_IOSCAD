# OpeniOSCAD — Architecture Update + Phases 2-5 + Claude Code Rules

This document supersedes geometry kernel decisions in 01_VISION_AND_ARCHITECTURE.md. Everything else in that doc remains valid. Read this AFTER the original three docs.

---

## Architecture Update: C++ Geometry Kernel via Manifold

### What Changed

The original vision said "100% Swift, no C++." That was wrong for the geometry kernel. CSG boolean operations on triangle meshes are one of the hardest problems in computational geometry. Floating-point precision, degenerate triangles, coincident faces, T-junctions — writing a robust implementation from scratch takes months and produces years of edge-case bugs.

### The Fix: Manifold

**Manifold** (https://github.com/ennomane/manifold) is an MIT-licensed C++ library for robust mesh boolean operations. It is what OpenSCAD itself is migrating to as its next-gen CSG engine. It is extremely fast (GPU-accelerated optional), handles all degenerate cases, and guarantees manifold output from manifold input.

Using Manifold means:
- CSG booleans (union, difference, intersection) are solved on day one
- We get battle-tested robustness instead of writing our own
- MIT license is fully compatible with our MIT license and App Store distribution
- Swift/C++ interop is mature in Swift 5.9+ and SPM supports C/C++ targets natively

### What Stays Swift

- SCADEngine (lexer, parser, evaluator, customizer) — 100% Swift
- App layer (SwiftUI views, view models, file handling) — 100% Swift
- Renderer (Metal shaders, render pipeline, camera) — 100% Swift + Metal
- Mesh data structures and conversions — Swift, bridging to/from Manifold types
- Extrusion operations — Swift (generates mesh, hands to Manifold for booleans)
- Export (STL, 3MF) — Swift

### What Uses C++ (via SPM C++ target)

- CSG boolean operations — Manifold library
- Hull / Minkowski operations (v2.0) — Manifold
- Potentially BREP operations (v2.0+) — evaluate wrapping OpenCASCADE or building minimal BREP in Swift

### Updated Package Structure

```
OpeniOSCAD/
├── OpeniOSCAD/                         ← iOS app target (SwiftUI)
│   ├── App/
│   │   └── OpeniOSCADApp.swift
│   ├── Views/
│   │   ├── ViewportView.swift
│   │   ├── FeatureTreeView.swift
│   │   ├── ScriptEditorView.swift
│   │   ├── ParameterPanelView.swift
│   │   ├── ToolbarView.swift
│   │   └── SketchCanvasView.swift      (v1.5)
│   ├── ViewModels/
│   │   ├── ModelViewModel.swift
│   │   ├── ScriptBridge.swift          ← GUI action → script text generation
│   │   └── SketchViewModel.swift       (v1.5)
│   └── Services/
│       ├── UndoManager.swift           ← Script-level undo/redo
│       ├── FileManager.swift           ← .scad file I/O
│       └── ExportService.swift         ← Coordinates export pipeline
│
├── SCADEngine/                          ← Swift package: OpenSCAD interpreter
│   ├── Sources/SCADEngine/
│   │   ├── Lexer/
│   │   ├── Parser/
│   │   ├── Evaluator/
│   │   ├── Customizer/
│   │   └── Export/SCADExporter.swift
│   └── Tests/SCADEngineTests/
│
├── GeometryKernel/                      ← Swift package + C++ dependency
│   ├── Sources/
│   │   ├── GeometryKernel/             ← Swift code
│   │   │   ├── Primitives/
│   │   │   │   ├── Cube.swift
│   │   │   │   ├── Cylinder.swift
│   │   │   │   ├── Sphere.swift
│   │   │   │   └── Polyhedron.swift
│   │   │   ├── CSG/
│   │   │   │   └── CSGOperations.swift ← Swift wrapper calling ManifoldBridge
│   │   │   ├── Transforms/
│   │   │   ├── Extrude/
│   │   │   ├── Mesh/
│   │   │   │   ├── TriangleMesh.swift
│   │   │   │   └── MeshConversion.swift ← Convert TriangleMesh <-> Manifold types
│   │   │   ├── Export/
│   │   │   │   ├── STLExporter.swift
│   │   │   │   └── ThreeMFExporter.swift
│   │   │   ├── Sketch/ (v1.5)
│   │   │   │   ├── SketchPrimitive.swift
│   │   │   │   ├── Constraint.swift
│   │   │   │   └── ConstraintSolver.swift
│   │   │   └── BREP/ (v2.0)
│   │   │
│   │   └── ManifoldBridge/             ← C++ interop layer
│   │       ├── include/
│   │       │   └── ManifoldBridge.h    ← C header exposing Manifold ops to Swift
│   │       └── ManifoldBridge.cpp      ← C++ impl calling Manifold library
│   │
│   └── Tests/GeometryKernelTests/
│
├── Renderer/                            ← Swift package + Metal
│   ├── Sources/Renderer/
│   │   ├── Shaders/
│   │   ├── RenderPipeline.swift
│   │   ├── Camera.swift
│   │   └── SelectionHighlighter.swift
│   └── Tests/RendererTests/
│
├── MaestroTests/                        ← E2E (from 03_MAESTRO_TESTING.md)
├── TestFixtures/
├── .github/workflows/
│
├── CLAUDE.md                            ← Claude Code persistent instructions
└── README.md
```

### ManifoldBridge Pattern

The bridge is a thin C-callable layer so Swift can use it without direct C++ interop complexity:

```c
// ManifoldBridge.h
#ifndef MANIFOLD_BRIDGE_H
#define MANIFOLD_BRIDGE_H

#include <stdint.h>

typedef struct {
    float x, y, z;
} MBVertex;

typedef struct {
    uint32_t a, b, c;
} MBTriangle;

typedef struct {
    MBVertex* vertices;
    uint32_t vertex_count;
    MBTriangle* triangles;
    uint32_t triangle_count;
} MBMesh;

typedef void* MBManifold;

MBManifold mb_create_from_mesh(const MBMesh* mesh);
MBManifold mb_boolean_union(MBManifold a, MBManifold b);
MBManifold mb_boolean_difference(MBManifold a, MBManifold b);
MBManifold mb_boolean_intersection(MBManifold a, MBManifold b);
MBManifold mb_hull(MBManifold* inputs, uint32_t count);
MBMesh mb_to_mesh(MBManifold m);
void mb_free_manifold(MBManifold m);
void mb_free_mesh(MBMesh* mesh);

#endif
```

Swift calls these C functions. The .cpp implementation wraps Manifold's C++ API. This keeps the C++ contained to one directory with one header.

### Updated Task 1.6: CSG Booleans

The original task spec said "implement BSP-tree mesh booleans in Swift." Updated:

1. Add Manifold as a dependency (git submodule or SPM dependency)
2. Build the ManifoldBridge C target
3. Write `MeshConversion.swift` to convert `TriangleMesh` to/from `MBMesh`
4. Write `CSGOperations.swift` as Swift wrappers:

```swift
struct CSGOperations {
    static func union(_ a: TriangleMesh, _ b: TriangleMesh) -> TriangleMesh
    static func difference(_ a: TriangleMesh, _ b: TriangleMesh) -> TriangleMesh
    static func intersection(_ a: TriangleMesh, _ b: TriangleMesh) -> TriangleMesh
}
```

Same acceptance criteria as before, but now the implementation wraps Manifold instead of rolling your own. This should take days instead of months.

---

## Phase 2 Tasks: GUI → Script Bridge

Phase 1 gives us: parse .scad → evaluate → render → export. Phase 2 makes the GUI write script, making the app bidirectional.

### Task 2.1: ScriptBridge — GUI Actions Generate Script

**Files:** `OpeniOSCAD/ViewModels/ScriptBridge.swift`

**What it does:** When the user performs a GUI action (add cube, add cylinder, etc.), ScriptBridge generates the corresponding OpenSCAD code and inserts it into the script text at the correct position.

**Script generation rules:**
- "Add Cube" → appends `cube([10, 10, 10]);` and a `// @feature "Cube 1"` annotation above it
- "Add Cylinder" → appends `cylinder(h=10, r=5, $fn=32);` with `// @feature "Cylinder 1"`
- "Add Sphere" → appends `sphere(r=5, $fn=32);` with `// @feature "Sphere 1"`
- Feature names auto-increment: "Cube 1", "Cube 2", etc.
- Insertions go after the currently selected feature in the tree (or at end if nothing selected)
- Boolean operations: when user selects two bodies and picks "Subtract," wrap them in `difference() { ... }`

**The critical flow:**
```
User taps [+] → Cube
    |
ScriptBridge.insertPrimitive(.cube, afterFeature: selectedFeature)
    |
Script text is mutated (insert lines)
    |
ModelViewModel detects script change
    |
Re-parse → re-evaluate → re-render → update feature tree
```

**Acceptance criteria:**
- Adding a primitive via GUI produces valid .scad code that desktop OpenSCAD would accept
- The @feature annotation is present so the feature tree picks it up
- Inserting after a specific feature puts the code in the right place
- The generated code is clean and readable (proper indentation, no junk)
- Tests: generate script for each primitive type, verify it parses and evaluates correctly

### Task 2.2: Bidirectional Feature Tree

**Files:** `OpeniOSCAD/Views/FeatureTreeView.swift`, updates to `ModelViewModel.swift`

**What it does:** The feature tree reads @feature annotations from the parsed AST and displays them as a reorderable list. Interactions in the tree modify the script.

**Operations:**
- **Select:** Tap a feature → highlights corresponding geometry in viewport, moves cursor to script block
- **Reorder:** Long-press drag → physically moves the script block (the lines between one @feature and the next) to the new position in the script text, triggers rebuild
- **Suppress:** Swipe → toggle eye icon → comments out the script block (`// @feature` becomes `// @feature [suppressed]` and all lines in the block get `//` prepended). Rebuild skips it.
- **Delete:** Swipe → delete → removes the script block entirely, triggers rebuild
- **Rename:** Tap the name → edit inline → updates the `// @feature "Name"` comment in script

**Script block definition:** A "feature block" is everything from one `// @feature` line to the line before the next `// @feature` (or end of file). The parser/annotation extractor must output line ranges for each feature.

**Acceptance criteria:**
- Feature tree reflects the @feature annotations in the current script
- Reordering features in the tree moves the correct lines of script and the model rebuilds correctly
- Suppressing a feature comments out the right lines and the model rebuilds without that feature
- Deleting removes the lines and rebuilds
- All operations are undoable (Task 2.3)
- Maestro tests 05_feature_tree_reorder.yaml and 08_feature_tree_select.yaml pass

### Task 2.3: Undo/Redo System

**Files:** `OpeniOSCAD/Services/UndoManager.swift`, updates to `ModelViewModel.swift`

**What it does:** Script-level undo/redo. Since the script IS the model, undo is just reverting the script text to its previous state.

**Implementation:**
- Maintain a stack of script snapshots (or text diffs for memory efficiency)
- Every mutation to the script text (GUI action, direct edit, tree reorder) pushes a new state
- Undo pops the stack and restores the previous script text
- Redo pushes forward
- Debounce rapid typing in the script editor (don't push a snapshot per keystroke — batch by pause)
- Integrate with iOS UndoManager for shake-to-undo and three-finger gestures

**Acceptance criteria:**
- Every GUI action (add primitive, reorder, suppress, delete, rename) is undoable
- Script editor changes are undoable (with debounce)
- Undo/redo updates the script, which triggers re-parse → re-evaluate → re-render
- Three-finger swipe left = undo, right = redo (iOS standard)
- Maestro test 09_undo_redo.yaml passes
- Memory: undo stack doesn't grow unbounded (cap at 100 states or use diff-based storage)

### Task 2.4: Live Customizer Panel

**Files:** `OpeniOSCAD/Views/ParameterPanelView.swift`, updates to `ModelViewModel.swift`

**What it does:** The customizer panel shows sliders/pickers for annotated variables. Changing a value updates the variable assignment in the script text and triggers rebuild.

**The key insight:** The customizer doesn't talk to the evaluator directly. It modifies the SCRIPT TEXT (changes `width = 40;` to `width = 55;`), which triggers the normal parse → evaluate → render pipeline. Script-authoritative, always.

**Implementation:**
- CustomizerExtractor (Task 1.4) identifies params with line numbers
- ParameterPanelView renders controls based on param type and constraints
- On slider drag: update the number literal in the script text at the correct line/column
- Debounce during continuous drag (don't rebuild on every pixel of slider movement — throttle to ~15fps rebuilds)
- On slider release: final rebuild + push undo state
- Show current value next to slider
- Group params by `/* [Tab Name] */` headers

**Acceptance criteria:**
- Sliders appear for variables with `// [min:max]` annotations
- Dropdowns appear for variables with `// [opt1, opt2]` annotations
- Checkboxes appear for boolean variables
- Text fields appear for string variables
- Changing any control updates the script text and the model rebuilds
- During slider drag, preview updates smoothly (throttled)
- Maestro tests 05_customizer_sliders.yaml and 06_modify_parameter.yaml pass

### Task 2.5: Incremental Evaluation

**Files:** Updates to `SCADEngine/Sources/SCADEngine/Evaluator/Evaluator.swift`

**What it does:** When a single variable changes (like a customizer slider), don't re-evaluate the entire script. Track which geometry depends on which variables and only rebuild what changed.

**Implementation approach:**
- During evaluation, track which variables each GeometryOp depends on
- When a variable changes, mark dependent GeometryOps as dirty
- Only re-evaluate dirty ops; reuse cached results for clean ops
- For v1, a simpler approach is acceptable: if only a top-level variable changed, re-evaluate everything but cache intermediate Manifold objects and skip re-computing unchanged subtrees

**Acceptance criteria:**
- Changing a customizer variable on a 50-feature model rebuilds in < 200ms on iPhone 15 (vs full rebuild time)
- Changing a variable that only one feature depends on is noticeably faster than full rebuild
- Results are identical to full re-evaluation (no stale cache bugs)
- Performance benchmarks in integration tests

### Task 2.6: Script Editor Enhancements

**Files:** `OpeniOSCAD/Views/ScriptEditorView.swift`

**What it does:** Upgrade the basic text editor from Phase 1 into a proper code editor.

**Features:**
- Syntax highlighting: keywords (blue), numbers (orange), strings (green), comments (gray), @feature annotations (purple), $variables (teal)
- Line numbers in left gutter
- Inline error markers: red underline on lines with parse/eval errors, tap for error message
- Basic autocomplete: when typing, suggest OpenSCAD builtins and variable names from current scope
- Code folding: collapse module definitions and @feature blocks
- "Jump to feature": when user taps a feature tree item, scroll script editor to that line
- "Jump to 3D": when user taps a line containing geometry, highlight that geometry in viewport

**Acceptance criteria:**
- Syntax highlighting covers all OpenSCAD token types
- Errors show inline (not just in console)
- Autocomplete popup appears after typing 2+ characters
- Jump-to-feature scrolls to correct line
- Performance: no lag when typing in a 500-line script
- Maestro test 04_script_editor_toggle.yaml passes

---

## Phase 3-5 Task Outlines

These are less detailed than Phase 1-2 because they'll be informed by learnings from earlier phases. But the architecture needs to accommodate them, so agents should be aware of what's coming.

### Phase 3: Sketch + Constrain (v1.5)

**3.1 — 2D Sketch Primitives:** Line, arc, circle, rectangle, polygon, spline as 2D entities with a shared SketchEntity protocol. Stored as structured data, not mesh.

**3.2 — Constraint Solver:** Newton-Raphson iterative solver for geometric constraints (coincident, tangent, perpendicular, parallel, equal, horizontal, vertical, fixed, dimension). This is the hardest engineering task in the entire project. Evaluate wrapping SolveSpace's solver (GPL — licensing issue) vs building minimal solver. Under-constrained sketches must remain draggable. Over-constrained must report conflicts.

**3.3 — Sketch Mode UI:** Orthographic 2D canvas on the sketch plane. Sketch toolbar (line, arc, circle, rect, dimension). Constraint visualization with the "make it feel like a game" approach from the vision doc. Enter sketch mode by selecting a face + tapping "Sketch."

**3.4 — Sketch → Extrude/Cut Workflow:** Select a completed sketch, extrude or cut. The script emits the @sketch annotation comment + OpenSCAD-compatible CSG fallback.

**3.5 — Construction Geometry:** Reference lines and points that participate in constraints but don't generate geometry.

### Phase 4: BREP (v2.0)

**4.1 — BREP Data Structure:** Vertex, Edge, Face, Shell, Solid with topological adjacency. This is the foundation for fillet/chamfer/shell.

**4.2 — Fillet/Chamfer:** Select edges, apply radius. Requires BREP edge identification from the mesh. Evaluate whether Manifold provides enough topology info or if we need a separate BREP kernel (potentially wrapping a subset of OpenCASCADE).

**4.3 — Shell Operation:** Select faces to remove, specify wall thickness, hollow the solid.

**4.4 — STEP Export:** Convert BREP representation to STEP AP214. This is a significant format implementation. Consider wrapping an existing STEP writer.

**4.5 — text() Support:** Font rendering pipeline. Convert text to 2D outlines, then extrude. Requires font parsing (CoreText can help on iOS).

**4.6 — minkowski/hull:** Manifold may support hull natively. Minkowski sum is more complex. Implement based on Manifold capabilities.

### Phase 5: Polish (v2.5-3.0)

**5.1 — Sweep/Loft:** Sweep a profile along a path. Loft between two or more profiles.

**5.2 — Patterns:** Linear pattern (repeat along vector), circular pattern (repeat around axis), mirror pattern.

**5.3 — Multi-body:** Multiple independent solid bodies in one file. Important for assemblies.

**5.4 — Assembly Constraints:** Mate, align, insert constraints between parts/bodies.

**5.5 — 2D Drawing Generation:** Orthographic projections, section views, dimension annotations. Export to DXF/PDF.

**5.6 — iPad Layout:** Side-by-side script editor + 3D viewport. Apple Pencil support in sketch mode.

**5.7 — Community/Sharing:** Cloud upload for shareable parametric customizer links. Module/library package manager.

---

## CLAUDE.md — Claude Code Persistent Instructions

Put this content in the repo root as CLAUDE.md. Claude Code reads it automatically on every session.

```
# CLAUDE.md — OpeniOSCAD Project Instructions

## What This Project Is
OpeniOSCAD is a free (MIT), native iOS parametric CAD app. Every model is an OpenSCAD-compatible .scad script. The GUI writes script, the engine evaluates script, the viewport renders the result.

## Architecture — Non-Negotiable
- Script-authoritative. The .scad text is the single source of truth. GUI actions modify the script text. The engine rebuilds geometry from script. Never store model state independently of the script.
- Three Swift packages + one app target:
  - SCADEngine: OpenSCAD lexer/parser/evaluator. Pure Swift. No UI dependencies.
  - GeometryKernel: Mesh primitives, CSG (via Manifold C++ bridge), transforms, extrusions, export. Swift + C++ interop.
  - Renderer: Metal render pipeline, camera, selection. Swift + Metal.
  - OpeniOSCAD (app): SwiftUI views, view models, file handling. Depends on all three packages.
- CSG booleans use the Manifold library via a C bridge (ManifoldBridge). Do not rewrite mesh booleans in Swift.

## Code Rules
- Swift for all app logic, script engine, UI, rendering, mesh generation, export.
- C++ ONLY in GeometryKernel/Sources/ManifoldBridge/ for wrapping the Manifold library. Nowhere else.
- Every interactive UI element MUST have .accessibilityIdentifier() for Maestro testing. See 03_MAESTRO_TESTING.md for the naming convention.
- Write unit tests alongside implementations, not after. Tests live in each package's Tests/ directory.
- No force unwraps in production code. Use guard/let or throw.
- Errors from script parsing/evaluation must include line numbers and descriptive messages.

## Script-Authoritative Flow
When implementing ANY feature that changes the model:
1. The action MUST modify the script text (String)
2. ModelViewModel detects the script change
3. SCADEngine re-parses and re-evaluates
4. GeometryKernel produces updated mesh
5. Renderer displays the result
6. Feature tree updates from @feature annotations

NEVER skip this flow. Never cache model state outside the script. Never let the viewport or feature tree be the source of truth.

## OpenSCAD Compatibility
- Standard .scad files from Thingiverse must parse and render.
- OpeniOSCAD extensions use structured comments: // @feature "Name"
- Desktop OpenSCAD ignores these comments. Our parser extracts them for the feature tree.
- When exporting, all output must be valid OpenSCAD syntax.

## File Organization
- Keep package boundaries clean. SCADEngine should not import GeometryKernel types directly in its public API. Use a protocol/enum (GeometryOp) as the interface between engine and kernel.
- Mesh data flows: SCADEngine produces GeometryOp tree → GeometryKernel evaluates to TriangleMesh → Renderer displays TriangleMesh.

## Testing
- Unit tests: every package has Tests/ with XCTest targets.
- Integration tests: TestFixtures/thingiverse_samples/ contains real .scad files. Test that they parse, evaluate, and produce non-empty meshes.
- E2E tests: MaestroTests/flows/ contains Maestro YAML flows for iOS Simulator.
- Run unit tests: `xcodebuild test -scheme SCADEngine -destination 'platform=iOS Simulator,name=iPhone 16'`
- Run Maestro: `./MaestroTests/scripts/build_and_test.sh`

## Performance Targets
- Script parse+eval: <100ms on iPhone 15
- Full model rebuild (<50 features): <500ms on iPhone 15  
- Display render: 60fps for <100K triangles
- STL export: <1s for 100K triangles

## What NOT to Do
- Do not add Python, JavaScript, or WASM to this project.
- Do not use C++ outside of ManifoldBridge.
- Do not store model geometry independently of the script.
- Do not skip the script-authoritative flow for "optimization." If it's slow, optimize the pipeline, don't bypass it.
- Do not add third-party UI frameworks. SwiftUI + UIKit (for Metal view) only.
- Do not add networking or cloud features until Phase 5.
```

---

## Manifold Integration Checklist

For the agent picking up the Manifold integration:

1. **Clone Manifold:** Add as git submodule or SPM dependency. Manifold repo: https://github.com/elalish/manifold (note: correct repo is elalish, not ennomane)
2. **Cross-compile for iOS:** Manifold uses CMake. You'll need to cross-compile for iOS ARM64 (device) and x86_64 (simulator). Create a build script that produces a .a static library for both architectures.
3. **Create the ManifoldBridge SPM target:** A C target in the GeometryKernel package that includes ManifoldBridge.h and ManifoldBridge.cpp, linking against the Manifold static library.
4. **Implement MeshConversion.swift:** Convert between our TriangleMesh (Swift) and MBMesh (C struct). This is the boundary between Swift and C worlds.
5. **Implement CSGOperations.swift:** Swift functions that call the C bridge functions and return TriangleMesh results.
6. **Test:** Unit tests for union, difference, intersection on known primitives. Verify manifoldness of results.

If Manifold proves too complex to cross-compile for iOS in the short term, an acceptable interim is to use a simpler CSG approach (like the original BSP-tree plan) and swap in Manifold later. The CSGOperations.swift API stays the same either way — the bridge is an implementation detail behind a clean Swift interface.

---

## Prompt for Claude Code — Phase 2 Kickoff

Use this prompt after Phase 1 is working:

```
Read CLAUDE.md, 01_VISION_AND_ARCHITECTURE.md, and 04_UPDATED_ARCH_AND_REMAINING_PHASES.md.

Phase 1 is complete: the app can parse .scad files, evaluate them, render 3D, and export STL.

Now implement Phase 2 — the GUI → Script bridge. The goal is: every GUI action writes OpenSCAD script, and the script is always the source of truth.

Tasks in order:
1. Task 2.1: ScriptBridge — GUI primitive insertion writes .scad code with @feature annotations
2. Task 2.3: Undo/Redo — script-level undo stack, integrated with iOS UndoManager
3. Task 2.2: Bidirectional Feature Tree — reorder/suppress/delete modify the script text
4. Task 2.4: Live Customizer Panel — slider changes modify variable assignments in script text
5. Task 2.5: Incremental Evaluation — cache unchanged subtrees during rebuild
6. Task 2.6: Script Editor Enhancements — syntax highlighting, errors, autocomplete, jump-to

Write tests alongside each implementation. Run Maestro flows after each task to catch regressions. The critical invariant to maintain: the .scad script text is ALWAYS the source of truth. No model state exists outside the script.
```

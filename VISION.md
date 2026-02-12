# OpeniOSCAD — Vision & Architecture

## What This Is

OpeniOSCAD is a free, open-source (MIT), native iOS parametric CAD app. Users build 3D models by adding features — sketches, extrusions, fillets, booleans — through direct touch interaction. The app stores models as a typed feature history, renders them with Metal, and exports to industry formats including OpenSCAD scripts, STL, 3MF, and STEP.

This is not a script editor that happens to render 3D. This is a parametric CAD tool that happens to be able to export scripts.

## Decided — Do Not Revisit

- **Name:** OpeniOSCAD
- **License:** MIT, public GitHub repo
- **Price:** Free. No IAP, no subscription, no paid tiers.
- **Platform:** iPhone primary. iPad fast-follow (same codebase, adaptive layout).
- **Language:** Swift + Metal for all app logic. C++ only for Manifold (CSG booleans) via a thin C bridge.
- **Source of truth:** The feature tree — a typed, ordered list of Feature objects. Not a script. Not a mesh.
- **Design philosophy:** Accessible AND serious. Progressive disclosure. Direct manipulation. Respect user intelligence.

## Core Architecture Principle

**The feature tree is the single source of truth. Always.**

```
User taps "Add Cube"
       |
       v
App appends Feature.primitive(.cube, params) to the feature list
       |
       v
ParametricEngine evaluates the feature list top-to-bottom
       |
       v
GeometryKernel produces geometry (BREP solid → tessellated mesh)
       |
       v
Metal renderer displays the mesh. Feature tree UI updates.
```

The model is NEVER stored independently of the feature list. Undo = revert the feature list. Save = serialize the feature list. Export = generate script/mesh from the evaluated model. Feature reorder = move an entry in the list. Suppress = mark a feature as suppressed.

Scripts (OpenSCAD, CadQuery) are **export formats**, not the native representation. The app can also **import** .scad files by parsing them into features, but internally everything is the typed feature tree.

## System Architecture

Four Swift packages + one app target:

```
OpeniOSCAD (iOS App — SwiftUI)
  ├── Views: Viewport, FeatureTree, PropertyPanel, SketchCanvas, Toolbar
  ├── ViewModels: ModelViewModel, SketchViewModel
  └── Services: UndoManager, FileService, ExportService

ParametricEngine (Swift Package — model evaluation)
  ├── Feature types (Sketch, Extrude, Revolve, Fillet, Boolean, Pattern, etc.)
  ├── FeatureEvaluator (walks the feature list, produces geometry)
  ├── ConstraintSolver (2D sketch constraints)
  └── ScriptExporter (Feature[] → .scad / .py text)

GeometryKernel (Swift Package + Manifold C++ bridge)
  ├── BREP types (Vertex, Edge, Face, Shell, Solid)
  ├── Primitives (box, cylinder, sphere → BREP solids)
  ├── Operations (extrude, revolve, fillet, chamfer, shell, booleans)
  ├── Tessellator (BREP solid → TriangleMesh for display)
  ├── ManifoldBridge (C bridge to Manifold for CSG booleans)
  └── Export (STL, 3MF, STEP writers)

Renderer (Swift Package + Metal)
  ├── Metal shaders, render pipeline
  ├── Camera (orbit, pan, zoom)
  └── Selection (face/edge highlight, pick ray)

SCADParser (Swift Package — OpenSCAD import only)
  ├── Lexer, Parser, Evaluator
  └── FeatureConverter (AST → Feature[] for import)
```

### Package Boundaries

- **ParametricEngine** defines the `Feature` types and evaluates them. It calls GeometryKernel for geometry operations. It has no UI dependencies.
- **GeometryKernel** knows nothing about features. It operates on geometry: create solid, boolean two solids, fillet an edge, tessellate for display, export to file format.
- **Renderer** knows only `TriangleMesh` and selection state. Zero dependency on ParametricEngine or feature concepts.
- **SCADParser** is an import-only module. It parses .scad text into an AST, evaluates it, and converts the result to `Feature[]` objects that the rest of the app understands. It is not on the critical path for normal app usage.
- **App layer** orchestrates everything: user interaction → modify Feature[] → evaluate → render.

### Data Flow

```
Feature[] (source of truth)
    │
    ├──→ ParametricEngine.evaluate(features)
    │         │
    │         ├──→ GeometryKernel: create primitives, extrude sketches,
    │         │    apply booleans (via Manifold), fillet edges
    │         │         │
    │         │         └──→ BREPSolid (exact geometry)
    │         │                  │
    │         │                  ├──→ Tessellator → TriangleMesh → Renderer (display)
    │         │                  ├──→ STLExporter (mesh export)
    │         │                  ├──→ STEPExporter (BREP export)
    │         │                  └──→ ThreeMFExporter (mesh export)
    │         │
    │         └──→ ScriptExporter → .scad text (OpenSCAD export)
    │                             → .py text (CadQuery export)
    │
    ├──→ FeatureTreeView (UI list of features)
    │
    ├──→ PropertyPanel (editable parameters for selected feature)
    │
    └──→ FileService.save() → .ioscad file (JSON serialization)
```

## The Feature System

Every modeling operation is a Feature. Features are evaluated in order, top to bottom. Each feature takes the current model state and produces updated model state.

### Feature Types

```swift
enum Feature: Identifiable, Codable {
    // Primitives — create a new solid body
    case primitive(id, name, PrimitiveParams)       // box, cylinder, sphere, cone

    // Sketch — 2D profile on a plane
    case sketch(id, name, plane, [SketchEntity], [Constraint])

    // Solid operations — create 3D from 2D
    case extrude(id, name, sketchRef, depth, direction)
    case cut(id, name, sketchRef, depth, direction)  // extrude-subtract
    case revolve(id, name, sketchRef, axis, angle)

    // Modify operations — alter existing solid
    case fillet(id, name, edgeRefs, radius)
    case chamfer(id, name, edgeRefs, distance)
    case shell(id, name, faceRefs, thickness)

    // Boolean operations — combine solids
    case booleanUnion(id, name, bodyRefs)
    case booleanSubtract(id, name, targetRef, toolRefs)
    case booleanIntersect(id, name, bodyRefs)

    // Transform operations
    case transform(id, name, bodyRef, TransformParams)  // translate, rotate, scale, mirror

    // Patterns
    case linearPattern(id, name, featureRef, direction, count, spacing)
    case circularPattern(id, name, featureRef, axis, count, angle)

    // Import
    case importMesh(id, name, filePath, format)     // STL, 3MF, OBJ

    // Metadata
    var id: UUID
    var name: String
    var isSuppressed: Bool
    var parameters: [String: ParameterValue]        // user-editable params
}
```

### Feature Evaluation

The evaluator walks the feature list in order, maintaining a `ModelState` — the set of solid bodies that exist at each point in the history:

```
Feature 1: primitive(box, 20×20×10)        → ModelState: [Body A]
Feature 2: sketch(top face of A, circle)   → ModelState: [Body A], sketch pending
Feature 3: cut(sketch, depth: 5)           → ModelState: [Body A with hole]
Feature 4: fillet(hole edges, radius: 2)   → ModelState: [Body A with filleted hole]
```

Editing Feature 1's dimensions re-evaluates everything from Feature 1 forward. This is history-based parametric modeling — the same paradigm as SolidWorks, Fusion 360, and Onshape.

### Parameters and Editing

Every feature exposes typed parameters that the user can edit through the PropertyPanel:

- Select a feature in the tree → PropertyPanel shows its parameters
- Change a value → feature is updated → re-evaluate from that point forward → re-render
- Parameters can reference other features' geometry (e.g., "extrude from this face", "fillet these edges")

## Geometry Strategy

### Phase 1: Hybrid Mesh + Topology

For the initial release, geometry uses triangle meshes internally but maintains enough topological information (which triangles belong to which logical face/edge) to support selection and basic feature references:

- **Primitives** generate meshes with face/edge group annotations
- **Booleans** use Manifold (C++ library via bridge) — robust, fast, battle-tested
- **Extrude/Revolve** generate meshes from 2D profiles with proper face groups
- **Fillet/Chamfer** operate on annotated edge groups (mesh-based approximation)
- **Selection** uses face/edge group IDs, not raw triangles

This gets a working app shipped without requiring a full BREP kernel.

### Phase 2+: True BREP

When the foundation is solid, evolve toward exact BREP representation:

- Primitives and extrusions produce exact analytical surfaces (planes, cylinders, spheres, toroidal blends)
- Booleans produce exact BREP (potentially wrapping OpenCASCADE or building minimal BREP ops)
- Tessellation happens only at the display boundary
- STEP export produces exact geometry, not approximated meshes
- Fillets produce proper rolling-ball blends

The key: **the Feature types and app architecture don't change** between Phase 1 and Phase 2. Only the GeometryKernel internals change. The feature tree, UI, undo system, file format, and export pipeline all stay the same.

## File Format

### Native: `.ioscad` (JSON)

The native file format is a JSON serialization of the feature list plus metadata:

```json
{
  "version": 1,
  "name": "Bracket",
  "units": "mm",
  "features": [
    {
      "type": "primitive",
      "id": "...",
      "name": "Base Plate",
      "primitive": "box",
      "params": { "width": 40, "height": 25, "depth": 3 },
      "suppressed": false
    },
    {
      "type": "sketch",
      "id": "...",
      "name": "Hole Profile",
      "plane": { "faceRef": "...", "featureId": "..." },
      "entities": [ { "type": "circle", "center": [20, 12.5], "radius": 2.5 } ],
      "constraints": [ { "type": "concentric", "entity": 0, "faceRef": "..." } ]
    },
    {
      "type": "cut",
      "id": "...",
      "name": "Mounting Hole",
      "sketchRef": "...",
      "depth": 5,
      "direction": "through"
    }
  ]
}
```

This is human-readable, diffable in git, and trivially serializable with Swift's Codable.

### Import

- **.scad** — Parse with SCADParser, convert to Feature[] (best-effort: primitives + booleans + transforms map cleanly; complex scripts may produce a single "imported group" feature)
- **.stl / .3mf / .obj** — Import as mesh body (Feature.importMesh)
- **.step** — Future: parse BREP geometry into features

### Export

- **.scad** — ScriptExporter generates valid OpenSCAD from the feature list. Primitives, booleans, and transforms map directly. Sketches export as CSG approximations with comments preserving the original sketch data. Any .scad exported by this app should render identically in desktop OpenSCAD.
- **.py (CadQuery)** — For users who want a more capable script format. CadQuery can express sketches, fillets, chamfers, assemblies — much closer to what our feature tree actually represents.
- **.stl / .3mf** — Tessellate and write mesh.
- **.step** — Export exact BREP geometry (Phase 2+, mesh approximation in Phase 1).
- **.svg / .dxf** — 2D projection export (future).

## UI/UX Design

### iPhone Layout

```
+---------------------------+
|  +---------------------+  |
|  |   3D Viewport       |  |  ← Primary, always visible
|  |   (Metal render)    |  |     Pinch/pan/orbit
|  |                     |  |     Tap to select face/edge/body
|  +---------------------+  |
|  +---------------------+  |
|  |  Feature Tree       |  |  ← Collapsible bottom panel
|  |  (ordered history)  |  |     Tap: select. Drag: reorder.
|  +---------------------+  |
|  | [+]  [sketch]  [≡]  |  |  ← Primary actions
|  +---------------------+  |
+---------------------------+
```

### Modal States

1. **Model Mode** — 3D viewport + feature tree + toolbar. Primary interaction mode.
2. **Sketch Mode** — 2D orthographic canvas on a selected plane/face. Sketch tools (line, arc, circle, rect, dimension). Constraint visualization. Exit sketch → return to model mode.
3. **Property Mode** — PropertyPanel slides up showing parameters for the selected feature. Edit values, see live preview.
4. **Export Mode** — Export sheet with format options and settings.

### Direct Manipulation

The whole point of moving away from script-authoritative is to enable real direct manipulation:

- **Tap a face** → select it → options appear: "Sketch on Face", "Extrude", "Shell"
- **Tap an edge** → select it → options appear: "Fillet", "Chamfer"
- **Tap a body** → select it → options appear: "Move", "Boolean", "Pattern"
- **Drag a dimension** → live update the parameter → re-evaluate → re-render in real time
- **Double-tap a feature** → jump into editing its parameters

### Progressive Disclosure

**Level 1 (immediate):** [+] Add → (Box, Cylinder, Sphere). Sketch button. Feature tree.
**Level 2 (explore):** Long-press [+] for full primitive library. Face/edge selection reveals contextual operations. Swipe features for suppress/delete.
**Level 3 (power):** Patterns, assemblies, multi-body operations, export settings, direct script export, import from .scad.

### Gestures

- 1-finger drag: Orbit (model mode) / Draw (sketch mode)
- 2-finger pinch: Zoom
- 2-finger drag: Pan
- Tap: Select face/edge/body
- Double-tap: Edit feature / Fit-all (if nothing selected)
- Long-press: Context menu
- 3-finger swipe: Undo (left) / Redo (right) — iOS standard

### Constraint Visualization (Sketch Mode)

Make it feel like a game, not like homework:
- **Under-constrained:** Pulsing colored arrows show free degrees of freedom, draggable
- **Fully constrained:** Green outline, subtle celebration animation
- **Over-constrained:** Red highlights, tap to see conflicts and choose which to remove

### Feature Tree Interactions

- **Tap:** Select feature → highlight geometry in viewport → show in PropertyPanel
- **Long-press drag:** Reorder feature in history (re-evaluates from the moved position)
- **Swipe left:** Suppress (gray out, skip during eval) or Delete
- **Eye icon:** Toggle suppression
- **Tap name:** Rename inline
- **Tap parameter value:** Edit inline (quick edit without opening full PropertyPanel)

## OpenSCAD Compatibility

OpenSCAD compatibility is an **import/export** concern, not an architectural constraint:

- **Import:** The SCADParser module can read standard .scad files and convert them to Feature objects. Simple scripts (primitives + booleans + transforms) convert cleanly. Complex scripts with modules, loops, and conditionals produce a flattened feature set.
- **Export:** The ScriptExporter generates valid .scad from any model. Thingiverse users can download and open these in desktop OpenSCAD.
- **Customizer variables** in imported .scad files become feature parameters in the app.
- **@feature annotations** in .scad comments provide hints for better import fidelity. These are ignored by desktop OpenSCAD.

The key difference from the old architecture: we are not constrained by what OpenSCAD can express. If our feature tree supports fillets, we export the filleted result as a polyhedron in .scad, not try to express the fillet operation in a language that doesn't have one.

## Testing Strategy

### Unit Tests (XCTest)

Every package has `Tests/` with XCTest targets:
- **ParametricEngine:** Feature creation, evaluation order, parameter updates, constraint solver, script export fidelity
- **GeometryKernel:** Primitive generation, boolean correctness, tessellation quality, export format correctness, Manifold bridge
- **Renderer:** Pipeline initialization, camera math, pick ray calculation
- **SCADParser:** Lexer, parser, evaluator, feature conversion from AST
- **App:** ViewModel logic, undo/redo, file serialization round-trip

Run: `swift test --package-path ParametricEngine && swift test --package-path GeometryKernel && swift test --package-path Renderer && swift test --package-path SCADParser`

### Integration Tests

- `TestFixtures/` contains `.ioscad` files and `.scad` files for regression testing
- Test that .scad import → feature conversion → .scad export produces equivalent geometry
- Test that .ioscad save → load round-trips without data loss

### E2E Tests (Maestro)

Maestro YAML flows test the full app in iOS Simulator:
- App launch, add primitive, feature tree interaction, undo/redo, export
- Every interactive UI element MUST have `.accessibilityIdentifier()` for Maestro
- CI runs via `.github/workflows/maestro.yml`

See test flows in `MaestroTests/flows/`.

**Accessibility ID convention:**
```
toolbar_add_button
toolbar_sketch_button
toolbar_menu_button
feature_tree_item_{index}
feature_tree_item_{index}_eye
property_panel
property_field_{param_name}
property_slider_{param_name}
viewport_view
export_button
export_stl / export_3mf / export_step / export_scad
undo_button
redo_button
sketch_tool_line / sketch_tool_arc / sketch_tool_circle / sketch_tool_rect
sketch_tool_dimension
sketch_done_button
```

## Development Phases

### Phase 1: Foundation

Core modeling loop: add primitive → see it → select faces/edges → modify → undo → save → export.

- ParametricEngine with primitive features (box, cylinder, sphere, cone)
- GeometryKernel with mesh generation, Manifold booleans, face/edge group tracking
- Metal renderer with selection highlighting
- Feature tree UI with reorder, suppress, delete
- PropertyPanel for editing feature parameters
- Undo/redo (feature list snapshots)
- Native file format (.ioscad) save/load
- STL and 3MF export
- Boolean features (union, subtract, intersect)
- Transform features (translate, rotate, scale, mirror)

### Phase 2: Sketch + Extrude

The workflow that makes parametric CAD actually parametric: sketch a 2D profile, extrude it, reference existing geometry.

- Sketch mode: 2D canvas on a selected face/plane
- Sketch primitives: line, arc, circle, rectangle, polygon
- Constraint solver: coincident, tangent, perpendicular, parallel, equal, dimension
- Extrude/Cut from sketch
- Revolve from sketch
- Face/edge reference system (features can reference geometry from earlier features)
- Constraint visualization ("make it feel like a game")

### Phase 3: Advanced Operations

The features that turn basic modeling into serious CAD.

- Fillet and chamfer (mesh-based in Phase 1 kernel, exact in BREP upgrade)
- Shell operation
- Draft angle
- Linear and circular patterns
- Mirror pattern
- .scad import (SCADParser → Feature conversion)
- .scad and CadQuery export
- OpenSCAD customizer variable import

### Phase 4: BREP + Precision

Upgrade the geometry kernel for engineering-grade output.

- True BREP representation (exact surfaces, not mesh approximation)
- STEP AP214 export with exact geometry
- text() feature (font outlines → sketch → extrude)
- Sweep (profile along path)
- Loft (between profiles)
- Improved fillet/chamfer with exact rolling-ball blends

### Phase 5: Polish + Ship

- iPad layout (side-by-side panels, Apple Pencil in sketch mode)
- Multi-body support and assembly constraints
- 2D drawing generation (orthographic projections, dimensions, section views)
- DXF/SVG/PDF export
- App Store launch
- Community sharing (parametric customizer links)

## Performance Targets

| Operation | iPhone 15 | iPhone 12 |
|-----------|-----------|-----------|
| Add feature + re-eval (< 10 features) | < 50ms | < 150ms |
| Full rebuild (< 50 features) | < 500ms | < 1.5s |
| Sketch constraint solve | < 16ms | < 50ms |
| Display render | 60fps (< 100K tris) | 30fps |
| Tessellation | < 100ms | < 300ms |
| STL export (100K tris) | < 1s | < 3s |
| File save/load | < 50ms | < 150ms |
| .scad import (500 lines) | < 200ms | < 600ms |

## Design Philosophy

Most CAD apps are unapproachable not because engineering is hard but because the UI is bad. Decades of dogma: 200-icon toolbars, 6-deep modal dialogs, right-click menus that change with invisible state.

Every UI decision asks: "Is this complexity necessary, or is it dogma?"

- **Direct manipulation over text manipulation.** Touch a face, extrude it. Don't type "linear_extrude(height=10) square([20,20]);" into a text box.
- **Progressive disclosure over feature dumps.** Show 3 tools, let users discover 30.
- **The feature tree is your history.** Every step is visible, reorderable, editable, suppressible. No black boxes.
- **Constraints are visible, not hidden.** Show degrees of freedom as draggable handles. Make sketching feel like a game.
- **Undo is fearless.** The feature list IS the undo history. You can always go back.
- **Export is generous.** Your model, your formats. OpenSCAD, CadQuery, STL, 3MF, STEP. No lock-in.
- **Respect the user's intelligence.** A hobbyist and an engineer need the same tool. The difference is disclosure, not capability.

## What NOT to Do

- Do not store model geometry independently of the feature list.
- Do not make script the source of truth. Script is an export format.
- Do not add Python, JavaScript, or WASM runtimes.
- Do not use C++ outside of the ManifoldBridge directory.
- Do not add third-party UI frameworks. SwiftUI + UIKit (for Metal view) only.
- Do not add networking or cloud features until Phase 5.
- Do not skip the feature evaluation pipeline for "optimization." If it's slow, optimize the pipeline, don't bypass it.
- Do not design the UI around OpenSCAD's limitations. Design the UI for parametric CAD; export to OpenSCAD as a lossy format.

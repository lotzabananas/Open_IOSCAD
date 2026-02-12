# Phase 1: Foundation

## Goal

A user can launch the app, add primitives (box, cylinder, sphere), apply boolean operations and transforms, see live-rendered results, edit parameters, select faces/edges, undo/redo, save/load STEP files with full parametric history, and export STL/3MF.

This phase wires up the complete feature-authoritative pipeline end to end: **Feature[] -> ParametricEngine -> GeometryKernel -> Tessellator -> TriangleMesh -> Renderer**.

---

## Current State Assessment

### Done

| Area | Status | Details |
|------|--------|---------|
| Primitive generators | Complete | Cube, Cylinder, Sphere, Polyhedron in GeometryKernel |
| Boolean operations | Complete | BSP-tree CSG: union, difference, intersection |
| All transforms | Complete | Translate, rotate, scale, mirror matrices + winding flip |
| Linear/Rotate extrude | Complete | Polygon2D extrusion operations |
| STL export | Complete | Binary + ASCII export |
| 3MF export | Complete | XML-based 3MF generation |
| Metal renderer | Complete | Phong shading + edge overlay + background gradient |
| Orbit camera | Complete | Pan, zoom, rotate with gesture recognition |
| MetalViewport | Complete | SwiftUI UIViewRepresentable with gestures |
| App shell UI | Complete | ContentView, ToolbarView, FeatureTreeView, AddPrimitiveSheet, ExportSheet |
| ModelViewModel | Stubbed | Feature list CRUD exists but produces no geometry |
| GeometryKernel tests | Complete | Primitives, CSG, extrude, transform, export tests |
| App ViewModel tests | Complete | Add, delete, suppress, rename, move tests |
| Maestro E2E flows | Complete | Launch, add cube/cylinder, export, feature tree, undo/redo flows |

### Missing (This Phase Delivers)

| Area | Status | Details |
|------|--------|---------|
| ParametricEngine package | Not started | Feature types, evaluator, the brain of the app |
| Feature -> geometry pipeline | Not started | Features added in UI produce no mesh today |
| Parameter editing UI | Not started | No property inspector for feature parameters |
| Face/edge selection | Not started | No picking / hit testing |
| Undo/redo | Stubbed | Empty methods in ModelViewModel |
| STEP read/write | Not started | No file I/O for native format |
| Document integration | Not started | No save/load/file browser |

---

## Milestone 1.1: ParametricEngine Package + Feature Types

### Goal
Create the ParametricEngine Swift package with Feature types that can be evaluated into GeometryOp trees for the kernel to process.

### What to Build

**New package:** `ParametricEngine/`

```
ParametricEngine/
  Package.swift
  Sources/ParametricEngine/
    Feature.swift              -- Feature protocol + FeatureID
    FeatureTree.swift           -- Ordered feature list container
    Features/
      PrimitiveFeature.swift    -- Box, Cylinder, Sphere creation
      BooleanFeature.swift      -- Union, Difference, Intersection
      TransformFeature.swift    -- Translate, Rotate, Scale, Mirror
    Evaluator/
      FeatureEvaluator.swift    -- Feature[] -> GeometryOp tree
    Serialization/
      FeatureCodable.swift      -- Codable conformance for JSON round-trip
  Tests/ParametricEngineTests/
    FeatureTests.swift
    FeatureTreeTests.swift
    EvaluatorTests.swift
    SerializationTests.swift
```

### Key Design Decisions

**Feature identity:** Each Feature gets a stable UUID (`FeatureID = UUID`). This survives reorder, undo, and serialization. The feature tree is an ordered array of `Feature` values keyed by `FeatureID`.

**Feature protocol:**
```swift
public protocol Feature: Identifiable, Codable, Sendable {
    var id: FeatureID { get }
    var name: String { get set }
    var isSuppressed: Bool { get set }
    var featureType: String { get }  // "box", "cylinder", "union", etc.
}
```

**Concrete feature types:**
- `PrimitiveFeature` — type (box/cylinder/sphere), parameters (dimensions, center flag, segment count)
- `BooleanFeature` — type (union/difference/intersection), operand feature IDs (tool bodies)
- `TransformFeature` — type (translate/rotate/scale/mirror), parameters (vector, angle, axis), target feature ID

**FeatureTree:**
- Wraps `[any Feature]` with ordered-list semantics
- Insert, remove, move, suppress, lookup by ID
- Provides the feature list for evaluation

**FeatureEvaluator:**
- Takes a `FeatureTree`, walks it top-to-bottom
- Converts each non-suppressed Feature into a `GeometryOp` node
- Produces a final `GeometryOp` tree (typically a `.group` or nested booleans)
- Handles references between features (boolean operands, transform targets)

**Evaluation model — accumulator pattern:**
- Start with an empty result
- Each primitive feature adds a new body to the scene
- Boolean features combine the current accumulated result with a target body
- Transform features wrap a target body's geometry
- Result: a `GeometryOp` tree that GeometryKernel evaluates to `TriangleMesh`

**Serialization:**
- All Feature types conform to `Codable`
- `FeatureTree` encodes to/from JSON (this is what goes in the STEP `@openioscad` comment block)
- Use a `type` discriminator field for polymorphic decoding

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParametricEngine",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ParametricEngine", targets: ["ParametricEngine"]),
    ],
    dependencies: [
        .package(path: "../GeometryKernel"),
    ],
    targets: [
        .target(name: "ParametricEngine", dependencies: ["GeometryKernel"]),
        .testTarget(name: "ParametricEngineTests", dependencies: ["ParametricEngine"]),
    ]
)
```

ParametricEngine depends on GeometryKernel (for `GeometryOp`, `PrimitiveParams`, etc.) but NOT on Renderer or UI. This is the `Feature[] -> GeometryOp` bridge.

### Acceptance Criteria
- [ ] `ParametricEngine` package compiles and passes `swift test`
- [ ] Can create a `FeatureTree` with Box + Cylinder + Boolean(difference)
- [ ] `FeatureEvaluator` produces a valid `GeometryOp` tree from that feature list
- [ ] `GeometryKernel` evaluates that tree to a non-empty `TriangleMesh`
- [ ] Features round-trip through JSON encode/decode without data loss
- [ ] Suppressed features are skipped during evaluation
- [ ] Feature reorder changes evaluation order and produces different geometry

### Dependencies
- GeometryKernel (existing, no changes needed)

---

## Milestone 1.2: Wire Engine into App (Feature Evaluation Pipeline)

### Goal
Connect ParametricEngine to ModelViewModel so that every feature list change produces visible geometry in the viewport.

### What to Build

**Modify:** `ModelViewModel.swift` — Replace stub implementations with real ParametricEngine calls.

**Modify:** `project.yml` — Add ParametricEngine as a dependency of the app target.

### Changes

1. **ModelViewModel gains a `FeatureTree` and `FeatureEvaluator`** instead of the current `[FeatureItem]` array.

2. **`addPrimitive()` flow becomes:**
   ```
   User taps "Cube" -> ModelViewModel creates PrimitiveFeature(type: .box, ...)
   -> appends to FeatureTree -> calls evaluate() -> GeometryKernel.evaluate(opTree)
   -> updates currentMesh -> Renderer displays it
   ```

3. **`addBooleanOp()` flow becomes:**
   ```
   User taps "Difference" -> ModelViewModel creates BooleanFeature(type: .difference, operands: [...])
   -> appends to FeatureTree -> re-evaluate -> update mesh
   ```

4. **Every mutation** (add, delete, suppress, move, rename) triggers re-evaluation from the modified point forward. Initially, full re-evaluation is fine. Incremental re-eval is an optimization for later.

5. **`features` published property** becomes a derived view of `FeatureTree` for the UI — essentially mapping `Feature` values to the display model the `FeatureTreeView` consumes.

6. **Remove `FeatureItem` struct** — replace with a view model mapping from actual `Feature` types.

### Acceptance Criteria
- [ ] Adding a Box primitive shows a rendered cube in the viewport
- [ ] Adding a Cylinder shows a rendered cylinder
- [ ] Adding a Sphere shows a rendered sphere
- [ ] Adding a Boolean Difference after two primitives produces CSG geometry
- [ ] Suppressing a feature re-evaluates and updates the viewport
- [ ] Deleting a feature re-evaluates and updates the viewport
- [ ] Reordering features changes the evaluation result and updates the viewport
- [ ] Existing Maestro E2E tests still pass (or are updated for new behavior)

### Dependencies
- Milestone 1.1 (ParametricEngine package)

---

## Milestone 1.3: Parameter Editing

### Goal
User can tap a feature in the tree, see its parameters in a property inspector, edit values, and see the model update live.

### What to Build

**New:** `OpeniOSCAD/Views/PropertyInspectorView.swift` — Side panel or sheet showing editable parameters for the selected feature.

**Modify:** `ContentView.swift` — Add property inspector presentation (sheet or inline panel).

**Modify:** `ModelViewModel.swift` — Add `updateFeatureParameters()` method that mutates a feature's params and triggers re-evaluation.

### Design

**Property inspector layout per feature type:**

| Feature Type | Editable Parameters |
|-------------|-------------------|
| Box | Width, Height, Depth, Centered (toggle) |
| Cylinder | Radius (top), Radius (bottom), Height, Centered (toggle), Segments |
| Sphere | Radius, Segments |
| Boolean | Type picker (union/difference/intersection), Operand selection |
| Transform | Type, Vector (x/y/z), Angle, Axis |

**Interaction:**
- Tap a feature row in the tree -> selected feature highlighted, property inspector appears
- Edit a numeric field -> on commit (or debounced), ModelViewModel updates the feature and re-evaluates
- Changes are immediately visible in the viewport
- Each parameter field has `.accessibilityIdentifier()` for Maestro testing

**Implementation approach:**
- Use SwiftUI `Form` with `Section` groups per parameter category
- Numeric inputs via `TextField` with `NumberFormatter` or custom stepper controls
- Toggle for boolean params (centered, etc.)
- Picker for enum params (boolean type, transform type)

### Acceptance Criteria
- [ ] Tapping a feature in the tree shows its parameters
- [ ] Editing Box width updates the rendered geometry
- [ ] Editing Cylinder radius updates the rendered geometry
- [ ] Editing Sphere radius updates the rendered geometry
- [ ] Boolean type can be changed (union <-> difference <-> intersection)
- [ ] Transform vector values can be edited
- [ ] All parameter fields have accessibility identifiers
- [ ] Dismissing the inspector deselects the feature

### Dependencies
- Milestone 1.2 (working evaluation pipeline)

---

## Milestone 1.4: Face/Edge Selection

### Goal
User can tap on rendered geometry to select individual faces or edges. Selection is highlighted visually. This is the foundation for contextual operations in Phase 2 (tap face -> extrude, tap edge -> fillet).

### What to Build

**New:** `Renderer/Sources/Renderer/Picking.swift` — Hit testing via GPU color-ID rendering or CPU ray casting.

**Modify:** `RenderPipeline.swift` — Add selection highlight rendering pass.

**Modify:** `TriangleMesh.swift` — Add face ID tracking (which triangles belong to which logical face).

**Modify:** `MetalViewport.swift` — Add tap gesture for picking.

**Modify:** `ModelViewModel.swift` — Add selection state (selected face IDs, selected edge IDs).

### Approach: GPU Color-ID Picking

This is more reliable and performant than CPU ray casting for complex meshes:

1. **Off-screen render pass** renders each triangle with a unique color encoding its face ID (R,G,B channels encode a 24-bit triangle/face index).
2. **On tap**, read the pixel at the tap point from the off-screen texture.
3. **Decode** the color back to a face/triangle index.
4. **Map** triangle index to logical face (group of coplanar adjacent triangles sharing a normal — computed at tessellation time).

**Face grouping** — GeometryKernel already produces flat-shaded meshes where coplanar triangles share the same normal. Group triangles by normal direction + position to identify logical faces. Store face group IDs alongside the mesh.

**Edge detection** — Edges are boundaries between face groups. Identify edges as the set of vertex pairs shared between triangles belonging to different face groups.

**Selection highlight:**
- Selected faces: render with a distinct color (e.g., blue tint) or emissive overlay
- Selected edges: render as thicker wireframe lines in highlight color
- Add a new render pass or modify the fragment shader uniform to include per-face selection state

### Acceptance Criteria
- [ ] Tapping on a face highlights it visually
- [ ] Tapping on an edge highlights it visually
- [ ] Tapping empty space deselects
- [ ] Selection state is exposed to ModelViewModel
- [ ] Multiple taps on different faces change the selection
- [ ] Selection survives camera orbit/pan (selection is in model space, not screen space)
- [ ] Works on all three primitive types (box, cylinder, sphere)

### Dependencies
- Milestone 1.2 (geometry must be visible to tap on it)

---

## Milestone 1.5: Undo/Redo

### Goal
Full undo/redo for all feature tree operations using feature list snapshots.

### What to Build

**New:** `ParametricEngine/Sources/ParametricEngine/UndoStack.swift` — Snapshot-based undo stack operating on `FeatureTree`.

**Modify:** `ModelViewModel.swift` — Wire undo/redo to the snapshot stack, update `canUndo`/`canRedo` flags.

### Design

**Snapshot approach** (simple, correct, works for <50 features per performance targets):

```swift
public final class UndoStack {
    private var snapshots: [FeatureTree] = []
    private var currentIndex: Int = -1

    func push(_ tree: FeatureTree)    // Save snapshot after every mutation
    func undo() -> FeatureTree?       // Move back, return previous state
    func redo() -> FeatureTree?       // Move forward, return next state
    var canUndo: Bool
    var canRedo: Bool
}
```

**Every feature mutation** (add, delete, suppress, move, rename, parameter edit) pushes a snapshot. Pushing clears any redo states beyond the current index.

**ModelViewModel integration:**
- Before every mutation, push the current state
- `undo()` pops to previous snapshot, replaces FeatureTree, re-evaluates
- `redo()` moves forward, replaces FeatureTree, re-evaluates
- `canUndo` / `canRedo` drive toolbar button state

**Memory:** Feature trees are small (structs + value types). At 50 features per snapshot and 100 undo levels, memory is negligible (<1MB). No need for command pattern or diff-based undo at this stage.

### Acceptance Criteria
- [ ] Adding a primitive then pressing undo removes it (geometry disappears)
- [ ] Pressing redo after undo restores it (geometry reappears)
- [ ] Deleting a feature then undoing restores it
- [ ] Suppress + undo restores unsuppressed state
- [ ] Parameter edit + undo restores old parameter value
- [ ] Multiple sequential undos work correctly
- [ ] Redo stack is cleared when a new mutation occurs after undo
- [ ] `canUndo`/`canRedo` correctly reflect availability
- [ ] Toolbar undo/redo buttons enable/disable appropriately

### Dependencies
- Milestone 1.2 (need working evaluation to verify undo produces correct geometry)
- Milestone 1.3 (parameter edits should be undoable)

---

## Milestone 1.6: STEP Read/Write

### Goal
Save the model as a valid STEP AP214 file with the `@openioscad` feature history comment block. Load it back, reconstruct the full feature tree, and resume editing.

### What to Build

**New:** `GeometryKernel/Sources/GeometryKernel/STEP/STEPWriter.swift` — Write STEP AP214 entities from TriangleMesh.

**New:** `GeometryKernel/Sources/GeometryKernel/STEP/STEPReader.swift` — Parse STEP AP214 entities into TriangleMesh.

**New:** `GeometryKernel/Sources/GeometryKernel/STEP/STEPDocument.swift` — Top-level STEP file structure (header, data section, comment block).

**New:** `ParametricEngine/Sources/ParametricEngine/Serialization/HistoryComment.swift` — Encode/decode `@openioscad` JSON block to/from STEP comment string.

**New tests:** `GeometryKernel/Tests/GeometryKernelTests/STEPTests.swift`

### STEP File Format

Per VISION.md, the output looks like:

```
ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('OpeniOSCAD model'),'2;1');
FILE_NAME('model.step','2026-01-01T00:00:00',(''),(''),'',' ','');
FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));
ENDSEC;
DATA;
/* @openioscad {"version":1,"features":[...feature tree JSON...]} */
#1=CARTESIAN_POINT('',(0.,0.,0.));
...geometry entities...
ENDSEC;
END-ISO-10303-21;
```

### STEP Write Strategy (Tessellated Geometry)

For Phase 1, write the tessellated mesh as STEP entities. This produces universally-readable geometry:

- Each vertex -> `CARTESIAN_POINT`
- Each triangle -> `FACE_OUTER_BOUND` -> `FACE_BOUND` -> `ADVANCED_FACE`
- Or more practically: use the **tessellated geometry** representation from AP242 (`TRIANGULATED_FACE` / `TESSELLATED_SOLID`) which is simpler to generate

The exact BREP representation (true surfaces, curves, topology) comes in Phase 4. Tessellated output is valid STEP and importable by all major CAD tools.

### STEP Read Strategy

1. Parse the `@openioscad` comment block if present -> reconstruct FeatureTree -> full parametric editing
2. If no comment block (external STEP file): parse geometry entities -> import as a single solid body TriangleMesh -> user can add new features on top

### Acceptance Criteria
- [ ] Save produces a valid STEP file that opens in FreeCAD/PrusaSlicer
- [ ] The `@openioscad` comment block contains correct JSON
- [ ] Loading our own STEP file reconstructs the full feature tree
- [ ] All feature types survive save/load round-trip
- [ ] Loading an external STEP file (no comment block) imports geometry as a body
- [ ] File size is reasonable (<1MB for simple models)

### Dependencies
- Milestone 1.1 (FeatureTree serialization)
- Milestone 1.2 (need geometry to write)

---

## Milestone 1.7: Document Integration

### Goal
Integrate with iOS file management so users can create, save, open, and manage STEP files through the standard iOS document experience.

### What to Build

**New:** `OpeniOSCAD/Document/STEPDocument.swift` — `FileDocument` or `ReferenceFileDocument` conformance for SwiftUI document-based app.

**Modify:** `OpeniOSCADApp.swift` — Switch to `DocumentGroup` scene (or add document open/save to existing `WindowGroup`).

**Modify:** `ModelViewModel.swift` — Integrate with document lifecycle (save triggers STEP write, open triggers STEP read + feature tree reconstruction).

**Modify:** `ContentView.swift` — Add save/open buttons or integrate with system document browser.

**Modify:** `project.yml` — Ensure document type declarations are correct for STEP files.

### Design

**SwiftUI `ReferenceFileDocument` approach:**
- The document holds a reference to the `FeatureTree` + current `TriangleMesh`
- On save: serialize FeatureTree to JSON, write STEP file with geometry + comment block
- On open: parse STEP file, extract comment block, reconstruct FeatureTree, evaluate to mesh
- `UndoManager` integration for free undo/redo tracking via the document (may replace or complement Milestone 1.5's custom stack)

**File type registration:**
- UTType: `com.openioscad.step` conforming to `public.data`
- File extension: `.step`
- The app appears as an option when opening `.step` files in Files app

### Acceptance Criteria
- [ ] New document creates an empty model
- [ ] Save writes a `.step` file to the chosen location
- [ ] Open reads a `.step` file and shows the model
- [ ] Reopening a saved file restores the full feature tree (not just geometry)
- [ ] Files app integration works (browse, open, rename, delete)
- [ ] Share sheet can share the STEP file
- [ ] External STEP files can be opened (imported as geometry body)

### Dependencies
- Milestone 1.6 (STEP read/write)
- Milestone 1.5 (undo/redo, potentially via UndoManager)

---

## Milestone Dependency Graph

```
1.1 ParametricEngine
 |
 v
1.2 Wire Engine -> App
 |        \            \
 v         v            v
1.3 Params  1.4 Picking  1.5 Undo/Redo
 |                          |
 v                          v
1.6 STEP Read/Write --------+
 |
 v
1.7 Document Integration
```

Milestones 1.3, 1.4, and 1.5 can proceed in parallel once 1.2 is done. 1.6 needs 1.1 and 1.2. 1.7 is the final integration milestone.

---

## Files Created / Modified Summary

### New Files

| File | Package | Milestone |
|------|---------|-----------|
| `ParametricEngine/Package.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/ParametricEngine/Feature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/ParametricEngine/FeatureTree.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/ParametricEngine/Features/PrimitiveFeature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/ParametricEngine/Features/BooleanFeature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/ParametricEngine/Features/TransformFeature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/ParametricEngine/Evaluator/FeatureEvaluator.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/ParametricEngine/Serialization/FeatureCodable.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Tests/ParametricEngineTests/FeatureTests.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Tests/ParametricEngineTests/FeatureTreeTests.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Tests/ParametricEngineTests/EvaluatorTests.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Tests/ParametricEngineTests/SerializationTests.swift` | ParametricEngine | 1.1 |
| `OpeniOSCAD/Views/PropertyInspectorView.swift` | App | 1.3 |
| `Renderer/Sources/Renderer/Picking.swift` | Renderer | 1.4 |
| `ParametricEngine/Sources/ParametricEngine/UndoStack.swift` | ParametricEngine | 1.5 |
| `GeometryKernel/Sources/GeometryKernel/STEP/STEPWriter.swift` | GeometryKernel | 1.6 |
| `GeometryKernel/Sources/GeometryKernel/STEP/STEPReader.swift` | GeometryKernel | 1.6 |
| `GeometryKernel/Sources/GeometryKernel/STEP/STEPDocument.swift` | GeometryKernel | 1.6 |
| `ParametricEngine/Sources/ParametricEngine/Serialization/HistoryComment.swift` | ParametricEngine | 1.6 |
| `GeometryKernel/Tests/GeometryKernelTests/STEPTests.swift` | GeometryKernel | 1.6 |
| `OpeniOSCAD/Document/STEPDocument.swift` | App | 1.7 |

### Modified Files

| File | Milestone | Changes |
|------|-----------|---------|
| `project.yml` | 1.2 | Add ParametricEngine dependency |
| `ModelViewModel.swift` | 1.2, 1.3, 1.4, 1.5, 1.7 | Replace stubs with real engine calls |
| `ContentView.swift` | 1.3, 1.7 | Add property inspector, document integration |
| `OpeniOSCADApp.swift` | 1.7 | Document-based app scene |
| `RenderPipeline.swift` | 1.4 | Selection highlight pass |
| `MetalViewport.swift` | 1.4 | Tap gesture for picking |
| `TriangleMesh.swift` | 1.4 | Face ID tracking |
| `ModelShaders.metal` | 1.4 | Selection highlight in fragment shader |

---

## Testing Strategy

### Unit Tests (per milestone)

| Milestone | Test File | What It Covers |
|-----------|-----------|----------------|
| 1.1 | `ParametricEngineTests/FeatureTests.swift` | Feature creation, properties, identity |
| 1.1 | `ParametricEngineTests/FeatureTreeTests.swift` | Insert, remove, move, suppress, lookup |
| 1.1 | `ParametricEngineTests/EvaluatorTests.swift` | Feature list -> GeometryOp tree correctness |
| 1.1 | `ParametricEngineTests/SerializationTests.swift` | JSON round-trip for all feature types |
| 1.3 | `OpeniOSCADTests/ParameterEditTests.swift` | Parameter mutation triggers re-eval |
| 1.5 | `ParametricEngineTests/UndoStackTests.swift` | Push/undo/redo/clear correctness |
| 1.6 | `GeometryKernelTests/STEPTests.swift` | STEP write validity, read/write round-trip |

### E2E Tests (Maestro)

| Milestone | Flow | What It Tests |
|-----------|------|---------------|
| 1.2 | `10_add_primitive_renders.yaml` | Add cube -> viewport shows geometry |
| 1.3 | `11_edit_parameters.yaml` | Tap feature -> edit width -> geometry changes |
| 1.4 | `12_face_selection.yaml` | Tap on geometry -> face highlights |
| 1.5 | `13_undo_redo_works.yaml` | Add -> undo -> geometry gone -> redo -> back |
| 1.7 | `14_save_load.yaml` | Save file -> close -> reopen -> features intact |

---

## Performance Targets (from CLAUDE.md)

These must be met by the end of Phase 1:

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Add feature + re-eval (<10 features) | <50ms on iPhone 15 | Instrument `evaluate()` call duration |
| Full rebuild (<50 features) | <500ms on iPhone 15 | Instrument full re-eval with 50 primitives+booleans |
| Display render | 60fps for <100K triangles | Metal GPU profiler, frame time <16.6ms |
| STL export | <1s for 100K triangles | Time `exportSTL()` for a complex model |
| STEP save/load | <200ms | Time STEP write + read for a 50-feature model |

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| BSP-tree booleans produce artifacts on complex geometry | Incorrect CSG results visible to user | Track known failure cases; Phase 4 replaces with Manifold C++ bridge for exact booleans |
| STEP tessellated output not accepted by some CAD tools | Interop failure | Test against FreeCAD, PrusaSlicer, Fusion 360 import; fall back to STL entity encoding if needed |
| GPU color-ID picking unreliable on some Metal devices | Selection misses | Implement CPU ray-cast fallback; test on A15+ devices |
| Feature evaluation too slow for >10 features | Exceeds 50ms target | Profile early; implement incremental re-eval (only re-evaluate from modified feature forward) |

---

## Definition of Done (Phase 1 Complete)

- [ ] All 7 milestones delivered and tested
- [ ] User can add Box, Cylinder, Sphere primitives and see them rendered
- [ ] User can apply Boolean union/difference/intersection between bodies
- [ ] User can apply Translate/Rotate/Scale/Mirror transforms
- [ ] User can tap a feature to edit its parameters with live preview
- [ ] User can tap geometry to select faces and edges
- [ ] Undo/redo works for all operations
- [ ] Save produces a valid STEP file with `@openioscad` history
- [ ] Load reconstructs the full feature tree from a saved STEP file
- [ ] External STEP files open as imported geometry
- [ ] STL and 3MF export works
- [ ] All unit tests pass
- [ ] All Maestro E2E tests pass
- [ ] Performance targets met on iPhone 15

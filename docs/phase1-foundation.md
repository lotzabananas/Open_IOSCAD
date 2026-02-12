# Phase 1: Foundation

## Goal

Users can create 3D geometry through sketch-based modeling: draw 2D shapes on a plane, extrude or cut to produce solids. Convenience commands provide one-tap creation of common shapes (box, cylinder). Users can edit sketch and extrude parameters, select faces and edges, undo/redo all operations, save/load as STEP with full parametric history, and export STL/3MF.

This phase establishes the correct parametric CAD data model from day one: **every 3D feature references a 2D sketch.** The feature tree reads like real MCAD: Sketch → Extrude, Sketch → Cut. No standalone "primitive features."

---

## Why Sketch-First

In every successful parametric MCAD system (SolidWorks, Fusion 360, FreeCAD Part Design, Onshape), the sketch is the atomic unit of modeling. A box is a rectangle sketch + extrude. A cylinder is a circle sketch + extrude. There are no "box features."

Building around primitives would create a data model that doesn't match real CAD. When sketch-based features arrive later, we'd have two parallel creation paths (primitives AND sketch→extrude), two evaluation codepaths, and primitive features that become dead weight or require migration. Instead, we build the correct data model from day one.

**Convenience commands ("Add Box", "Add Cylinder") create sketch + extrude features behind the scenes.** The user experience for quick shape creation is the same — the architecture underneath is right.

**The constraint solver is NOT in Phase 1.** Sketches are fully dimensioned: every element has explicit coordinates and sizes. The data model has a slot for constraints (empty array) that grows into a full 2D solver in a later phase. This is how FreeCAD's Sketcher evolved — basic positioned elements first, constraints added incrementally.

---

## How This Maps to Existing Code

GeometryKernel already has the complete extrusion pipeline:

- `Polygon2D` — ordered 2D points forming a closed profile
- `LinearExtrudeOperation.extrude(polygon:params:)` — extrudes Polygon2D to TriangleMesh
- `GeometryOp.extrude(.linear, params, child)` — extrude node in the operation tree
- `extractPolygon(from:)` — converts `.primitive(.polygon, ...)` to Polygon2D
- `CSGOperations.perform(.difference, meshes)` — boolean subtraction for cuts

The FeatureEvaluator's job is straightforward:
1. **SketchFeature** → convert elements to Polygon2D points → wrap as `.primitive(.polygon, params)`
2. **ExtrudeFeature (additive)** → `.extrude(.linear, ExtrudeParams(height: depth), sketchOp)` → union with accumulated geometry
3. **ExtrudeFeature (subtractive/cut)** → same extrude → `.boolean(.difference, [accumulated, extruded])`

**Almost no GeometryKernel changes are needed.** The new code is primarily the FeatureEvaluator and the sketch data model in ParametricEngine.

---

## Current State Assessment

### Done

| Area | Status | Details |
|------|--------|---------|
| Polygon2D extrusion | Complete | LinearExtrudeOperation, RotateExtrudeOperation |
| Boolean operations | Complete | BSP-tree CSG: union, difference, intersection |
| All transforms | Complete | Translate, rotate, scale, mirror + winding flip |
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
| ParametricEngine package | Not started | Sketch-based feature types, evaluator |
| Feature → geometry pipeline | Not started | Features added in UI produce no mesh today |
| Sketch mode UI | Not started | No 2D canvas for freehand sketch drawing |
| Parameter editing UI | Not started | No property inspector for feature parameters |
| Face/edge selection | Not started | No picking / hit testing |
| Undo/redo | Stubbed | Empty methods in ModelViewModel |
| STEP read/write | Not started | No file I/O for native format |
| Document integration | Not started | No save/load/file browser |

---

## Feature Types

### SketchFeature

A 2D sketch on a plane or face. Contains positioned geometric elements and (in Phase 1, empty) constraints.

```swift
struct SketchFeature: Feature {
    let id: FeatureID
    var name: String
    var isSuppressed: Bool
    var plane: SketchPlane
    var elements: [SketchElement]
    var constraints: [SketchConstraint]  // Empty in Phase 1
}
```

**SketchPlane** — where the sketch lives:
```swift
enum SketchPlane: Codable {
    case xy    // Global XY plane (default for first sketch)
    case xz    // Global XZ plane
    case yz    // Global YZ plane
    case offsetXY(distance: Double)  // Parallel to XY at distance
    case faceOf(featureID: FeatureID, faceIndex: Int)  // On an existing face
}
```

**SketchElement** — 2D geometry in the sketch's local coordinate system:
```swift
enum SketchElement: Identifiable, Codable {
    case rectangle(id: ElementID, origin: Point2D, width: Double, height: Double)
    case circle(id: ElementID, center: Point2D, radius: Double)
    case lineSegment(id: ElementID, start: Point2D, end: Point2D)
}
```

Phase 1 uses compound elements (rectangle, circle) for simplicity. When the constraint solver arrives in a later phase, a "rectangle tool" can create 4 constrained line segments instead. Compound elements remain valid alongside primitive elements — the enum grows, nothing breaks.

**Profile extraction** converts SketchElements to `Polygon2D`:
- Rectangle → 4 corner points
- Circle → N-point polygon approximation (reuses GeometryKernel's segment resolution logic)
- Connected line segments → validate closure, extract ordered points

### ExtrudeFeature

Extrudes a sketch profile into 3D. Can add material (boss/pad) or subtract it (cut/pocket).

```swift
struct ExtrudeFeature: Feature {
    let id: FeatureID
    var name: String
    var isSuppressed: Bool
    var sketchID: FeatureID       // Reference to the source sketch
    var depth: Double             // Extrusion distance
    var operation: Operation      // .additive or .subtractive

    enum Operation: Codable {
        case additive    // Union with existing geometry (boss/pad)
        case subtractive // Subtract from existing geometry (cut/pocket)
    }
}
```

The evaluator converts this to:
- Additive: `.extrude(.linear, params, sketchPolygonOp)` → union with accumulated
- Subtractive: `.extrude(.linear, params, sketchPolygonOp)` → `.boolean(.difference, [accumulated, extruded])`

### BooleanFeature

Combines separate bodies. Same as the original plan.

```swift
struct BooleanFeature: Feature {
    let id: FeatureID
    var name: String
    var isSuppressed: Bool
    var booleanType: BooleanType  // union, intersection
    var targetIDs: [FeatureID]    // Bodies to combine
}
```

### TransformFeature

Positions/orients geometry. Same as the original plan.

```swift
struct TransformFeature: Feature {
    let id: FeatureID
    var name: String
    var isSuppressed: Bool
    var transformType: TransformType  // translate, rotate, scale, mirror
    var params: TransformParams
    var targetID: FeatureID
}
```

---

## Convenience Commands

These are UI shortcuts that create the correct features behind the scenes. The user taps one button and enters dimensions; the app creates the full feature structure.

### "Add Box"

1. Creates `SketchFeature` on XY plane with a centered rectangle (width × height)
2. Creates `ExtrudeFeature` referencing that sketch (additive, depth)
3. Both appear in the feature tree as separate entries:
   ```
   ▸ Sketch 1 — Rectangle on XY
   ▸ Extrude 1 — 20mm
   ```
4. User can edit either independently

### "Add Cylinder"

1. Creates `SketchFeature` on XY plane with a centered circle (radius)
2. Creates `ExtrudeFeature` referencing that sketch (additive, height)
3. Feature tree:
   ```
   ▸ Sketch 1 — Circle on XY
   ▸ Extrude 1 — 30mm
   ```

### "Add Hole" (on selected face)

Requires face selection (milestone 1.4). After selecting a face:
1. Creates `SketchFeature` on the selected face with a circle
2. Creates `ExtrudeFeature` referencing that sketch (subtractive, depth)
3. Feature tree:
   ```
   ▸ Sketch 2 — Circle on Face 3 of Extrude 1
   ▸ Cut 1 — Through
   ```

---

## Milestones

### 1.1: ParametricEngine + Sketch-Based Feature Types

**Goal:** Create the ParametricEngine package with sketch-based features that produce geometry through the evaluation pipeline.

**New package:** `ParametricEngine/`

```
ParametricEngine/
  Package.swift
  Sources/ParametricEngine/
    Feature.swift                  -- Feature protocol + FeatureID
    FeatureTree.swift              -- Ordered feature list container
    Features/
      SketchFeature.swift          -- 2D sketch on a plane/face
      ExtrudeFeature.swift         -- Extrude sketch profile (add or cut)
      BooleanFeature.swift         -- Combine bodies
      TransformFeature.swift       -- Translate, Rotate, Scale, Mirror
    Sketch/
      SketchElement.swift          -- Rectangle, circle, line segment
      SketchPlane.swift            -- XY, XZ, YZ, face reference
      ProfileExtractor.swift       -- SketchElements → Polygon2D
    Evaluator/
      FeatureEvaluator.swift       -- FeatureTree → GeometryOp tree
    Serialization/
      FeatureCodable.swift         -- Codable wrappers for polymorphic decoding
  Tests/ParametricEngineTests/
    SketchFeatureTests.swift
    ExtrudeFeatureTests.swift
    FeatureTreeTests.swift
    ProfileExtractorTests.swift
    EvaluatorTests.swift
    SerializationTests.swift
```

**Key design:**

- **Feature identity:** Each Feature gets a stable UUID (`FeatureID`). Survives reorder, undo, serialization.
- **Feature protocol:** `Identifiable`, `Codable`, `Sendable`. Type discriminator field for polymorphic decoding.
- **FeatureTree:** Wraps `[any Feature]` with ordered-list semantics (insert, remove, move, suppress, lookup by ID).
- **ProfileExtractor:** Converts `[SketchElement]` → `Polygon2D`. For Phase 1 this handles rectangle (4 points), circle (N-point approximation), and closed line-segment chains.
- **FeatureEvaluator:** Walks the FeatureTree top-to-bottom. Sketches produce cached Profile2D/Polygon2D. Extrudes look up their referenced sketch, build `.extrude(.linear, ...)` GeometryOp, and union/subtract with the accumulated solid. Returns a final GeometryOp tree for GeometryKernel.

**Package.swift:**
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

**Acceptance criteria:**
- [ ] ParametricEngine compiles and passes `swift test`
- [ ] Can create SketchFeature(rectangle on XY) + ExtrudeFeature(additive, depth=20)
- [ ] FeatureEvaluator produces a valid GeometryOp tree from that feature pair
- [ ] GeometryKernel evaluates that tree to a non-empty TriangleMesh with correct dimensions
- [ ] Can create a subtractive ExtrudeFeature (cut) that produces boolean difference geometry
- [ ] ProfileExtractor correctly converts rectangle, circle, and closed line segments to Polygon2D
- [ ] All features round-trip through JSON encode/decode without data loss
- [ ] Suppressed features are skipped during evaluation
- [ ] Feature reorder changes evaluation order and produces different geometry

**Dependencies:** GeometryKernel (existing, no changes needed)

---

### 1.2: Wire Engine into App + Convenience Commands

**Goal:** Connect ParametricEngine to ModelViewModel. "Add Box" and "Add Cylinder" create sketch + extrude features and show rendered geometry in the viewport.

**Modify:** `ModelViewModel.swift` — Replace stub feature list with FeatureTree + FeatureEvaluator.

**Modify:** `AddPrimitiveSheet.swift` → `AddShapeSheet.swift` — Dimension input for convenience commands.

**Modify:** `FeatureTreeView.swift` — Display real Feature entries (Sketch, Extrude) instead of stub items.

**Modify:** `project.yml` — Add ParametricEngine dependency.

**Changes:**

1. **ModelViewModel gains `FeatureTree` and `FeatureEvaluator`**. The `features` published property becomes a derived view of the FeatureTree for the UI.

2. **"Add Box" flow:**
   ```
   User taps "Box" → dimension sheet (width, depth, height)
   → ModelViewModel creates SketchFeature(rectangle on XY, width×depth)
   → creates ExtrudeFeature(additive, height)
   → appends both to FeatureTree → evaluate → render
   ```

3. **"Add Cylinder" flow:**
   ```
   User taps "Cylinder" → dimension sheet (radius, height)
   → SketchFeature(circle on XY, radius) + ExtrudeFeature(additive, height)
   → append → evaluate → render
   ```

4. **Feature tree UI** shows the real structure: "Sketch 1 — Rectangle on XY" and "Extrude 1 — 20mm" as separate rows.

5. **Every mutation** (add, delete, suppress, move, rename) triggers full re-evaluation. Incremental re-eval is an optimization for later.

6. **Remove `FeatureItem` stub** and old primitive-based add flow.

**Acceptance criteria:**
- [ ] "Add Box" creates two features (Sketch + Extrude) and shows rendered geometry
- [ ] "Add Cylinder" creates two features and shows rendered geometry
- [ ] Feature tree shows Sketch and Extrude as separate entries
- [ ] Deleting a feature re-evaluates and updates the viewport
- [ ] Suppressing a feature re-evaluates and updates the viewport
- [ ] Reordering features changes the evaluation result
- [ ] Deleting an Extrude's referenced Sketch handles gracefully (error or auto-delete)
- [ ] Existing Maestro E2E tests updated and pass

**Dependencies:** Milestone 1.1

---

### 1.3: Parameter Editing

**Goal:** User taps a feature in the tree, sees its parameters in a property inspector, edits values, and sees the model update live.

**New:** `OpeniOSCAD/Views/PropertyInspectorView.swift`

**Modify:** `ContentView.swift` — Add property inspector presentation.

**Modify:** `ModelViewModel.swift` — Add `updateFeatureParameters()` method.

**Parameters per feature type:**

| Feature Type | Editable Parameters |
|-------------|-------------------|
| Sketch (rectangle) | Width, Height, Origin X, Origin Y |
| Sketch (circle) | Radius, Center X, Center Y |
| Extrude (additive) | Depth |
| Extrude (subtractive) | Depth |
| Boolean | Type picker (union/intersection) |
| Transform | Type, Vector (x/y/z), Angle, Axis |

**Interaction:**
- Tap a feature row → selected, property inspector appears
- Edit a numeric field → on commit, ModelViewModel updates the feature and re-evaluates
- Changes immediately visible in viewport
- Each parameter field has `.accessibilityIdentifier()` for Maestro testing

**Acceptance criteria:**
- [ ] Tapping a Sketch feature shows its element parameters
- [ ] Editing rectangle width updates the rendered geometry
- [ ] Editing circle radius updates the rendered geometry
- [ ] Editing extrude depth updates the rendered geometry
- [ ] All parameter fields have accessibility identifiers
- [ ] Dismissing the inspector deselects the feature

**Dependencies:** Milestone 1.2

---

### 1.4: Face/Edge Selection

**Goal:** User taps rendered geometry to select individual faces or edges. This is the foundation for "sketch on face" in milestone 1.6.

**New:** `Renderer/Sources/Renderer/Picking.swift`

**Modify:** `RenderPipeline.swift` — Selection highlight render pass.

**Modify:** `TriangleMesh.swift` — Face ID tracking.

**Modify:** `MetalViewport.swift` — Tap gesture for picking.

**Modify:** `ModelViewModel.swift` — Selection state.

**Approach: GPU color-ID picking:**
1. Off-screen render pass encodes face ID as pixel color (24-bit face index in RGB)
2. On tap, read pixel at tap point
3. Decode to face/triangle index
4. Map to logical face (group coplanar adjacent triangles by normal)

**Face grouping:** Group triangles by normal direction + plane offset to identify logical faces. Store face group IDs alongside the mesh.

**Edge detection:** Edges are boundaries between face groups. Identify as vertex pairs shared between triangles in different face groups.

**Selection highlight:** Selected faces rendered with blue tint overlay. Selected edges rendered as thicker wireframe.

**Acceptance criteria:**
- [ ] Tapping a face highlights it visually
- [ ] Tapping an edge highlights it visually
- [ ] Tapping empty space deselects
- [ ] Selection state exposed to ModelViewModel
- [ ] Selection survives camera orbit/pan
- [ ] Works on extruded rectangles and circles

**Dependencies:** Milestone 1.2

---

### 1.5: Undo/Redo

**Goal:** Full undo/redo for all feature tree operations using feature list snapshots.

**New:** `ParametricEngine/Sources/ParametricEngine/UndoStack.swift`

**Modify:** `ModelViewModel.swift` — Wire undo/redo to snapshot stack.

**Design: Snapshot approach** (simple, correct for <50 features):

```swift
public final class UndoStack {
    private var snapshots: [FeatureTree] = []
    private var currentIndex: Int = -1

    func push(_ tree: FeatureTree)
    func undo() -> FeatureTree?
    func redo() -> FeatureTree?
    var canUndo: Bool
    var canRedo: Bool
}
```

Every mutation pushes a snapshot. Undo/redo moves through snapshots and triggers re-evaluation. Pushing clears redo states beyond current index.

Memory: Feature trees are small value types. 50 features × 100 undo levels < 1MB. No command pattern needed.

**Acceptance criteria:**
- [ ] Adding features then undoing removes them (geometry disappears)
- [ ] Redo after undo restores features (geometry reappears)
- [ ] Parameter edits are undoable
- [ ] Suppress/unsuppress is undoable
- [ ] Multiple sequential undos work correctly
- [ ] Redo stack cleared when new mutation occurs after undo
- [ ] `canUndo`/`canRedo` drive toolbar button state

**Dependencies:** Milestone 1.2

---

### 1.6: Sketch Mode UI

**Goal:** Users can manually enter sketch mode on a plane or face, draw 2D geometry with touch, and create 3D features from their sketches.

This is the transition from convenience-command-only creation to real sketch-based CAD interaction.

**New:** `OpeniOSCAD/Views/SketchCanvasView.swift` — 2D drawing overlay.

**New:** `OpeniOSCAD/Views/SketchToolbar.swift` — Drawing tool palette.

**New:** `OpeniOSCAD/ViewModels/SketchViewModel.swift` — Sketch mode state management.

**Modify:** `MetalViewport.swift` — Orthographic camera mode for sketch plane.

**Modify:** `ContentView.swift` — Sketch mode entry/exit, tool palette display.

**Sketch mode entry:**
- Tap "New Sketch" button → choose construction plane (XY, XZ, YZ)
- Or: select a face (requires 1.4) → tap "Sketch on Face"

**Sketch mode interaction:**
- Camera snaps to orthographic view aligned with the sketch plane
- Grid overlay on the sketch plane
- Drawing tool palette appears: Rectangle, Circle, Line
- Tap to place element center, drag to size — or tap to place and enter dimensions numerically
- Elements render as 2D wireframe on the plane
- "Finish Sketch" confirms and creates the SketchFeature
- "Cancel Sketch" discards without modifying the feature tree

**After finishing sketch:**
- Prompt for operation: Extrude (enter depth) or Cut (enter depth)
- Creates ExtrudeFeature referencing the new sketch
- Camera returns to perspective view
- New features appear in the tree

**Design decisions:**
- Sketch mode is modal: 3D orbit/pan gestures are disabled, touch maps to 2D coordinates in the sketch plane's local frame
- The canvas is the Metal viewport with camera locked orthographic
- Touch coordinates are unprojected to the sketch plane for element placement
- Elements snap to grid intersections for easy alignment (grid spacing adjustable)

**Acceptance criteria:**
- [ ] User can enter sketch mode on XY plane
- [ ] User can draw a rectangle in sketch mode
- [ ] User can draw a circle in sketch mode
- [ ] User can draw line segments in sketch mode
- [ ] Grid overlay is visible and elements snap to it
- [ ] "Finish Sketch" creates a SketchFeature in the tree
- [ ] User is prompted for extrude/cut depth after finishing sketch
- [ ] Resulting geometry appears in the viewport
- [ ] User can sketch on a selected face
- [ ] Cancel discards without modifying feature tree
- [ ] Camera returns to perspective after exiting sketch mode

**Dependencies:** Milestones 1.2, 1.4 (for sketch-on-face; construction planes work without 1.4)

---

### 1.7: STEP Read/Write + Document Integration

**Goal:** Save the model as valid STEP AP214 with `@openioscad` feature history. Load it back with full editing capability. Integrate with iOS file management.

**New:** `GeometryKernel/Sources/GeometryKernel/STEP/STEPWriter.swift`

**New:** `GeometryKernel/Sources/GeometryKernel/STEP/STEPReader.swift`

**New:** `GeometryKernel/Sources/GeometryKernel/STEP/STEPDocument.swift`

**New:** `ParametricEngine/Sources/ParametricEngine/Serialization/HistoryComment.swift`

**New:** `OpeniOSCAD/Document/STEPDocument.swift`

**New tests:** `GeometryKernelTests/STEPTests.swift`

**Modify:** `OpeniOSCADApp.swift` — DocumentGroup scene.

**Modify:** `ModelViewModel.swift` — Document lifecycle integration.

### STEP Write

Phase 1 writes tessellated geometry as STEP entities (universally readable). The `@openioscad` comment block contains the sketch-based feature tree as JSON:

```
ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('OpeniOSCAD model'),'2;1');
FILE_NAME('model.step','2026-01-01T00:00:00',(''),(''),'',' ','');
FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));
ENDSEC;
DATA;
/* @openioscad {"version":1,"features":[
  {"type":"sketch","id":"...","plane":"xy","elements":[{"type":"rectangle",...}]},
  {"type":"extrude","id":"...","sketchID":"...","depth":20,"operation":"additive"}
]} */
#1=CARTESIAN_POINT('',(0.,0.,0.));
...geometry entities...
ENDSEC;
END-ISO-10303-21;
```

### STEP Read

1. If `@openioscad` comment block present → parse JSON → reconstruct FeatureTree → full parametric editing
2. If no comment block (external STEP file) → parse geometry entities → import as single body TriangleMesh → user can add new features on top

### Document Integration

- `ReferenceFileDocument` conformance for SwiftUI document-based app
- `DocumentGroup` scene for open/save workflow
- UTType `com.openioscad.step` conforming to `public.data`
- Files app integration (browse, open, rename, share)
- `UndoManager` integration (may complement or replace milestone 1.5's custom stack)

**Acceptance criteria:**
- [ ] Save produces a valid STEP file that opens in FreeCAD/PrusaSlicer
- [ ] The `@openioscad` comment block contains correct sketch-based feature JSON
- [ ] Loading our own STEP file reconstructs the full feature tree with Sketch + Extrude features
- [ ] All feature types survive save/load round-trip
- [ ] Loading an external STEP file imports geometry as a body
- [ ] New document creates an empty model
- [ ] Files app integration works (browse, open, save, share)
- [ ] File size reasonable (<1MB for simple models)

**Dependencies:** Milestones 1.1, 1.2, 1.5

---

## Milestone Dependency Graph

```
1.1 ParametricEngine + Sketch Feature Types
 │
 v
1.2 Wire Engine + Convenience Commands
 │         \              \
 v          v              v
1.3 Params  1.4 Selection  1.5 Undo/Redo
                \
                 v
              1.6 Sketch Mode UI
                     │
                     v
              1.7 STEP I/O + Documents
```

1.3, 1.4, and 1.5 can proceed in parallel once 1.2 is done. 1.6 (sketch mode UI) needs 1.4 for sketch-on-face, but can start with construction-plane-only sketching once 1.2 is done. 1.7 is the final integration milestone.

---

## Files Created / Modified Summary

### New Files

| File | Package | Milestone |
|------|---------|-----------|
| `ParametricEngine/Package.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Feature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../FeatureTree.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Features/SketchFeature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Features/ExtrudeFeature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Features/BooleanFeature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Features/TransformFeature.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Sketch/SketchElement.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Sketch/SketchPlane.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Sketch/ProfileExtractor.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Evaluator/FeatureEvaluator.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Sources/.../Serialization/FeatureCodable.swift` | ParametricEngine | 1.1 |
| `ParametricEngine/Tests/ParametricEngineTests/*.swift` | ParametricEngine | 1.1 |
| `OpeniOSCAD/Views/PropertyInspectorView.swift` | App | 1.3 |
| `Renderer/Sources/Renderer/Picking.swift` | Renderer | 1.4 |
| `ParametricEngine/Sources/.../UndoStack.swift` | ParametricEngine | 1.5 |
| `OpeniOSCAD/Views/SketchCanvasView.swift` | App | 1.6 |
| `OpeniOSCAD/Views/SketchToolbar.swift` | App | 1.6 |
| `OpeniOSCAD/ViewModels/SketchViewModel.swift` | App | 1.6 |
| `GeometryKernel/Sources/.../STEP/STEPWriter.swift` | GeometryKernel | 1.7 |
| `GeometryKernel/Sources/.../STEP/STEPReader.swift` | GeometryKernel | 1.7 |
| `GeometryKernel/Sources/.../STEP/STEPDocument.swift` | GeometryKernel | 1.7 |
| `ParametricEngine/Sources/.../Serialization/HistoryComment.swift` | ParametricEngine | 1.7 |
| `GeometryKernel/Tests/.../STEPTests.swift` | GeometryKernel | 1.7 |
| `OpeniOSCAD/Document/STEPDocument.swift` | App | 1.7 |

### Modified Files

| File | Milestone | Changes |
|------|-----------|---------|
| `project.yml` | 1.2 | Add ParametricEngine dependency |
| `ModelViewModel.swift` | 1.2, 1.3, 1.4, 1.5, 1.7 | Replace stubs with FeatureTree + evaluator |
| `AddPrimitiveSheet.swift` → `AddShapeSheet.swift` | 1.2 | Dimension input for convenience commands |
| `FeatureTreeView.swift` | 1.2 | Display Sketch/Extrude feature entries |
| `ContentView.swift` | 1.3, 1.6, 1.7 | Property inspector, sketch mode, document |
| `MetalViewport.swift` | 1.4, 1.6 | Tap picking gesture, orthographic mode |
| `RenderPipeline.swift` | 1.4 | Selection highlight pass |
| `TriangleMesh.swift` | 1.4 | Face ID tracking |
| `ModelShaders.metal` | 1.4 | Selection highlight in fragment shader |
| `OpeniOSCADApp.swift` | 1.7 | DocumentGroup scene |

---

## Testing Strategy

### Unit Tests (per milestone)

| Milestone | Test File | What It Covers |
|-----------|-----------|----------------|
| 1.1 | `SketchFeatureTests.swift` | Sketch creation, element types, plane variants |
| 1.1 | `ExtrudeFeatureTests.swift` | Additive/subtractive, sketch reference |
| 1.1 | `ProfileExtractorTests.swift` | Rectangle→Polygon2D, circle→Polygon2D, line closure |
| 1.1 | `EvaluatorTests.swift` | Sketch+Extrude→GeometryOp tree, cuts, multi-feature |
| 1.1 | `FeatureTreeTests.swift` | Insert, remove, move, suppress, lookup |
| 1.1 | `SerializationTests.swift` | JSON round-trip for all feature types |
| 1.3 | `ParameterEditTests.swift` | Parameter mutation triggers re-evaluation |
| 1.5 | `UndoStackTests.swift` | Push/undo/redo/clear correctness |
| 1.7 | `STEPTests.swift` | STEP write validity, read/write round-trip |

### E2E Tests (Maestro)

| Milestone | Flow | What It Tests |
|-----------|------|---------------|
| 1.2 | `10_add_box_renders.yaml` | Add Box → viewport shows geometry |
| 1.2 | `11_add_cylinder_renders.yaml` | Add Cylinder → viewport shows geometry |
| 1.3 | `12_edit_parameters.yaml` | Tap feature → edit width → geometry changes |
| 1.4 | `13_face_selection.yaml` | Tap geometry → face highlights |
| 1.5 | `14_undo_redo.yaml` | Add → undo → gone → redo → back |
| 1.6 | `15_sketch_mode.yaml` | Enter sketch → draw → finish → extrude |
| 1.7 | `16_save_load.yaml` | Save → close → reopen → features intact |

---

## Performance Targets

These must be met by the end of Phase 1:

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Add feature + re-eval (<10 features) | <50ms on iPhone 15 | Instrument `evaluate()` call duration |
| Full rebuild (<50 features) | <500ms on iPhone 15 | Instrument full re-eval |
| Display render | 60fps for <100K triangles | Metal GPU profiler, frame time <16.6ms |
| STL export | <1s for 100K triangles | Time `exportSTL()` |
| STEP save/load | <200ms | Time STEP write + read for a 50-feature model |

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| BSP-tree booleans produce artifacts on complex cut geometry | Incorrect CSG results | Track failure cases; Manifold C++ bridge replaces BSP in a later phase |
| STEP tessellated output not accepted by some CAD tools | Interop failure | Test against FreeCAD, PrusaSlicer; fall back to STL entity encoding |
| GPU color-ID picking unreliable on some Metal devices | Selection misses | CPU ray-cast fallback; test on A15+ |
| Sketch-on-face coordinate mapping inaccurate | Misplaced sketch elements | Extensive unit tests for plane projection; start with construction planes |
| Profile extraction fails for complex line-segment arrangements | Can't extrude user-drawn sketches | Phase 1 focus on simple cases (rect, circle, convex polygons); complex profiles later |
| Two-feature-per-shape tree feels verbose to new users | UX friction | Good default naming ("Box 1" instead of "Sketch 1 + Extrude 1"); consider tree grouping later |

---

## Definition of Done (Phase 1 Complete)

- [ ] All 7 milestones delivered and tested
- [ ] "Add Box" and "Add Cylinder" create sketch+extrude features and render geometry
- [ ] Manual sketch mode: user can sketch on a plane, draw shapes, extrude/cut
- [ ] User can sketch on a selected face
- [ ] User can tap a feature to edit its parameters with live preview
- [ ] User can tap geometry to select faces and edges
- [ ] Undo/redo works for all operations
- [ ] Save produces a valid STEP file with `@openioscad` sketch-based history
- [ ] Load reconstructs the full feature tree from a saved STEP file
- [ ] External STEP files open as imported geometry
- [ ] STL and 3MF export works
- [ ] Feature tree displays Sketch and Extrude as separate entries
- [ ] All unit tests pass
- [ ] All Maestro E2E tests pass
- [ ] Performance targets met on iPhone 15

# OpeniOSCAD — Vision

## What This Is

OpeniOSCAD is a free, open-source (MIT), native iOS parametric CAD app. Users build 3D models through direct touch interaction with a history-based feature tree. The native file format is STEP — the industry standard for exact geometry — enriched with parametric history in comments so every file is universally readable by any CAD tool while remaining fully editable in our app.

## Decided — Do Not Revisit

- **Name:** OpeniOSCAD
- **License:** MIT, public GitHub repo
- **Price:** Free. No IAP, no subscription, no paid tiers.
- **Platform:** iPhone primary. iPad fast-follow (same codebase, adaptive layout).
- **Source of truth:** The feature tree — a typed, ordered list of Feature objects in memory. On disk, this persists as a STEP file with history embedded in comments.
- **Design philosophy:** Accessible AND serious. Progressive disclosure. Direct manipulation. Respect user intelligence.

## Core Principles

### 1. The Feature Tree Is the Source of Truth

Every modeling operation is a Feature. Features are evaluated in order, top to bottom. The feature list is the single authoritative representation of the model.

- Undo = revert the feature list
- Save = write STEP geometry + feature history in comments
- Reorder = move an entry in the list, re-evaluate from that point
- Suppress = skip a feature during evaluation

Scripts, meshes, and rendered frames are all derived from the feature list. Never the reverse.

### 2. STEP-Native File Format

The native file format is `.step` (ISO 10303). STEP files support `/* */` comments per the spec. We embed the parametric feature history as structured JSON inside a STEP comment block:

```
ISO-10303-21;
HEADER; ... ENDSEC;
DATA;
/* @openioscad { "features": [...parametric history...] } */
#1=CARTESIAN_POINT('',(0.,0.,0.));
...standard STEP geometry entities...
ENDSEC;
END-ISO-10303-21;
```

**Why this matters:**
- **Universal compatibility.** Every CAD tool in the world reads STEP. FreeCAD, Fusion 360, SolidWorks, PrusaSlicer — they all open our files and get exact geometry. They ignore our comments.
- **Our app gets full editing.** When we open the file, we read the comment block, reconstruct the feature tree, and the user has full parametric editing capability.
- **Someone else's STEP file works too.** Open any of the millions of STEP files online. No history comment? Import the geometry as a solid body. The user can add new features on top.
- **One format, not two.** Saving and exporting to STEP are the same operation. No separate "native format" to maintain alongside export formats.

### 3. AI-First Design

The app is designed from the ground up for AI integration. The feature tree is a simple, structured instruction set that describes modeling intent:

```
1. Create a box: 40 × 25 × 3
2. Sketch a circle (r=2.5) on the top face
3. Cut through
4. Fillet the hole edges, radius 2
```

This is the interface for AI — not raw STEP text, not script code. An AI model describes what to build as feature instructions, the app creates the Feature objects, evaluates them to geometry, and saves as STEP. The AI never needs to understand STEP syntax or any CAD scripting language. It just describes intent.

This also works in reverse: the user can select geometry, ask "make this stronger" or "add mounting holes," and the AI can inspect the feature tree, understand the design history, and append/modify features.

### 4. Direct Manipulation, Not Text Manipulation

This is a touch-first CAD tool, not a script editor:

- **Tap a face** → contextual options: sketch, extrude, shell
- **Tap an edge** → contextual options: fillet, chamfer
- **Drag a dimension** → live parameter update and re-render
- **Reorder features** in the tree → model re-evaluates

The UI is not constrained by what any scripting language can express. If parametric CAD needs it, we build it.

## Architecture

Four Swift packages + one app target:

- **ParametricEngine:** Feature types, feature evaluator, constraint solver. Pure Swift. No UI dependencies. The brain of the app.
- **GeometryKernel:** Geometry operations — primitives, booleans, extrude/revolve, fillet/chamfer, tessellation, STEP read/write. Swift + C++ (ManifoldBridge only for CSG booleans).
- **Renderer:** Metal render pipeline, camera, face/edge selection and highlighting. Swift + Metal. Knows only triangle meshes and selection state.
- **SCADParser:** OpenSCAD lexer/parser/evaluator. Import-only — converts .scad files to Feature objects. Not on the critical modeling path.
- **OpeniOSCAD (app):** SwiftUI views, view models, undo/redo, file handling. Orchestrates all packages.

**Package boundaries are strict:** ParametricEngine does not import Renderer. GeometryKernel knows nothing about Features. Renderer knows nothing about either. Data flows one direction: Features → geometry → mesh → pixels.

## File Format

**Native:** `.step` — STEP AP214 geometry with `@openioscad` comment block containing the feature history as JSON. Human-readable (as much as STEP ever is), universally compatible, no proprietary lock-in.

**Import:** `.step` (native), `.scad` (via SCADParser → Feature conversion), `.stl` / `.3mf` (as mesh bodies)

**Export:** `.step` (same as save), `.stl` / `.3mf` (tessellated mesh), `.scad` (OpenSCAD script — lossy, best-effort), `.py` (CadQuery script)

Script export (OpenSCAD, CadQuery) is a convenience feature for interoperability. Features that the target language can't express (e.g., fillets in OpenSCAD) export as the evaluated geometry result (polyhedron), not as operations.

## UI/UX

### Layout

The 3D viewport is always primary. The feature tree is a collapsible bottom panel. A toolbar provides the core actions. Everything else is contextual — it appears when the user's selection makes it relevant.

### Progressive Disclosure

- **Level 1:** Add shapes (box, cylinder) via convenience commands. See the feature tree. Tap to select. Undo/redo.
- **Level 2:** Face/edge selection reveals contextual operations. Sketch mode on planes and faces. Feature reorder, suppress, delete. Property editing.
- **Level 3:** Sketch constraints. Patterns. Multi-body. Script export. AI assist.

### Sketch Mode

Select a face, enter sketch mode: 2D orthographic canvas with drawing tools (line, arc, circle, rectangle, dimension). Constraints are visible and interactive — under-constrained geometry pulses to show free degrees of freedom. Completing a sketch returns to model mode where it can be extruded, cut, or revolved.

### Design Philosophy

Most CAD apps are unapproachable not because engineering is hard but because the UI is bad.

- Progressive disclosure over feature dumps
- The feature tree is your history — visible, reorderable, editable, suppressible
- Constraints are visible, not hidden — make sketching feel like a game
- Undo is fearless
- Export is generous — your model, your formats, no lock-in
- A hobbyist and an engineer need the same tool — the difference is disclosure, not capability

## Development Phases

### Phase 1: Foundation
Sketch-based modeling foundation. Create geometry through sketch → extrude/cut, with convenience commands for common shapes (box, cylinder). Manual sketch mode on planes and faces. Face/edge selection, parameter editing, undo/redo, STEP save/load, STL/3MF export.

### Phase 2: Sketch + Constraints
Constraint solver for sketches (geometric + dimensional), revolve from sketches, advanced sketch tools (arc, spline, dimension visualization), face/edge reference stability across feature tree mutations.

### Phase 3: Advanced Operations
Fillet, chamfer, shell, patterns (linear, circular, mirror), .scad import/export, CadQuery export.

### Phase 4: Precision + AI
True BREP geometry kernel (exact surfaces), improved STEP fidelity, sweep/loft, AI feature generation from natural language.

### Phase 5: Polish + Ship
iPad layout with Apple Pencil, multi-body + assemblies, 2D drawings (DXF/PDF), App Store launch.

## What NOT to Do

- Do not store model state outside the feature list
- Do not make script the source of truth — STEP is the file format, scripts are export
- Do not add Python, JavaScript, or WASM runtimes
- Do not use C++ outside of ManifoldBridge
- Do not add third-party UI frameworks — SwiftUI + UIKit (Metal view) only
- Do not skip the feature evaluation pipeline for "optimization"
- Do not add networking or cloud features until Phase 5
- Do not design the UI around any scripting language's limitations

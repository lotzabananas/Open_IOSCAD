# Phase 2: Sketch + Extrude

## Goal

Users can enter 2D sketch mode on any face or plane, draw constrained geometry (lines, arcs, circles, rectangles), and use completed sketches to create 3D features (extrude, cut, revolve). This phase introduces the constraint solver and face/edge reference system between features.

## Prerequisites

- Phase 1 complete (feature pipeline, face selection, parameter editing, STEP I/O)

## Scope

### Sketch Mode
- Enter sketch mode by tapping a face or selecting a construction plane
- 2D orthographic canvas overlaid on the selected face
- Drawing tools: line, arc, circle, rectangle, dimension
- Geometric constraints: coincident, horizontal, vertical, perpendicular, parallel, tangent, equal, fixed
- Dimensional constraints: distance, angle, radius
- Constraint visualization: under-constrained geometry pulses to show free DOFs
- Sketch profiles: closed loops detected automatically for extrusion

### Constraint Solver
- New module in ParametricEngine: `ConstraintSolver/`
- Solves 2D geometric constraint systems (Newton-Raphson or similar iterative solver)
- Handles over-constrained detection and user feedback
- Real-time solving as the user drags points

### Sketch-Based Features
- **Extrude:** Push/pull a sketch profile into 3D (blind depth, through-all, up-to-face)
- **Cut:** Boolean subtract an extruded sketch from existing geometry
- **Revolve:** Rotate a sketch profile around an axis

### Face/Edge References
- Features can reference faces and edges of prior features (e.g., "extrude on the top face of Box 1")
- References survive feature reorder and parameter changes
- Broken references detected and reported to user

### New Feature Types
- `SketchFeature` — 2D sketch with constraints on a plane/face
- `ExtrudeFeature` — Extrude a sketch profile (replaces direct extrude from Phase 1)
- `CutFeature` — Boolean cut using an extruded sketch
- `RevolveFeature` — Revolve a sketch profile around an axis

### New UI
- Sketch canvas (2D orthographic Metal view or SwiftUI Canvas)
- Drawing tool palette
- Constraint badges (visual indicators on sketch geometry)
- Dimension input fields
- "Finish Sketch" / "Cancel Sketch" controls

## Key Technical Challenges
- Constraint solver performance for interactive dragging
- Robust closed-loop detection in sketch profiles
- Face/edge reference stability across feature tree mutations
- Smooth transition between 3D viewport and 2D sketch mode

## Deliverables
- Constraint solver in ParametricEngine
- Sketch feature type with full serialization
- Sketch UI with drawing tools and constraint visualization
- Extrude, Cut, Revolve features from sketches
- Face/edge reference system
- Unit tests for constraint solver
- Maestro E2E tests for sketch workflow

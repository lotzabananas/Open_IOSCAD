# Phase 3: Advanced Operations

## Goal

Expand the modeling toolkit with fillet, chamfer, shell, patterns, and script import/export. Users can create production-quality parts with smooth edges, thin walls, and repeated geometry.

## Prerequisites

- Phase 2 complete (sketch mode, constraint solver, extrude/cut/revolve, face/edge references)

## Scope

### Edge Operations
- **Fillet:** Round edges with a specified radius. Select one or more edges, specify radius, preview live.
- **Chamfer:** Bevel edges with distance or distance+angle. Same selection workflow as fillet.

### Shell
- Select a face to remove, specify wall thickness
- Hollows the solid, leaving the selected face open
- Handles internal corners and intersecting walls

### Patterns
- **Linear Pattern:** Repeat a feature along a direction (count + spacing)
- **Circular Pattern:** Repeat a feature around an axis (count + angle)
- **Mirror:** Mirror a feature across a plane

### Script Import/Export
- **OpenSCAD Import (.scad):** Reactivate SCADParser package. Lexer/parser/evaluator converts .scad files to Feature objects. Import-only path.
- **OpenSCAD Export (.scad):** Best-effort conversion of feature tree to OpenSCAD script. Features that OpenSCAD can't express (e.g., fillets) export as `polyhedron()` with evaluated geometry.
- **CadQuery Export (.py):** Convert feature tree to CadQuery Python script. Similar lossy fallback for unsupported operations.

### New Feature Types
- `FilletFeature` — edge references + radius
- `ChamferFeature` — edge references + distance/angle
- `ShellFeature` — face reference + thickness
- `LinearPatternFeature` — source feature + direction + count + spacing
- `CircularPatternFeature` — source feature + axis + count + angle
- `MirrorPatternFeature` — source feature + mirror plane

### ManifoldBridge (if needed)
- Fillet and chamfer may require more robust boolean operations than BSP-tree CSG
- Evaluate whether to introduce the Manifold C++ bridge in this phase or defer to Phase 4
- If introduced: C++ wrapper in `GeometryKernel/Sources/ManifoldBridge/`

## Key Technical Challenges
- Fillet/chamfer on tessellated geometry (approximation until Phase 4 BREP kernel)
- Shell operation correctness for complex part geometry
- Pattern feature references surviving feature tree mutations
- Maintaining <500ms rebuild target with patterns (N copies of a feature)

## Deliverables
- Fillet, chamfer, shell operations in GeometryKernel
- Pattern features in ParametricEngine
- SCADParser package reactivated for .scad import
- OpenSCAD + CadQuery export
- Unit tests for all new operations
- Maestro E2E tests for fillet, pattern, and export workflows

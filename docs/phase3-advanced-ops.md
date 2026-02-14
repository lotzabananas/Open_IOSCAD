# Phase 3: Advanced Operations

## Status: Complete

## Deliverables

### Geometry Operations (GeometryKernel)
- **FilletOperation** — Edge rounding via bevel strip generation. Detects sharp edges (dihedral angle > threshold) using edge-to-face adjacency, creates smooth bevel strips along those edges.
- **ChamferOperation** — Flat angled cuts at sharp edges. Reuses edge detection from FilletOperation, creates flat bevel strips instead of curved.
- **ShellOperation** — Hollows a solid body by offsetting vertices inward along normals. Supports open faces (removed during shell). Creates connecting wall strips between inner and outer shells at open boundaries.
- **PatternOperation** — Three pattern types:
  - *Linear*: Translates copies along a direction vector with configurable spacing
  - *Circular*: Rotates copies around an axis over a configurable angle span
  - *Mirror*: Reflects geometry across a plane, flips winding for correct normals

### Feature Types (ParametricEngine)
- **FilletFeature** — `radius`, `edgeIndices`, `targetID`
- **ChamferFeature** — `distance`, `edgeIndices`, `targetID`
- **ShellFeature** — `thickness`, `openFaceIndices`, `targetID`
- **PatternFeature** — `patternType` (.linear/.circular/.mirror), `sourceID`, `direction`, `count`, `spacing`, `axis`, `totalAngle`, `equalSpacing`

All feature types are Codable with round-trip serialization tested.

### Export
- **SCADExporter** — Exports FeatureTree to valid OpenSCAD .scad script. Handles extrude, revolve, transform, boolean, and pattern features. Fillet/chamfer/shell noted as comments (unsupported in OpenSCAD).
- **CadQueryExporter** — Exports FeatureTree to CadQuery Python script. Better fillet/chamfer/shell support than OpenSCAD via CadQuery API.

### Evaluator Integration
FeatureEvaluator updated with cases for all new feature types. Each operation modifies the target feature's mesh in-place during Pass 1 evaluation.

### UI Integration (OpeniOSCAD App)
- **ModelViewModel** — `addFillet()`, `addChamfer()`, `addShell()`, `addLinearPattern()`, `addCircularPattern()`, `addMirrorPattern()`, `exportSCAD()`, `exportCadQuery()` methods. Auto-naming counters for all new types.
- **PropertyInspectorView** — Dedicated inspectors for each new feature type with editable parameters and accessibility identifiers.
- **AddShapeSheet** — New "Operations" section with Fillet, Chamfer, Shell, Linear Pattern, Circular Pattern, and Mirror options.
- **ExportSheet** — OpenSCAD (.scad) and CadQuery (.py) export options added.
- **FeatureTreeView** — SF Symbol icons for all new feature types.

## Test Coverage
- **GeometryKernel**: 14 operation tests in OperationTests.swift (fillet, chamfer, shell, linear/circular/mirror pattern edge cases)
- **ParametricEngine**: 13 Phase 3 tests in Phase3Tests.swift (feature evaluation, export verification, serialization round-trip)
- **Total**: 191 tests passing (70 GK + 121 PE)

## Commits
- `e48a6da` feat(Phase3): fillet, chamfer, shell, pattern operations + SCAD/CadQuery export

# Phase 5: Polish + Ship

## Status: Complete

## Deliverables

### 1. iPad Adaptive Layout
- **ContentView.swift** uses `horizontalSizeClass` to switch between iPhone and iPad layouts
- **iPad layout**: Sidebar (300pt) with feature tree + property inspector, main viewport area
  - Toolbar at top of sidebar with undo/redo, add, export
  - Feature tree in sidebar body (always visible)
  - Property inspector below feature tree
  - Error banners float over the viewport
- **iPhone layout**: Preserved original compact layout with bottom panels
- Both layouts share sheet presentation for Add Shape and Export

### 2. Multi-Body + Assemblies
- **AssemblyFeature** (`ParametricEngine/Features/AssemblyFeature.swift`)
  - Groups features into independent bodies
  - Properties: memberFeatureIDs, color (RGBA), position (XYZ), rotation (Euler XYZ)
  - Codable, Sendable, round-trip serialization tested
- **AnyFeature.assembly** case added to Feature.swift with full Codable support
- **FeatureEvaluator** handles assembly as organizational (no geometry change)
- **AssemblyInspector** in PropertyInspectorView for editing position/rotation
- **"New Body Group"** button in AddPrimitiveSheet
- **FeatureTreeView** icon: `square.3.layers.3d`

### 3. 2D Drawings — DXF Export
- **DXFExporter** (`GeometryKernel/Export/DXFExporter.swift`)
  - AutoCAD R12-compatible DXF format
  - Three orthographic views: Front (XZ), Top (XY), Right (YZ)
  - Silhouette edge detection using face normal comparison against view direction
  - Layer organization: FRONT, TOP, RIGHT, LABELS, DIMENSIONS
  - Dimension annotations with bounding box measurements
  - Single-view export mode also available
- Accessible via Export Sheet as "DXF (AutoCAD)"

### 4. 2D Drawings — PDF Technical Drawing
- **PDFDrawingExporter** (`GeometryKernel/Export/PDFDrawingExporter.swift`)
  - CoreGraphics PDF generation (no external dependencies)
  - Three orthographic views in third-angle projection layout
  - View labels (FRONT, TOP, RIGHT)
  - Dimension annotations
  - Title block with model name, date, generator attribution
  - Paper sizes: A4 Landscape/Portrait, Letter Landscape/Portrait
  - Auto-scaling to fit all views proportionally
- Accessible via Export Sheet as "PDF Drawing"

### 5. Export Sheet Updates
- Added "2D Drawings" section with DXF and PDF buttons
- All export options now:
  - STL (Binary)
  - 3MF
  - OpenSCAD (.scad)
  - CadQuery (.py)
  - DXF (AutoCAD)
  - PDF Drawing
- All buttons have accessibility identifiers for Maestro testing

### 6. Maestro E2E Test Flows
- **MaestroTests/flows/** directory created with 9 test flows:
  1. `01_add_box.yaml` — Add box primitive, verify feature tree
  2. `02_add_cylinder.yaml` — Add cylinder primitive
  3. `03_undo_redo.yaml` — Undo/redo after adding shape
  4. `04_export_sheet.yaml` — Verify all export options visible
  5. `05_feature_tree.yaml` — Multiple features, selection, property inspector
  6. `06_sketch_mode.yaml` — Enter sketch mode, verify canvas
  7. `07_operations.yaml` — Verify Phase 3 operations sections
  8. `08_ai_generate.yaml` — Verify AI prompt field and button
  9. `09_assembly.yaml` — Verify assembly creation button
- **MaestroTests/scripts/build_and_test.sh** — Automated build + test runner

## Test Coverage

### New GeometryKernel Tests (ExportTests.swift)
- `testDXFExportProducesValidContent`
- `testDXFExportContainsLayers`
- `testDXFExportContainsLineEntities`
- `testDXFExportEmptyMesh`
- `testDXFSingleView`
- `testDXFExportContainsDimensions`
- `testPDFExportProducesData`
- `testPDFExportEmptyMeshReturnsNil`
- `testPDFExportContainsPDFHeader`
- `testPDFExportA4Portrait`
- `testPDFExportLetterLandscape`
- `testSTLBinaryExportLength`
- `testSTLASCIIExportContent`

### New ParametricEngine Tests (Phase5Tests.swift)
- `testAssemblyFeatureCreation`
- `testAssemblyFeatureRoundTrip`
- `testAssemblyEvaluatesWithoutError`
- `testAssemblyKindExists`
- `testDXFExportFromFeatureTree`
- `testPDFExportFromFeatureTree`
- `testSCADExportAssembly`
- `testCadQueryExportAssembly`
- `testAllFeatureKindsRegistered`

### Cumulative Totals
- GeometryKernel: 92 tests (13 new)
- ParametricEngine: 143 tests (9 new)
- **Total: 235 tests, 0 failures**
- Maestro E2E: 9 flows

## Files Created
- `GeometryKernel/Sources/GeometryKernel/Export/DXFExporter.swift`
- `GeometryKernel/Sources/GeometryKernel/Export/PDFDrawingExporter.swift`
- `ParametricEngine/Sources/ParametricEngine/Features/AssemblyFeature.swift`
- `GeometryKernel/Tests/GeometryKernelTests/ExportTests.swift`
- `ParametricEngine/Tests/ParametricEngineTests/Phase5Tests.swift`
- `MaestroTests/flows/01_add_box.yaml` through `09_assembly.yaml`
- `MaestroTests/scripts/build_and_test.sh`

## Files Modified
- `ParametricEngine/Sources/ParametricEngine/Feature.swift` — added `.assembly` to FeatureKind and AnyFeature
- `ParametricEngine/Sources/ParametricEngine/Evaluator/FeatureEvaluator.swift` — assembly case
- `ParametricEngine/Sources/ParametricEngine/Export/SCADExporter.swift` — assembly export
- `ParametricEngine/Sources/ParametricEngine/Export/CadQueryExporter.swift` — assembly export
- `OpeniOSCAD/ContentView.swift` — iPad adaptive layout with sidebar
- `OpeniOSCAD/ModelViewModel.swift` — assembly, DXF, PDF methods
- `OpeniOSCAD/Views/ExportSheet.swift` — DXF + PDF export buttons
- `OpeniOSCAD/Views/PropertyInspectorView.swift` — AssemblyInspector
- `OpeniOSCAD/Views/AddPrimitiveSheet.swift` — Assembly section
- `OpeniOSCAD/Views/FeatureTreeView.swift` — assembly icon

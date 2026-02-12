# CLAUDE.md — OpeniOSCAD Project Instructions

## What This Project Is
OpeniOSCAD is a free (MIT), native iOS parametric CAD app. Users build 3D models through direct touch interaction with a feature-tree-based history. The app exports to OpenSCAD scripts, STL, 3MF, and STEP. Read VISION.md for the full architecture and rationale.

## Architecture — Non-Negotiable
- **Feature-tree-authoritative.** The ordered list of Feature objects is the single source of truth. GUI actions modify the feature list. The engine re-evaluates from the modified point. Never store model state independently of the feature list. Scripts are an export format, not the source of truth.
- Four Swift packages + one app target:
  - **ParametricEngine:** Feature types, feature evaluator, constraint solver, script exporters. Pure Swift. No UI dependencies.
  - **GeometryKernel:** BREP types, primitives, booleans (via Manifold C++ bridge), extrude/revolve/fillet, tessellation, mesh export. Swift + C++ (ManifoldBridge only).
  - **Renderer:** Metal render pipeline, camera, face/edge selection. Swift + Metal.
  - **SCADParser:** OpenSCAD lexer/parser/evaluator for .scad import. Pure Swift. Import-only — not on the critical modeling path.
  - **OpeniOSCAD (app):** SwiftUI views, view models, file handling, undo/redo. Depends on all packages.

## Feature-Authoritative Flow
When implementing ANY operation that changes the model:
1. The action MUST modify the Feature list (append, update, reorder, or remove a Feature)
2. ModelViewModel detects the change
3. ParametricEngine re-evaluates from the modified feature forward
4. GeometryKernel produces updated geometry
5. Renderer displays the tessellated result
6. Feature tree UI updates

NEVER skip this flow. Never cache model state outside the feature list. Never let the viewport or a script be the source of truth.

## Code Rules
- Swift for all app logic, engine, UI, rendering, mesh generation, export.
- C++ ONLY in `GeometryKernel/Sources/ManifoldBridge/` for wrapping the Manifold library. Nowhere else.
- Every interactive UI element MUST have `.accessibilityIdentifier()` for Maestro testing. Convention in VISION.md.
- Write unit tests alongside implementations, not after. Tests live in each package's `Tests/` directory.
- No force unwraps in production code. Use `guard`/`let` or `throw`.
- Errors must include context: feature name, parameter name, and descriptive messages.

## File Format
- **Native:** `.ioscad` (JSON via Swift Codable). Human-readable, git-diffable.
- **Import:** `.scad` (via SCADParser → Feature conversion), `.stl`, `.3mf`
- **Export:** `.scad` (OpenSCAD), `.py` (CadQuery), `.stl`, `.3mf`, `.step` (Phase 4+)

## Package Boundaries
- ParametricEngine defines Feature types and calls GeometryKernel for geometry. It does not import Renderer or UI types.
- GeometryKernel knows nothing about features. It operates on geometry primitives, solids, and meshes.
- Renderer knows only TriangleMesh and selection state. Zero dependency on ParametricEngine.
- SCADParser is an import module. It converts .scad AST → Feature[]. It does not participate in the normal modeling pipeline.
- Data flows: Feature[] → ParametricEngine evaluates → GeometryKernel produces geometry → Tessellator → TriangleMesh → Renderer displays.

## Testing
- Unit tests: every package has `Tests/` with XCTest targets.
- Integration tests: `TestFixtures/` contains `.ioscad` and `.scad` files for regression testing.
- E2E tests: `MaestroTests/flows/` contains Maestro YAML flows for iOS Simulator.
- Run unit tests: `swift test --package-path ParametricEngine && swift test --package-path GeometryKernel && swift test --package-path Renderer && swift test --package-path SCADParser`
- Run Maestro: `./MaestroTests/scripts/build_and_test.sh`

## Performance Targets
- Add feature + re-eval (<10 features): <50ms on iPhone 15
- Full rebuild (<50 features): <500ms on iPhone 15
- Display render: 60fps for <100K triangles
- STL export: <1s for 100K triangles
- File save/load: <50ms

## What NOT to Do
- Do not make script the source of truth. The feature list is the source of truth.
- Do not add Python, JavaScript, or WASM runtimes.
- Do not use C++ outside of ManifoldBridge.
- Do not store model geometry independently of the feature list.
- Do not skip the feature evaluation pipeline for "optimization." If it's slow, optimize the pipeline, don't bypass it.
- Do not add third-party UI frameworks. SwiftUI + UIKit (for Metal view) only.
- Do not add networking or cloud features until Phase 5.
- Do not design UI around OpenSCAD limitations. Design for parametric CAD; export to OpenSCAD as a lossy format.

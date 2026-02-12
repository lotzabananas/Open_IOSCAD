# CLAUDE.md — OpeniOSCAD Project Instructions

## What This Project Is
OpeniOSCAD is a free (MIT), native iOS parametric CAD app. Users build 3D models through direct touch interaction with a history-based feature tree. The native file format is STEP with parametric history in comments. Read VISION.md for full architecture and rationale.

## Architecture — Non-Negotiable
- **Feature-tree-authoritative.** The ordered list of Feature objects is the single source of truth at runtime. GUI actions modify the feature list. The engine re-evaluates from the modified point. Never store model state independently of the feature list.
- **STEP-native file format.** Files save as standard STEP AP214 geometry with an `@openioscad` comment block containing the feature history as JSON. Any CAD tool can open the geometry. Our app can reconstruct full editing capability from the comment.
- **Scripts are export formats.** OpenSCAD and CadQuery are export targets, not the source of truth.
- Four Swift packages + one app target:
  - **ParametricEngine:** Feature types, feature evaluator, constraint solver. Pure Swift. No UI dependencies.
  - **GeometryKernel:** Primitives, booleans (via Manifold C++ bridge), extrude/revolve/fillet, tessellation, STEP read/write, mesh export. Swift + C++ (ManifoldBridge only).
  - **Renderer:** Metal render pipeline, camera, face/edge selection. Swift + Metal.
  - **SCADParser:** OpenSCAD lexer/parser/evaluator for .scad import. Pure Swift. Import-only.
  - **OpeniOSCAD (app):** SwiftUI views, view models, file handling, undo/redo. Depends on all packages.

## Feature-Authoritative Flow
When implementing ANY operation that changes the model:
1. The action MUST modify the Feature list (append, update, reorder, or remove a Feature)
2. ModelViewModel detects the change
3. ParametricEngine re-evaluates from the modified feature forward
4. GeometryKernel produces updated geometry
5. Renderer displays the tessellated result
6. Feature tree UI updates

NEVER skip this flow. Never cache model state outside the feature list.

## Code Rules
- Swift for all app logic, engine, UI, rendering, mesh generation, export.
- C++ ONLY in `GeometryKernel/Sources/ManifoldBridge/` for wrapping the Manifold library. Nowhere else.
- Every interactive UI element MUST have `.accessibilityIdentifier()` for Maestro testing.
- Write unit tests alongside implementations, not after. Tests live in each package's `Tests/` directory.
- No force unwraps in production code. Use `guard`/`let` or `throw`.
- Errors must include context: feature name, parameter name, and descriptive messages.

## File Format
- **Native:** `.step` (STEP AP214 with `@openioscad` JSON comment block for feature history)
- **Import:** `.step` (native), `.scad` (via SCADParser → Feature conversion), `.stl`, `.3mf`
- **Export:** `.step` (same as save), `.stl`, `.3mf`, `.scad` (OpenSCAD — lossy), `.py` (CadQuery)

## Package Boundaries
- ParametricEngine defines Feature types and calls GeometryKernel for geometry. It does not import Renderer or UI types.
- GeometryKernel knows nothing about features. It operates on geometry primitives, solids, and meshes.
- Renderer knows only TriangleMesh and selection state. Zero dependency on ParametricEngine.
- SCADParser is an import module. It converts .scad AST → Feature[]. Not on the critical modeling path.
- Data flows one direction: Feature[] → ParametricEngine → GeometryKernel → Tessellator → TriangleMesh → Renderer.

## Testing
- Unit tests: every package has `Tests/` with XCTest targets.
- Integration tests: `TestFixtures/` contains `.step` and `.scad` files for regression testing.
- E2E tests: `MaestroTests/flows/` contains Maestro YAML flows for iOS Simulator.
- Run unit tests: `swift test --package-path ParametricEngine && swift test --package-path GeometryKernel && swift test --package-path Renderer && swift test --package-path SCADParser`
- Run Maestro: `./MaestroTests/scripts/build_and_test.sh`

## Performance Targets
- Add feature + re-eval (<10 features): <50ms on iPhone 15
- Full rebuild (<50 features): <500ms on iPhone 15
- Display render: 60fps for <100K triangles
- STL export: <1s for 100K triangles
- STEP save/load: <200ms

## What NOT to Do
- Do not store model state outside the feature list
- Do not make script the source of truth — STEP is the file format, scripts are export
- Do not add Python, JavaScript, or WASM runtimes
- Do not use C++ outside of ManifoldBridge
- Do not add third-party UI frameworks — SwiftUI + UIKit (Metal view) only
- Do not skip the feature evaluation pipeline for "optimization"
- Do not add networking or cloud features until Phase 5
- Do not design UI around any scripting language's limitations

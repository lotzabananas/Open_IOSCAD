# CLAUDE.md — OpeniOSCAD Project Instructions

## What This Project Is
OpeniOSCAD is a free (MIT), native iOS parametric CAD app. Every model is an OpenSCAD-compatible .scad script. The GUI writes script, the engine evaluates script, the viewport renders the result.

## Architecture — Non-Negotiable
- Script-authoritative. The .scad text is the single source of truth. GUI actions modify the script text. The engine rebuilds geometry from script. Never store model state independently of the script.
- Three Swift packages + one app target:
  - SCADEngine: OpenSCAD lexer/parser/evaluator. Pure Swift. No UI dependencies.
  - GeometryKernel: Mesh primitives, CSG (BSP-tree, Manifold swap-in planned), transforms, extrusions, export. Swift.
  - Renderer: Metal render pipeline, camera, selection. Swift + Metal.
  - OpeniOSCAD (app): SwiftUI views, view models, file handling. Depends on all three packages.
- CSG booleans currently use BSP-tree implementation. Manifold C++ bridge planned for robustness upgrade.

## Code Rules
- Swift for all app logic, script engine, UI, rendering, mesh generation, export.
- Every interactive UI element MUST have .accessibilityIdentifier() for Maestro testing. See 03_MAESTRO_TESTING.md for the naming convention.
- Write unit tests alongside implementations, not after. Tests live in each package's Tests/ directory.
- No force unwraps in production code. Use guard/let or throw.
- Errors from script parsing/evaluation must include line numbers and descriptive messages.

## Script-Authoritative Flow
When implementing ANY feature that changes the model:
1. The action MUST modify the script text (String)
2. ModelViewModel detects the script change
3. SCADEngine re-parses and re-evaluates
4. GeometryKernel produces updated mesh
5. Renderer displays the result
6. Feature tree updates from @feature annotations

NEVER skip this flow. Never cache model state outside the script. Never let the viewport or feature tree be the source of truth.

## OpenSCAD Compatibility
- Standard .scad files from Thingiverse must parse and render.
- OpeniOSCAD extensions use structured comments: // @feature "Name"
- Desktop OpenSCAD ignores these comments. Our parser extracts them for the feature tree.
- When exporting, all output must be valid OpenSCAD syntax.

## File Organization
- Keep package boundaries clean. SCADEngine should not import GeometryKernel types directly in its public API. Use a protocol/enum (GeometryOp) as the interface between engine and kernel.
- Mesh data flows: SCADEngine produces GeometryOp tree → GeometryKernel evaluates to TriangleMesh → Renderer displays TriangleMesh.

## Testing
- Unit tests: every package has Tests/ with XCTest targets.
- Integration tests: TestFixtures/thingiverse_samples/ contains real .scad files. Test that they parse, evaluate, and produce non-empty meshes.
- E2E tests: MaestroTests/flows/ contains Maestro YAML flows for iOS Simulator.
- Run unit tests: `swift test --package-path SCADEngine && swift test --package-path GeometryKernel && swift test --package-path Renderer`
- Run Maestro: `./MaestroTests/scripts/build_and_test.sh`

## Performance Targets
- Script parse+eval: <100ms on iPhone 15
- Full model rebuild (<50 features): <500ms on iPhone 15
- Display render: 60fps for <100K triangles
- STL export: <1s for 100K triangles

## What NOT to Do
- Do not add Python, JavaScript, or WASM to this project.
- Do not store model geometry independently of the script.
- Do not skip the script-authoritative flow for "optimization." If it's slow, optimize the pipeline, don't bypass it.
- Do not add third-party UI frameworks. SwiftUI + UIKit (for Metal view) only.
- Do not add networking or cloud features until Phase 5.

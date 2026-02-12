# OpeniOSCAD — Phase 1 Task Breakdown

Read 01_VISION_AND_ARCHITECTURE.md first. These tasks build the MVP: open a `.scad` file, parse it, evaluate it, render 3D geometry, export STL, and show a customizer panel for parameterized models.

All tasks produce Swift code. No C++, no Python, no bridging headers. Each task lists inputs, outputs, acceptance criteria, and dependencies.

---

## Task 1.1: OpenSCAD Lexer

**Package:** `SCADEngine/Sources/SCADEngine/Lexer/`
**Files:** `Token.swift`, `Lexer.swift`

**Output:** A lexer that tokenizes OpenSCAD `.scad` source into a token stream.

**Token types needed:**
- Keywords: `module`, `function`, `if`, `else`, `for`, `let`, `each`, `include`, `use`, `true`, `false`, `undef`
- Builtin modules (recognized but not special-cased in lexer): `cube`, `cylinder`, `sphere`, `polyhedron`, `union`, `difference`, `intersection`, `translate`, `rotate`, `scale`, `mirror`, `linear_extrude`, `rotate_extrude`, `color`, `import`, `projection`, `hull`, `minkowski`, `echo`, `assert`, `children`
- Identifiers, number literals (int, float, scientific notation), string literals (with escape sequences)
- Operators: `+`, `-`, `*`, `/`, `%`, `^`, `<`, `>`, `<=`, `>=`, `==`, `!=`, `&&`, `||`, `!`, `?`, `:`
- Delimiters: `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `.`, `=`
- Comments: `//` line comments (preserve text for @feature parsing), `/* */` block comments
- Special variables: `$fn`, `$fa`, `$fs`, `$t`, `$children`

**Acceptance criteria:**
- Tokenizes all 20+ `.scad` files in `TestFixtures/thingiverse_samples/` without errors
- Preserves source location (line, column) on every token for error reporting
- Handles edge cases: nested block comments, string escapes, scientific notation (`1e-3`), negative numbers vs subtraction
- Unit tests in `Tests/SCADEngineTests/LexerTests.swift`

**Dependencies:** None — can start immediately.

---

## Task 1.2: OpenSCAD Parser

**Package:** `SCADEngine/Sources/SCADEngine/Parser/`
**Files:** `AST.swift`, `Parser.swift`

**Output:** A recursive descent parser producing an AST from the token stream.

**AST node types needed:**
- `Program` (top-level: list of statements)
- `ModuleDefinition` (name, params with defaults, body)
- `FunctionDefinition` (name, params with defaults, expression body)
- `ModuleInstantiation` (name, args, children block) — this covers cube(), translate(), difference(), etc.
- `Assignment` (variable = expression)
- `IfStatement` (condition, then, else)
- `ForStatement` (variable, range/list, body)
- `LetExpression`
- `Expression` variants: binary op, unary op, ternary, function call, list literal, range (`[start:step:end]`), index access, member access, number, string, bool, undef, identifier, list comprehension
- `UseStatement`, `IncludeStatement`

**Key OpenSCAD parsing quirks to handle:**
- Module instantiation with children: `translate([1,0,0]) cube(5);` — the cube is a child of translate
- Implicit union of multiple children: `difference() { cube(10); cylinder(r=3, h=20); }` — first child is base, rest are subtracted
- Named parameters: `cylinder(h=10, r=5);`
- The `children()` builtin and `$children` variable
- Modifier characters: `*` (disable), `!` (show only), `#` (highlight), `%` (transparent) — prefix on module instantiation
- Range expressions: `[0:10]`, `[0:2:10]`
- Vector/list literals: `[1, 2, 3]`

**Acceptance criteria:**
- Parses all test fixture `.scad` files into valid ASTs
- Error messages include line number and descriptive text ("Expected ';' after statement on line 42")
- Round-trip test: parse → pretty-print → parse again → ASTs are equivalent
- Unit tests in `Tests/SCADEngineTests/ParserTests.swift`

**Dependencies:** Task 1.1 (Lexer)

---

## Task 1.3: OpenSCAD Evaluator

**Package:** `SCADEngine/Sources/SCADEngine/Evaluator/`
**Files:** `Evaluator.swift`, `Environment.swift`, `BuiltinModules.swift`

**Output:** A tree-walking evaluator that interprets the AST and calls into the GeometryKernel to produce geometry.

**Environment/scoping rules (OpenSCAD is weird — get this right):**
- Variables are immutable within a scope. Reassignment in the same scope uses the LAST assignment (not an error, not sequential — the last one wins for the entire scope).
- Inner scopes can shadow outer variables.
- Module parameters create a new scope.
- `let()` creates a new scope for its children.
- Special variables (`$fn`, `$fa`, `$fs`, `$t`) propagate into children (dynamic scoping, not lexical).

**Builtin functions to implement:**
- Math: `abs`, `sign`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `floor`, `ceil`, `round`, `ln`, `log`, `pow`, `sqrt`, `exp`, `min`, `max`
- Type: `len`, `str`, `chr`, `ord`, `is_num`, `is_string`, `is_list`, `is_bool`, `is_undef`
- List: `concat`, `lookup`, `search`
- String: string indexing, `str()` for concatenation
- Vector math: vector addition/subtraction/scalar multiply, cross(), norm()

**Builtin modules to implement (these call into GeometryKernel):**
- Primitives: `cube`, `cylinder`, `sphere`, `polyhedron`
- Booleans: `union`, `difference`, `intersection`
- Transforms: `translate`, `rotate`, `scale`, `mirror`
- Extrusions: `linear_extrude`, `rotate_extrude`
- Other: `color`, `echo`, `assert`, `import`, `children`

**The Evaluator→Kernel interface:**
The evaluator produces a tree of geometry operations. Define a protocol/enum like:
```swift
enum GeometryOp {
    case primitive(PrimitiveType, [String: Value])
    case boolean(BooleanType, [GeometryOp])
    case transform(TransformType, [String: Value], GeometryOp)
    case extrude(ExtrudeType, [String: Value], GeometryOp)
}
```
The GeometryKernel takes this tree and produces a `TriangleMesh`.

**Acceptance criteria:**
- Evaluates all test fixture `.scad` files without runtime errors
- Correct scoping: test that last-assignment-wins works, special variable propagation works, module parameter shadowing works
- Correct math: sin(90) == 1, etc.
- Integration test: evaluate a `.scad` file → produce GeometryOp tree → verify expected primitives and transforms
- Unit tests in `Tests/SCADEngineTests/EvaluatorTests.swift`

**Dependencies:** Task 1.2 (Parser)

---

## Task 1.4: Customizer Variable Extractor

**Package:** `SCADEngine/Sources/SCADEngine/Customizer/`
**Files:** `CustomizerExtractor.swift`

**Output:** Extracts top-level variable declarations with OpenSCAD Customizer annotations and produces a data structure the UI can use to generate parameter controls.

**OpenSCAD Customizer annotation format:**
```scad
width = 40;           // [10:100] Bracket width       → slider, min=10, max=100
height = 25;          // [10:2:50] Height              → slider, min=10, step=2, max=50
style = "round";      // [round, square, hex] Style    → dropdown
show_holes = true;    //                               → checkbox (bool)
count = 4;            // [1:1:10]                      → integer slider
name = "Part";        //                               → text field (string)

/* [Dimensions] */     // ← Tab/group header
wall = 3;             // [1:10]                        → slider under "Dimensions" tab
```

**Output data structure:**
```swift
struct CustomizerParam {
    let name: String
    let label: String           // from comment text after annotation
    let group: String?          // from /* [GroupName] */ headers
    let defaultValue: Value     // number, string, bool
    let constraint: ParamConstraint?  // range, enum list, or none
    let lineNumber: Int         // for jumping to script
}
```

**Acceptance criteria:**
- Correctly extracts params from 10+ real Thingiverse Customizer-enabled files
- Handles all annotation formats: `[min:max]`, `[min:step:max]`, `[opt1, opt2, opt3]`, bare (no annotation)
- Handles tab/group headers `/* [GroupName] */`
- Returns params in source order
- Unit tests in `Tests/SCADEngineTests/CustomizerTests.swift`

**Dependencies:** Task 1.1 (Lexer) — can work from raw source with regex, or can use token stream. Minimal dependency.

---

## Task 1.5: Geometry Kernel — Primitives

**Package:** `GeometryKernel/Sources/GeometryKernel/Primitives/`
**Files:** `Cube.swift`, `Cylinder.swift`, `Sphere.swift`, `Cone.swift`, `Polyhedron.swift`
**Also:** `GeometryKernel/Sources/GeometryKernel/Mesh/TriangleMesh.swift`

**Output:** Functions that generate `TriangleMesh` for each OpenSCAD primitive.

**TriangleMesh data structure:**
```swift
struct TriangleMesh {
    var vertices: [SIMD3<Float>]    // positions
    var normals: [SIMD3<Float>]     // per-vertex normals
    var triangles: [(Int, Int, Int)] // vertex index triples
}
```

**Primitive specs (matching OpenSCAD behavior):**
- `cube(size, center)` — size is scalar or [x,y,z]. center=false puts corner at origin.
- `cylinder(h, r, r1, r2, center)` — r1/r2 for cone. $fn controls facets. center=false puts bottom at z=0.
- `sphere(r)` — $fn controls facets. UV sphere or icosphere tessellation.
- `polyhedron(points, faces)` — user-defined mesh from point list and face index lists.

**Acceptance criteria:**
- All meshes are manifold (watertight): every edge shared by exactly 2 triangles
- Normals point outward
- cube([10,10,10]) produces exactly 12 triangles (2 per face)
- cylinder with $fn=6 produces a hexagonal prism
- sphere with $fn=16 produces consistent topology
- Unit tests verify vertex count, face count, bounding box, and manifoldness
- Tests in `Tests/GeometryKernelTests/PrimitiveTests.swift`

**Dependencies:** None — can start immediately.

---

## Task 1.6: Geometry Kernel — CSG Booleans

**Package:** `GeometryKernel/Sources/GeometryKernel/CSG/`
**Files:** `CSGNode.swift`, `BooleanUnion.swift`, `BooleanDifference.swift`, `BooleanIntersection.swift`

**Output:** Boolean operations on triangle meshes: union, difference, intersection.

**Algorithm:** BSP-tree based mesh boolean (recommended) or any algorithm that produces manifold output from manifold input. The classic approach is:
1. Compute triangle-triangle intersections between mesh A and mesh B
2. Classify triangles as inside/outside relative to the other mesh
3. Select appropriate triangles based on operation type
4. Re-triangulate intersection edges
5. Produce clean manifold output

**This is the hardest geometry task.** If a robust implementation proves too complex for v1.0, an acceptable fallback is to use a CSG tree representation (lazy evaluation) and only tessellate at export/display time using a simpler approach. But the goal is real mesh booleans.

**Acceptance criteria:**
- union of two overlapping cubes produces correct manifold mesh
- difference of cylinder from cube produces correct hole
- intersection of two spheres produces lens shape
- Handles: non-overlapping inputs, fully contained inputs, coincident faces
- Results are manifold
- Performance: < 50ms for two 1000-triangle meshes on modern hardware
- Tests in `Tests/GeometryKernelTests/CSGTests.swift`

**Dependencies:** Task 1.5 (Primitives)

---

## Task 1.7: Geometry Kernel — Transforms

**Package:** `GeometryKernel/Sources/GeometryKernel/Transforms/`
**Files:** `Translate.swift`, `Rotate.swift`, `Scale.swift`, `Mirror.swift`

**Output:** Transform operations that modify vertex positions and normals of a TriangleMesh.

**OpenSCAD transform semantics:**
- `translate([x,y,z])` — translate all vertices
- `rotate([x,y,z])` — Euler angles in degrees, applied in order: rotate around X, then Y, then Z
- `rotate(a, v)` — rotate `a` degrees around axis `v`
- `scale([x,y,z])` — scale factors per axis. Negative values mirror. Must flip face winding for negative scales.
- `mirror([x,y,z])` — mirror across plane defined by normal [x,y,z]. Must flip face winding.

**Acceptance criteria:**
- translate([5,0,0]) on a unit cube moves bounding box min from [0,0,0] to [5,0,0]
- rotate([0,0,90]) on cube([1,2,3]) swaps X and Y extents
- scale([1,1,-1]) mirrors and flips normals correctly
- Transforms compose correctly (order matters — OpenSCAD applies right-to-left)
- Tests in `Tests/GeometryKernelTests/TransformTests.swift`

**Dependencies:** Task 1.5 (Primitives)

---

## Task 1.8: Geometry Kernel — Extrusions

**Package:** `GeometryKernel/Sources/GeometryKernel/Extrude/`
**Files:** `LinearExtrude.swift`, `RotateExtrude.swift`

**Output:** Extrusion operations that create 3D meshes from 2D polygon profiles.

**linear_extrude parameters:**
- `height` — extrusion distance along Z
- `center` — if true, center vertically
- `twist` — degrees of rotation over the extrusion height
- `scale` — scale factor at the top (scalar or [x,y])
- `slices` — number of intermediate layers (important for twist)
- `$fn` — also controls slices for twist

**rotate_extrude parameters:**
- `angle` — degrees of rotation (default 360)
- `$fn` — number of angular steps

**Input:** A 2D polygon defined as a list of [x,y] vertices (a closed path). The evaluator will produce these from `circle()`, `square()`, `polygon()` 2D primitives, or from `projection()`.

**Acceptance criteria:**
- linear_extrude of a square produces a cube-like mesh
- linear_extrude with twist produces helical shape
- rotate_extrude of a rectangle offset from Y axis produces a ring/torus shape
- All outputs are manifold
- Tests in `Tests/GeometryKernelTests/ExtrudeTests.swift`

**Dependencies:** Task 1.5 (for mesh data structure and 2D primitive generation)

---

## Task 1.9: Metal Renderer

**Package:** `Renderer/Sources/Renderer/`
**Files:** `RenderPipeline.swift`, `Camera.swift`, `SelectionHighlighter.swift`, `Shaders/ModelShaders.metal`, `Shaders/EdgeShaders.metal`

**Output:** A Metal-based 3D renderer that displays TriangleMesh objects with lighting, camera controls, and edge highlighting.

**Rendering requirements:**
- Phong shading with a single directional light
- Per-face flat shading (standard for CAD) with option for smooth shading
- Edge rendering (black wireframe overlay on solid faces)
- Background: light gray gradient (standard CAD look)
- Ground plane grid (toggleable)
- Orbit camera: single-finger drag rotates around model center
- Pan: two-finger drag translates camera
- Zoom: pinch gesture
- Fit-all: double-tap empty space to frame the model
- Selection highlight: selected faces/edges render in a different color (blue tint)

**Metal pipeline:**
1. Vertex shader: transform vertices by model-view-projection matrix
2. Fragment shader: Phong lighting with face normal
3. Edge pass: render triangle edges as lines with slight depth offset to avoid z-fighting
4. Selection pass: render selected geometry with highlight color

**Interface with SwiftUI:**
Expose as a `UIViewRepresentable` wrapping an `MTKView`. Accept a `TriangleMesh` as input. Expose gesture callbacks for the ViewModel.

**Acceptance criteria:**
- Renders a cube with visible faces, edges, and lighting at 60fps
- Orbit/pan/zoom gestures feel smooth and responsive
- Renders 100K triangle mesh at 60fps on iPhone 15
- Selection highlighting works on individual faces
- Tests: visual regression tests are hard — at minimum, test that the render pipeline initializes without crashing and produces non-empty framebuffers

**Dependencies:** Task 1.5 (needs TriangleMesh data structure). Can develop in parallel using hardcoded test meshes.

---

## Task 1.10: STL & 3MF Exporter

**Package:** `GeometryKernel/Sources/GeometryKernel/Export/`
**Files:** `STLExporter.swift`, `ThreeMFExporter.swift`

**Output:** Export TriangleMesh to binary STL and 3MF file formats.

**Binary STL format:**
- 80-byte header (can be any text, use "OpeniOSCAD Export")
- 4 bytes: uint32 triangle count
- Per triangle: 12 floats (normal xyz, vertex1 xyz, vertex2 xyz, vertex3 xyz) + 2 bytes attribute (0)
- All values little-endian float32

**3MF format:**
- ZIP archive containing XML files
- Minimum viable: `[Content_Types].xml`, `_rels/.rels`, `3D/3dmodel.model`
- The model XML contains vertices and triangles in a straightforward XML schema

**Acceptance criteria:**
- Exported STL files open correctly in PrusaSlicer and Cura (test manually during development)
- STL binary format matches spec exactly (verify with a hex dump for a known simple model)
- 3MF files pass validation (the 3MF consortium has a validator)
- Export 100K triangle mesh in < 1s
- Tests in `Tests/GeometryKernelTests/ExportTests.swift` — verify byte-level correctness of STL header, triangle count, and first triangle data

**Dependencies:** Task 1.5 (TriangleMesh data structure)

---

## Task 1.11: Integration — Wire It Together

**Package:** `OpeniOSCAD/` (app target) + integration of all packages

**Output:** A working iOS app that opens a `.scad` file, parses it, evaluates it, renders the 3D result, shows a feature tree, provides a script editor with syntax highlighting, shows a customizer panel for annotated variables, and exports STL.

**What this task builds in the app target:**
1. `OpeniOSCADApp.swift` — app entry point, document-based app architecture
2. `ModelViewModel.swift` — holds script text, triggers parse→evaluate→render pipeline, manages state
3. `ViewportView.swift` — wraps the Metal renderer
4. `ScriptEditorView.swift` — text editor with syntax highlighting (can use a `TextEditor` with attributed string or a lightweight syntax highlighting library)
5. `FeatureTreeView.swift` — reads @feature annotations from the parsed AST, displays as a list
6. `ParameterPanelView.swift` — reads CustomizerExtractor output, generates sliders/pickers
7. `ToolbarView.swift` — the three primary buttons ([+], edit, script toggle)
8. File handling: open `.scad` files from Files app, share sheet, etc.
9. Export: STL export via share sheet

**The critical data flow to get right:**
```
Script text (String) ←→ ScriptEditorView
       |
       v
Lexer → Tokens → Parser → AST
       |                    |
       v                    v
CustomizerExtractor    FeatureAnnotationParser
       |                    |
       v                    v
ParameterPanelView    FeatureTreeView
       |
       v (AST)
Evaluator → GeometryOp tree
       |
       v
GeometryKernel → TriangleMesh
       |
       v
Renderer → MTKView → ViewportView
```

**Acceptance criteria:**
- Open 10 real Thingiverse `.scad` files and see correct 3D renders
- Customizer sliders appear for annotated variables and changing them updates the model
- Script editor shows the file with syntax highlighting
- Feature tree shows @feature annotations (if present in file)
- Export to STL produces valid files
- App doesn't crash on malformed `.scad` files (shows error message instead)

**Dependencies:** ALL of 1.1-1.10

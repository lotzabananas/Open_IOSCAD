# Phase 4: Precision + AI

## Status: Complete

## Deliverables

### Sweep Operation (GeometryKernel)
- **SweepExtrudeOperation** — Sweeps a 2D polygon profile along a 3D path to create a solid. The profile is oriented perpendicular to the path at each station using Frenet-like coordinate frames.
  - *Frenet frames*: At each path station, computes tangent (direction along path), normal (perpendicular via cross product with up vector), and binormal (cross of tangent and normal). Handles degenerate cases where the tangent aligns with the default up vector by switching to an alternate reference.
  - *Twist*: Applies an incremental twist angle (radians) that interpolates linearly from 0 at the start to the full twist value at the end. Profile points are rotated in 2D before mapping to the 3D frame.
  - *Scale*: Uniform scale factor interpolated linearly from 1.0 at start to `scaleEnd` at the end of the path.
  - *Mesh generation*: Builds vertex rings at each path station, connects consecutive rings with side-face triangle strips, and caps both start and end with fan triangulation. Smooth vertex normals are computed by averaging face normals.
  - *Guard clauses*: Returns empty mesh for polygons with fewer than 3 points or paths with fewer than 2 stations.

### Loft Operation (GeometryKernel)
- **LoftExtrudeOperation** — Lofts between two or more 2D profiles at specified Z-heights to create a smooth solid. Profiles must have identical point counts for 1:1 vertex correspondence.
  - *Hermite interpolation*: Uses cubic smoothstep function `t^2 * (3 - 2t)` for profile blending, producing smoother transitions than linear interpolation. Applied per-vertex in the XY plane while Z interpolates linearly.
  - *Multi-profile support*: Handles N profiles with N-1 spans. Avoids duplicate rings at span junctions by skipping the first slice of subsequent spans.
  - *Configurable resolution*: `slicesPerSpan` parameter (default 4) controls the number of interpolation slices between each pair of profiles.
  - *Mesh generation*: Same ring-connection and capping strategy as sweep. Bottom and top caps use fan triangulation. Vertex normals computed by face-normal averaging.
  - *Guard clauses*: Returns empty mesh for fewer than 2 profiles, mismatched profile/height counts, fewer than 3 points per profile, or mismatched point counts between profiles.

### Feature Types (ParametricEngine)
- **SweepFeature** — Conforms to `Feature` and `Sendable`. Properties: `profileSketchID` (cross-section sketch), `pathSketchID` (sweep path sketch), `twist` (degrees, default 0), `scaleEnd` (default 1.0), `operation` (additive/subtractive). Feature kind: `.sweep`.
- **LoftFeature** — Conforms to `Feature` and `Sendable`. Properties: `profileSketchIDs` (ordered array of sketch IDs, bottom to top), `heights` (Z-heights matching each profile), `slicesPerSpan` (default 4), `operation` (additive/subtractive). Feature kind: `.loft`.

Both feature types are Codable with round-trip JSON serialization tested.

### AI Feature Generator (ParametricEngine)
- **FeatureGenerator** — Template-based natural language to feature conversion. No LLM required; works entirely offline using pattern matching and regex extraction.
  - *11 pattern matchers*, each tried in priority order:
    1. **Box** — Matches "box", "cube", "block". Extracts `W x D x H` dimensions. Generates sketch + extrude. Confidence: 0.9.
    2. **Cylinder** — Matches "cylinder", "rod", "pipe". Extracts radius and height. Generates sketch + extrude. Confidence: 0.85.
    3. **Sphere** — Matches "sphere", "ball". Extracts radius or diameter. Generates semicircle sketch (24 segments) + revolve. Confidence: 0.85.
    4. **Hole** — Matches "hole", "drill", "bore". Extracts radius/diameter and depth. Generates sketch + subtractive extrude. Confidence: 0.8.
    5. **Fillet** — Matches "fillet", "round". Extracts radius. Returns description only (applied to selected feature). Confidence: 0.7.
    6. **Chamfer** — Matches "chamfer", "bevel". Extracts distance. Returns description only. Confidence: 0.7.
    7. **Shell** — Matches "shell", "hollow", "thin wall". Extracts wall thickness. Returns description only. Confidence: 0.7.
    8. **Pattern** — Matches "pattern", "array", "repeat". Extracts count and spacing. Returns description only. Confidence: 0.6.
    9. **Plate** — Matches "plate", "flat", "sheet". Extracts width, depth, thickness. Generates sketch + extrude. Confidence: 0.85.
    10. **Bracket** — Matches "bracket", "l-shape", or word-boundary "angle". Extracts size and thickness. Generates two sketch + extrude pairs (L-shape). Confidence: 0.7.
    11. **Enclosure** — Matches "enclosure", "case", "housing". Extracts width, depth, height, wall thickness. Generates sketch + extrude + shell. Confidence: 0.8.
  - *Number extraction*: Regex-based extraction supporting `keyword: value`, `keyword value`, and `value keyword` formats. Dimension parser handles "30x20x10" and "30 by 20 by 10" patterns.
  - *Word matching*: Uses `NSRegularExpression` with `\b` word boundaries to avoid substring false positives (e.g., "angle" not matching "triangle").
  - Throws `GenerationError.unrecognizedPrompt` when no pattern matches.

- **GenerationResult** — Contains: `features` (array of `AnyFeature`), `description` (human-readable summary), `confidence` (0.0-1.0 score).

- **AIFeatureBackend protocol** — Pluggable interface for future AI backends (local or cloud LLM). Method: `generate(prompt:context:) async throws -> GenerationResult`. Accepts `AIGenerationContext` with existing features, selected feature ID, and model bounding box.

- **AIGenerationContext** — Provides context to AI backends: `existingFeatures`, `selectedFeatureID`, `modelBounds`.

### Export Support
- **SCADExporter** — Sweep and loft features exported as SCAD-compatible constructs (stubs with comments documenting parameters, since OpenSCAD has no native sweep/loft).
- **CadQueryExporter** — Sweep and loft exported as CadQuery Python stubs with parameter documentation for downstream toolchains.

### UI Integration (OpeniOSCAD App)
- **Sweep Inspector** — Property inspector for SweepFeature with editable twist (degrees) and scale-end fields. Sketch selection for profile and path.
- **Loft Inspector** — Property inspector for LoftFeature with editable heights and slices-per-span. Multi-profile sketch selection.
- **AI Generate Section** — Text input field for natural language prompts. Generates features via `FeatureGenerator.generate(from:)` and appends them to the feature tree. Displays confidence score and description of generated features.

### Evaluator Integration
FeatureEvaluator updated with `.sweep` and `.loft` cases. Sweep evaluation extracts profile polygon and path points from referenced sketches, delegates to `SweepExtrudeOperation.sweep()`. Loft evaluation collects profile polygons from referenced sketches, delegates to `LoftExtrudeOperation.loft()`. Both produce errors when referenced sketch IDs are missing from the tree.

## Test Coverage

### GeometryKernel — 9 tests in SweepLoftTests.swift
- **Sweep** (5 tests): straight path, curved path (quarter circle in XZ plane), twist (90-degree), empty polygon guard, single-point path guard
- **Loft** (4 tests): two-square taper with bounding box validation, three-profile multi-span, mismatched point count guard, single profile guard

### ParametricEngine — 13 tests in Phase4Tests.swift
- **SweepFeature** (2 tests): creation with defaults, JSON round-trip with twist + scale
- **LoftFeature** (4 tests): creation with custom slicesPerSpan, JSON round-trip, evaluation with matching profiles, missing profile error handling
- **AI Feature Generator** (6 tests): box with dimensions, cylinder with radius/height, plate with thickness, enclosure (sketch + extrude + shell), unrecognized prompt error, generated features evaluate to non-empty mesh
- **Feature kinds** (1 test): `.sweep` and `.loft` present in `FeatureKind.allCases`

### Totals
- **Phase 4 tests**: 22 (9 GK + 13 PE)
- **Cumulative project tests**: 213 (79 GK + 134 PE)

## Commits
- `5acfffc` feat(Phase4): sweep, loft, AI feature generator, 22 new tests

# Phase 5: Polish + Ship

## Goal

Production-ready release: iPad layout with Apple Pencil support, multi-body and assembly modeling, 2D technical drawings, and App Store launch.

## Prerequisites

- Phase 4 complete (BREP kernel, improved STEP fidelity, sweep/loft, AI features)

## Scope

### iPad Layout + Apple Pencil
- Adaptive layout: larger feature tree panel, wider property inspector, toolbar repositioning
- Apple Pencil support for sketch mode (pressure-sensitive line weight, precision drawing)
- Drag-and-drop from Files into the app
- Stage Manager / multi-window support
- Keyboard shortcuts for common operations

### Multi-Body + Assemblies
- Multiple independent solid bodies in a single document
- Body-level operations (combine, split)
- Assembly mode: position bodies relative to each other with constraints (mate, align, offset)
- Assembly tree alongside feature tree
- Component reuse (insert a saved part as a component)

### 2D Technical Drawings
- Generate 2D orthographic projections from 3D model (front, top, side, isometric)
- Automatic hidden-line removal
- Dimension annotations (driven from 3D model parameters)
- Section views and detail views
- Export to DXF and PDF formats

### App Store Preparation
- App Store screenshots and preview video
- Privacy policy (no data collection)
- App Store description and metadata
- Performance profiling and optimization pass
- Accessibility audit (VoiceOver, Dynamic Type)
- Localization framework (English first, structure for future languages)
- Crash reporting and analytics (privacy-respecting, opt-in)

### Final QA
- Full Maestro E2E test suite covering all phases
- Device matrix testing (iPhone 15/16, iPad Pro, iPad Air)
- Memory profiling for large models
- Battery impact assessment
- Edge case testing (empty models, very large models, corrupt files)

## Key Technical Challenges
- Assembly constraint solver (3D, multi-body)
- Hidden-line removal for 2D drawings (visibility computation)
- Apple Pencil latency for sketch mode (<20ms target)
- App Store review compliance
- Performance across the full iPhone/iPad device range

## Deliverables
- iPad adaptive layout
- Apple Pencil sketch integration
- Multi-body modeling
- Assembly mode with constraints
- 2D drawing generation (DXF, PDF export)
- App Store submission package
- Comprehensive test suite
- Performance optimization pass

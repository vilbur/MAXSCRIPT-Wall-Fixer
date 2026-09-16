# Wall Mesh Cleaner

## Slicing pipeline (0.56)

Run `WallMeshCleaner.ms`. The existing **Slice Selected Walls** and **Fix N-gons** controls use the same native Edit Poly pipeline:

1. Reuse an exclusive top Edit Poly modifier, or add one above the existing stack.
2. Remove only geometrically straight vertices with exactly two incident edges; preserve boundary corners.
3. Collect boundary corner positions once.
4. Complete vertical cuts in the wall plane.
5. Complete horizontal cuts against the resulting topology.
6. Dissolve eligible fragments of original internal diagonal edges.
7. Repeat safe diagonal and collinear cleanup until neither changes topology.
8. Validate boundaries, corner positions, area by material/smoothing group, topology, and protected orthogonal edge coverage.

Both passes use the same preserved anchors. Topology is re-evaluated after each native operation; indices are never carried into the next operation. The Angle control classifies boundary directions; the tighter collinear tolerance is independent. Horizontal-only and vertical-only modes still run only their requested pass.

The frame uses the wall normal and projected vertical direction. Geometry rotated around scene Z, including rotation baked into vertices, is supported. Computation excludes scene translation to reduce floating-point cancellation. For horizontal planes, the longest boundary edge defines the in-plane horizontal direction.

The base object is not changed or collapsed. A failed operation restores the previous exclusive top modifier, or removes the newly added modifier. True object instances are made unique before editing their evaluated stack, so peers retain their original stack and geometry. A top Edit Poly shared by otherwise independent nodes is made unique for the selected node. Buried modifiers receive a new top Edit Poly. Commit active Edit Poly operations before running the tool.

### Conservative cleanup

- No automatic welding in Slice or Fix N-gons: the legacy weld arguments are accepted for caller compatibility.
- Real corners and junctions survive; hidden-edge visibility does not override vertex valence.
- Original orthogonal edges and every completed cut are protected geometrically, including after subdivision or collinear simplification.
- Diagonal dissolution requires two adjacent coplanar faces, matching material/smoothing groups, continuous UVs, and a simple merged boundary. Boundaries and opening loops cannot be dissolved.
- Material, smoothing, UV, or topology constraints can require an internal diagonal to remain.
- Auto Smooth, when requested by Fix N-gons, is applied through Edit Poly after topology cleanup.

Supported input is planar, consistently oriented manifold wall geometry with valid polygon boundaries. Native n-gons containing a hole bridged by a twice-traversed internal edge are supported. Nonplanar walls, degenerate polygons, and genuinely self-intersecting boundaries are rejected rather than remodeled. Other cleaning controls retain their existing behavior.

## Regression test

`OrthogonalPipeline_TEST.ms` builds a rectangular wall with a rectangular opening, redundant straight boundary vertices, and hidden internal diagonals. It runs against object rotations, baked rotation, pre-existing Edit Poly modifiers, and an Edit Poly over Editable Mesh (a native hole-bridged n-gon). Additional cases cover a door notch, nonuniform scale, a genuine sloping boundary, material seams, rollback of nonplanar input, single-direction cuts, and unselected-instance preservation.

Expected window-only result: **16 vertices, 24 edges, 8 rectangular polygons**; with the door notch, **30 vertices, 48 edges, 18 rectangular polygons**, with identical outer/opening boundaries and unchanged base geometry. A second run through Fix N-gons must leave this result unchanged.

Run in a disposable scene or with `3dsmaxbatch.exe`. The report is written to `test/pipeline-native-results.txt`. Success requires `ALL TESTS PASSED`; a successful Slice call alone is insufficient.

`PreSliceCleanup_TEST.ms` and `SliceCleanup_TEST.ms` are historical tests of the replaced algorithms; their welding and per-cut dissolving expectations do not apply to this pipeline.

The test also exports native before/after geometry in `test/pipeline-window-before.obj`, `test/pipeline-window-after.obj`, and `test/pipeline-door-after.obj`. `test/pipeline-comparison.svg` shows the exported window topology. `test/pipeline-validation.json` records an independent check of the exported opening, outer boundary, edge directions, and surface area.

API reference: [Autodesk Edit Poly](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/Mesh-Editing/GUID-9CA2E6DA-08C2-4279-87C9-B64351C0147E.html).

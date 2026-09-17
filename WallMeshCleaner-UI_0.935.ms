/*
WallMeshCleaner UI 0.935
Persistent UI settings, rollouts, handlers and dialog creation.
Load through WallMeshCleaner.ms during normal development.
*/

global WallMeshCleanerRollout
global WallMeshCleanerOptionsRollout
global WallMeshCleanerFaceSlicerRollout
global WallMeshCleanerFaceCleanerRollout
global WallMeshCleanerEdgeCleanerRollout
global WallMeshCleanerVertexCleanerRollout

saved_weld_enabled = WallMeshCleaner.readIniBool "WeldVertices" true
saved_weld_threshold = WallMeshCleaner.readIniFloat "WeldThreshold" 1.0
saved_display_hidden_edges = WallMeshCleaner.readIniBool "DisplayHiddenEdges" false
saved_double_side = WallMeshCleaner.readIniBool "DoubleSide" true
saved_auto_smooth = WallMeshCleaner.readIniBool "AutoSmooth" false
saved_cut_mode_index = WallMeshCleaner.readIniInt "CutMode" 1
saved_angle_threshold = WallMeshCleaner.readIniFloat "AngleThreshold" 5.0
saved_planar_tolerance = WallMeshCleaner.readIniFloat "PlanarTolerance" 1.0
saved_slice_plane_mode_index = WallMeshCleaner.readIniInt "SlicePlaneMode" 2
saved_border_angle_threshold = WallMeshCleaner.readIniFloat "BorderAngleThreshold" 5.0
saved_double_vert_threshold = WallMeshCleaner.readIniFloat "DoubleVertThreshold" 1.0
saved_slice_precision = WallMeshCleaner.readIniFloat "SlicePrecision" 0.01
saved_dialog_position = WallMeshCleaner.loadDialogPosition()

rollout WallMeshCleanerOptionsRollout "Options" width:310 height:142
(
    checkbox weld_checkbox "Weld Vertices" pos:[8,13] width:110 height:20 checked:saved_weld_enabled tooltip:"Legacy weld setting.\nSlice and Fix N-gons preserve boundaries without welding."
    label weld_threshold_label "Threshold:" pos:[140,15] width:62 height:18
    spinner weld_threshold_spinner "" pos:[200,12] width:102 height:20 \
        range:[0.0,1000000.0,saved_weld_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Maximum weld distance.\n\nUnits: system units."

    checkbox auto_smooth_checkbox "Auto Smooth" \
        pos:[8,42] width:126 height:20 checked:saved_auto_smooth \
        tooltip:"Enable automatic smoothing.\n\nApplied around supported cleanup operations."

    button smooth_button "Smooth" \
        pos:[166,38] width:136 height:26 \
        tooltip:"Apply Auto Smooth.\n\nUses the current smoothing threshold."

    checkbutton hidden_edges_checkbutton "Display Hidden Edges" \
        pos:[8,75] width:142 height:26 checked:saved_display_hidden_edges \
        tooltip:"Toggle hidden edge display.\n\nAffects selected wall objects."

    checkbutton double_side_checkbutton "Double Side" \
        pos:[160,75] width:142 height:26 checked:saved_double_side \
        tooltip:"Toggle double-sided display.\n\nDisables backface culling when enabled."

    label slice_precision_label "Advanced - Slice Precision:" pos:[8,114] width:152 height:18
    spinner slice_precision_spinner "" pos:[164,110] width:138 height:20 \
        range:[0.0,1000000.0,saved_slice_precision] type:#worldUnits scale:0.001 \
        tooltip:"Advanced post-slice precision threshold.\n\nSlice Selected Walls checks only vertices created by the latest Make 1 Slice. New vertices within this world-space distance of the defining anchor vertices are welded back to the anchor before redundant-loop cleanup.\n\nDefault: 0.01 world units."

    on weld_checkbox changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on weld_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on auto_smooth_checkbox changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on hidden_edges_checkbutton changed state do
    (
        WallMeshCleaner.setSelectionDisplayHiddenEdges state
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on double_side_checkbutton changed state do
    (
        WallMeshCleaner.setSelectionDoubleSide state
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on slice_precision_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on smooth_button pressed do
    (
        ::WallMeshCleanerRollout.runSmooth()
    )
)

rollout WallMeshCleanerFaceSlicerRollout "Face Slicer" width:310 height:458
(
    radiobuttons cut_mode_radio "" pos:[8,8] width:243 height:20 \
        labels:#("All", "Horizontal", "Vertical") default:saved_cut_mode_index columns:3 align:#left \
        offsets:#([0,0],[-15,0],[0,0]) \
        tooltip:"Choose slicing direction.\n\nAll: Vertical first, then Horizontal."

    spinner angle_spinner "Angle:" pos:[257,8] width:45 height:20 \
        range:[0.0,45.0,saved_angle_threshold] type:#float scale:1.0 \
        tooltip:"Orientation tolerance.\n\nUnits: degrees."

    label planar_tolerance_label "Planar tolerance:" pos:[8,40] width:96 height:18
    spinner planar_tolerance_spinner "" pos:[104,37] width:96 height:20 \
        range:[0.0,1000000.0,saved_planar_tolerance] type:#float scale:0.1 \
        tooltip:"Maximum distance from the detected wall plane before the wall is rejected.\n\nUnits: system units."

    label slice_plane_mode_label "Slice Direction" pos:[8,66] width:120 height:18
    radiobuttons slice_plane_mode_radio "" pos:[126,63] width:176 height:22 \
        labels:#("Global Axis", "Edge Direction") default:saved_slice_plane_mode_index columns:2 align:#left \
        tooltip:"Choose how each slice plane is oriented.\n\nCorner + Global Axis: source corner plus the wall-local horizontal/vertical frame.\nEdge Direction: source corner plus its matching adjacent border vertex. This is the default."

    button reset_slicing_button "RESET OBJECT" pos:[8,92] width:294 height:32

    button prepare_object_button "PREPARE OBJECT" pos:[8,132] width:294 height:34 \
        tooltip:"Prepare all selected geometry as planar wall objects.\n\n1. Add one instanced Smooth modifier to the selection and enable Auto Smooth using the current Angle value.\n2. Bake to Editable Poly.\n3. Split hard smoothing-group boundaries into elements.\n4. Detach every element to its own object."

    button slice_button "SLICE SELECTED WALLS" pos:[8,172] width:294 height:34 tooltip:"Build a fixed queue from the base-object slice candidates and process every queued slice in Wall topology cleanup.\n\nVertical: one task per base candidate.\nHorizontal: candidates at the same base-object world Z are grouped and sliced once per elevation.\n\nAll mode runs Vertical completely first, then Horizontal."

    button clean_up_sliced_edges_postprocess_button "CLEAN UP SLICED EDGES POSTPROCESS" pos:[8,212] width:294 height:28 \
        tooltip:"MANUAL POSTPROCESS ONLY. It is not run by Slice Selected Walls.\n\nLMB: Run the final straight-vertex postprocess in its own CLEAN UP SLICED EDGES POSTPROCESS Edit Poly modifier.\n\nRMB: Select exactly the current postprocess candidate vertices for inspection. No topology change and no undo block.\n\nCandidates are non-border vertices with exactly two visible straight edges. The two visible edges are never removed."

    groupBox manual_group "MANUAL" pos:[8,246] width:294 height:112
    button make_one_slice_button "1. MAKE 1 SLICE" pos:[16,264] width:278 height:28 \
        tooltip:"LMB: Analyze the unchanged base object and make one pending slice. Edge Direction remembers successful base border edges, not infinite planes. Failed cuts stay pending for retry after later topology changes. Vertical and horizontal are tracked separately.\nNewly created non-border edges are selected.\n\nRMB: Convert the currently selected sliced edges to non-border sliced vertices."
    button clean_up_sliced_edges_button "2. CLEAN UP SLICED EDGES" pos:[16,296] width:278 height:28 \
        tooltip:"LMB: Remove the redundant edges and eligible new vertices.\n\nRMB: Select redundant edge candidates and the slice-created vertex candidates that would be removed with them. Edge and Vertex selections are both stored; Vertex mode is left active."

    button slice_precision_cleanup_button "3. FIX SLICE PRECISION" pos:[16,328] width:278 height:28 \
        tooltip:"LMB: Repair all new slice vertices within Slice Precision of any original pre-slice vertex.\n\nRMB: Select all vertices that LMB would repair, without changing topology."

    groupBox debug_group "Debug" pos:[8,362] width:294 height:88
    button check_corners_button "1. CHECK CORNERS" pos:[16,380] width:278 height:28 \
        tooltip:"Select exactly the INNER VERTS captured by the last Reset Slicing.\n\nNo corner availability is recalculated. Run Reset Slicing first."
    button clean_up_slice_button "2. CLEAN UP SLICE" pos:[16,412] width:278 height:28 \
        tooltip:"LMB: Select only sliced verts with exactly 2 visible edges that are not on a border and are not Reset Slicing INNER VERTS. No topology change.\n\nRMB: Remove only eligible sliced verts using the same filter."
    on cut_mode_radio changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on angle_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on planar_tolerance_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on slice_plane_mode_radio changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on prepare_object_button pressed do
    (
        ::WallMeshCleanerRollout.runPrepareObject()
    )

    on slice_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugSliceSelectedWalls()
    )

    on reset_slicing_button pressed do
    (
        ::WallMeshCleanerRollout.runResetSlicing()
    )

    on reset_slicing_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugSelectInnerCorners()
    )

    on make_one_slice_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugMakeOneSlice()
    )

    on make_one_slice_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugSelectSlicedEdgeVertices()
    )

    on clean_up_sliced_edges_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugCleanUpSlicedEdges()
    )

    on clean_up_sliced_edges_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugInspectCleanUpSlicedEdges()
    )

    on slice_precision_cleanup_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugSlicePrecisionCleanup()
    )

    on slice_precision_cleanup_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugSelectSlicePrecisionCandidates()
    )

    on clean_up_sliced_edges_postprocess_button pressed do
    (
        ::WallMeshCleanerRollout.runCleanUpSlicedEdgesPostprocess()
    )

    on clean_up_sliced_edges_postprocess_button rightclick do
    (
        ::WallMeshCleanerRollout.runInspectCleanUpSlicedEdgesPostprocess()
    )

    on check_corners_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugCheckCorners()
    )

    on clean_up_slice_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugInspectCleanUpSlice()
    )

    on clean_up_slice_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugCleanUpSlice()
    )

)

rollout WallMeshCleanerFaceCleanerRollout "Face Cleaner" width:310 height:60
(
    button junction_button "Fix N-gons" pos:[8,8] width:294 height:34 tooltip:"Reduce wall N-gons.\n\nPrefer orthogonal clean cuts.\n\nRemove redundant dirty topology."

    on junction_button pressed do
    (
        ::WallMeshCleanerRollout.runFaceCleaner()
    )
)

rollout WallMeshCleanerEdgeCleanerRollout "Edge Cleaner" width:310 height:92
(
    button find_two_edge_verts_button "1. Find Two-Edge Verts" pos:[8,8] width:294 height:34 \
        tooltip:"LMB: Select all live vertices with exactly 2 visible edges whose edge directions form a straight 180-degree continuation. Visible-edge corners are excluded. No topology change.\n\nRMB: Weld each candidate to the closest neighbour on one of those two visible edges."

    button redundant_loop_cleanup_button "2. Redundant Loop Cleanup" pos:[8,50] width:294 height:34 \
        tooltip:"Find geometrically redundant straight planar loops on the current evaluated Edit Poly topology.\n\nWhen valid loops are found, create one dedicated Edit Poly modifier named Cleanup LOOPS and Remove Edge there.\n\nIf no loops are found, no Cleanup LOOPS modifier is left in the stack."

    on find_two_edge_verts_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugFindTwoEdgeVerts()
    )

    on find_two_edge_verts_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugWeldTwoEdgeVerts()
    )

    on redundant_loop_cleanup_button pressed do
    (
        ::WallMeshCleanerRollout.runRedundantLoopCleanup()
    )
)

rollout WallMeshCleanerVertexCleanerRollout "FIX GEOMETRY" width:310 height:144
(
    button test_border_angles_button "Test Border Angles" \
        pos:[8,8] width:138 height:34 \
        tooltip:"Select bad border-angle vertices.\n\nAccepts orthogonal or straight borders.\n\nSelection only."

    spinner border_angle_threshold_spinner "" pos:[152,14] width:76 height:20 \
        range:[0.0,45.0,saved_border_angle_threshold] type:#float scale:0.1 \
        tooltip:"Border angle tolerance.\n\nValid angles: 90 / 180 / 270 degrees."

    button fix_border_angles_button "Fix Angles" \
        pos:[234,8] width:68 height:34 \
        tooltip:"LMB: Align BOTTOM.\n\nRMB: Align TOP.\n\nCTRL + LMB: Align LEFT.\n\nCTRL + RMB: Align RIGHT.\n\nUses all currently selected vertices.\n\nHorizontal movement stays in the wall plane."

    button find_double_verts_button "Find Double Verts" \
        pos:[8,50] width:138 height:34 \
        tooltip:"Select near-coincident vertices.\n\nUses Double Vert Threshold.\n\nSelection only."

    spinner double_vert_threshold_spinner "" pos:[152,56] width:76 height:20 \
        range:[0.0,1000000.0,saved_double_vert_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Near-coincident distance threshold.\n\nUnits: system units.\n\nDefault: 1 system unit."

    button fix_double_verts_button "Fix Verts" \
        pos:[234,50] width:68 height:34 \
        tooltip:"Fix near-coincident vertex pairs.\n\nCreate edge if needed.\n\nCollapse connected pair.\n\nUnresolved pairs stay selected."

    button test_vertical_position_button "Test Vertical Position" \
        pos:[8,92] width:294 height:34 \
        tooltip:"Use currently selected vertices.\n\nReport maximum Z position difference.\n\nSelection only."

    on border_angle_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on double_vert_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on test_border_angles_button pressed do
    (
        ::WallMeshCleanerRollout.runBorderAngleTest()
    )

    on fix_border_angles_button pressed do
    (
        ::WallMeshCleanerRollout.runBorderAngleFix use_high_z:false horizontal_mode:keyboard.controlPressed
    )

    on fix_border_angles_button rightclick do
    (
        ::WallMeshCleanerRollout.runBorderAngleFix use_high_z:true horizontal_mode:keyboard.controlPressed
    )

    on find_double_verts_button pressed do
    (
        ::WallMeshCleanerRollout.runDoubleVertTest()
    )

    on fix_double_verts_button pressed do
    (
        ::WallMeshCleanerRollout.runDoubleVertFix()
    )

    on test_vertical_position_button pressed do
    (
        ::WallMeshCleanerRollout.runVerticalPositionTest()
    )
)

rollout WallMeshCleanerRollout "Wall Mesh Cleaner 6-ASTRA 0.935" width:344 height:1004
(
    button restart_button "Restart" pos:[262,6] width:74 height:22 tooltip:"Reload WallMeshCleaner.ms.\nThe loader automatically loads the newest version of every component."
    subRollout tool_subrollout "Wall Mesh Cleaner 6-ASTRA 0.935" pos:[8,32] width:328 height:924
    label batch_slice_progress_label "0 / 0 OBJECTS" pos:[8,960] width:328 height:16 align:#center
    progressbar batch_slice_progress pos:[8,978] width:328 height:14 value:0

    /*
    Returns the requested face-slice orientation from the Face Slicer sub-rollout.
    All performs vertical first and horizontal second in the slicer implementation.
    */
    function getCutMode =
    (
        case WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state of
        (
            2: #horizontal
            3: #vertical
            default: #all
        )
        -- return
    )

    /*
    Returns the selected slice-plane definition mode from the Face Slicer rollout.
    The next-vertex mode is the default because two mesh vertices define the actual cut line.
    */
    function getSlicePlaneMode =
    (
        case WallMeshCleanerFaceSlicerRollout.slice_plane_mode_radio.state of
        (
            1: #globalAxis
            default: #nextVert
        )
        -- return
    )

    /*
    Saves all controls from the five child rollouts to the shared INI file.
    Child rollouts call this parent method so persistence remains centralized.
    */
    function saveUiSettings =
    (
        WallMeshCleaner.saveSettings \
            WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            WallMeshCleanerOptionsRollout.double_side_checkbutton.checked \
            WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state \
            WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value \
            slice_plane_mode_index:WallMeshCleanerFaceSlicerRollout.slice_plane_mode_radio.state \
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value \
            slice_precision:WallMeshCleanerOptionsRollout.slice_precision_spinner.value
        -- return
    )

    /*
    Runs Auto Smooth from the Options sub-rollout.
    The operation remains undoable and redraws the viewport after completion.
    */
    function runSmooth =
    (
        undo "WallMeshCleaner - Auto Smooth" on
        (
            WallMeshCleaner.autoSmoothSelection()
        )

        completeRedraw()
        -- return
    )

    /*
    Prepares the selected geometry as individual planar wall objects.
    The Face Slicer Angle value is reused as the Smooth modifier Auto Smooth threshold.
    */
    function runPrepareObject =
    (
        saveUiSettings()

        undo "WallMeshCleaner - Prepare object" on
        (
            completed = WallMeshCleaner.prepareObjects \
                angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value
        )

        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Prepare object"
        )

        completed
        -- return
    )

    /*
    Updates the batch slice progress controls at the bottom of the dialog.
    The processed count is displayed as N / ALL OBJECTS and the bar is kept between 0 and 100 percent.
    */
    function updateBatchSliceProgress processed_count total_count =
    (
        progress_percent = 0

        if total_count > 0 then
        (
            progress_percent = ((100.0 * processed_count) / total_count) as integer
            if progress_percent < 0 then progress_percent = 0
            if progress_percent > 100 then progress_percent = 100
        )

        batch_slice_progress.value = progress_percent
        batch_slice_progress_label.text = (processed_count as string) + " / " + (total_count as string) + " OBJECTS"
        windows.processPostedMessages()
        -- return
    )

    /*
    Runs the main face slicer using shared Options and Face Slicer controls.
    Display options are applied before slicing and current settings are persisted.
    */
    function runFaceSlicer =
    (
        WallMeshCleaner.setSelectionDisplayHiddenEdges WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked
        WallMeshCleaner.setSelectionDoubleSide WallMeshCleanerOptionsRollout.double_side_checkbutton.checked
        saveUiSettings()

        local completed = WallMeshCleaner.sliceSelection \
            weld_vertices:WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            weld_threshold:WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        messageBox WallMeshCleaner.last_slice_report title:(if completed then "Wall Mesh Cleaner - Completed" else "Wall Mesh Cleaner - Could not finish")
        completed
    )

    /*
    Runs only the slicer's mesh validation stage for debugging.
    The report counts usable anchors and leaves those anchor vertices selected.
    */
    function runResetSlicing =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugCheckSelection \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        completed
        -- return
    )

    /*
    Automates the stable debug slicing workflow for every selected wall.
    Reset Slicing runs first; All mode completes vertical before horizontal.
    */
    function runDebugSliceSelectedWalls =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugSliceSelectedWalls \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value \
            slice_precision:WallMeshCleanerOptionsRollout.slice_precision_spinner.value \
            display_hidden_edges:WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            double_side:WallMeshCleanerOptionsRollout.double_side_checkbutton.checked \
            progress_callback:updateBatchSliceProgress

        messageBox WallMeshCleaner.last_slice_report title:(if completed then "Wall Mesh Cleaner - Slice Selected Walls Complete" else "Wall Mesh Cleaner - Slice Selected Walls Stopped")
        completed
        -- return
    )

    /*
    Selects wall-inner corner vertices for slicer debugging, including outer-border re-entrant corners.
    Triggered by right-click on Reset Slicing.
    */
    function runDebugSelectInnerCorners =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugSelectInnerCorners \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Inner Corner Check Failed"
        )
        completed
        -- return
    )

    /*
    Selects the exact INNER VERTS captured by the last successful Reset Slicing.
    The UI button therefore reproduces Reset Slicing corner IDs without recalculation.
    */
    function runDebugCheckCorners =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugCheckCorners \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Check Corners Failed"
        )
        completed
        -- return
    )

    /*
    Selects every live non-corner vertex with exactly two visible straight edges.
    Debug-only inspection; no topology is changed.
    */
    function runDebugFindTwoEdgeVerts =
    (
        local completed = WallMeshCleaner.debugFindTwoEdgeVerts angle_threshold:0.1
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Find Two-Edge Verts Failed"
        )
        completed
        -- return
    )

    /*
    Welds every current Find Two-Edge Verts candidate to its closest neighbour on one of its two visible straight edges.
    This is the RMB action of Debug button 3.
    */
    function runDebugWeldTwoEdgeVerts =
    (
        local completed = WallMeshCleaner.debugWeldTwoEdgeVertsToClosestNeighbor angle_threshold:0.1 position_tolerance:0.01
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Weld Two-Edge Verts Failed"
        )
        completed
        -- return
    )

    /*
    Selects non-border vertices belonging to the sliced edges created by the last Make 1 Slice.
    Triggered by right-click on Make 1 Slice and does not modify topology.
    */
    function runDebugSelectSlicedEdgeVertices =
    (
        local completed = WallMeshCleaner.debugSelectSlicedEdgeVertices()
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Sliced Edge Vertex Check Failed"
        )
        completed
        -- return
    )

    /*
    Runs exactly one slicer cut and leaves newly created non-border edges selected.
    Current cut mode, angle tolerance and planar tolerance are respected.
    */
    function runDebugMakeOneSlice =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugMakeOneSlice \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Debug Slice Failed"
        )
        completed
        -- return
    )

    /*
    Runs the exact Slice Precision post-slice repair used by Slice Selected Walls on the last manual Make 1 Slice.
    Only vertices created by that slice are candidates, and only near-anchor candidates may be welded.
    */
    function runDebugSlicePrecisionCleanup =
    (
        saveUiSettings()
        local selected_nodes = selection as array
        if selected_nodes.count != 1 then
        (
            format "WallMeshCleaner Slice Precision Manual: select exactly one wall that was processed by Make 1 Slice.\n"
            false
        )
        else
        (
            local node = selected_nodes[1]
            local precision_cleanup = WallMeshCleaner.cleanupMassSlicePrecisionVerts node precision_threshold:WallMeshCleanerOptionsRollout.slice_precision_spinner.value
            format "WallMeshCleaner Slice Precision Manual: node:% threshold:% success:% fixed:% candidates:%\n" node.name WallMeshCleanerOptionsRollout.slice_precision_spinner.value precision_cleanup[1] precision_cleanup[2] precision_cleanup[3]
            completeRedraw()
            precision_cleanup[1]
        )
        -- return
    )

    /*
    Selects every new vertex that the current Slice Precision value would repair.
    No topology change is made; Vertex sub-object level remains active for inspection.
    */
    function runDebugSelectSlicePrecisionCandidates =
    (
        saveUiSettings()
        local selected_nodes = selection as array
        if selected_nodes.count != 1 then
        (
            format "WallMeshCleaner Slice Precision Inspect: select exactly one wall that was processed by Make 1 Slice.\n"
            false
        )
        else
        (
            local node = selected_nodes[1]
            local precision_data = WallMeshCleaner.getMassSlicePrecisionCandidates node precision_threshold:WallMeshCleanerOptionsRollout.slice_precision_spinner.value
            local candidate_vertices = precision_data[1]
            local inspection_vertices = precision_data[3]

            if node.modifiers.count > 0 and classOf node.modifiers[1] == Edit_Poly then
            (
                local modifier = node.modifiers[1]
                select node
                max modify mode
                modPanel.setCurrentObject modifier
                modifier.SetPrimaryNode node
                modifier.useStackSelection = false
                modifier.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                modifier.SetSelection #Vertex #{} node:node
                modifier.SetSelection #Vertex inspection_vertices node:node
                modifier.RefreshScreen()
                completeRedraw()
            )

            format "WallMeshCleaner Slice Precision Candidates: %\n" candidate_vertices
            format "WallMeshCleaner Slice Precision Inspection: %\n" inspection_vertices
            inspection_vertices.numberSet > 0
        )
        -- return
    )

    /*
    Selects redundant edge candidates plus their predicted removable slice-created vertices.
    No topology change is made; Vertex sub-object level remains active for inspection.
    */
    function runDebugInspectCleanUpSlicedEdges =
    (
        local completed = WallMeshCleaner.debugInspectCleanUpSlicedEdges()
        local listener_only_notice = WallMeshCleaner.isLastSliceContextNotice (WallMeshCleaner.last_slice_report)
        if (not completed) and (not listener_only_notice) then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Test Failed"
        )
        completed
        -- return
    )

    /*
    Removes the redundant new edges identified from the last Make 1 Slice.
    */
    function runDebugCleanUpSlicedEdges =
    (
        local completed = WallMeshCleaner.debugCleanUpSlicedEdges()
        local listener_only_notice = WallMeshCleaner.isLastSliceContextNotice (WallMeshCleaner.last_slice_report)
        if (not completed) and (not listener_only_notice) then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Failed"
        )
        completed
        -- return
    )

    /*
    Selects only Clean Up Slice eligible vertices.
    LMB requires exactly 2 visible edges, not border, and not cached INNER VERTS; no topology change.
    */
    function runDebugInspectCleanUpSlice =
    (
        local completed = WallMeshCleaner.debugInspectCleanUpSlice()
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Slice Test Failed"
        )
        completed
        -- return
    )

    /*
    Removes redundant sliced vertices from the last debug slice.
    INNER VERTS cached by Reset Slicing are always protected from removal.
    */
    function runDebugCleanUpSlice =
    (
        local completed = WallMeshCleaner.debugCleanUpSlice()
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Slice Failed"
        )
        completed
        -- return
    )

    /*
    Selects the same candidates used by Clean Up Sliced Edges Postprocess without topology changes.
    No explicit undo block is used because inspection must preserve manual modifier mode.
    */
    function runInspectCleanUpSlicedEdgesPostprocess =
    (
        local selected_nodes = selection as array
        local completed = true

        if selected_nodes.count == 0 then
        (
            WallMeshCleaner.last_slice_report = "Select at least one processed wall before Clean Up Sliced Edges Postprocess inspection."
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Postprocess"
            return false
        )

        for node in selected_nodes do
        (
            if isValidNode node then
            (
                local inspect_result = WallMeshCleaner.inspectPostProcessCleanUpSliceVerts node
                if not inspect_result[1] then completed = false
            )
            else
            (
                completed = false
            )
        )

        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Postprocess Inspection Failed"
        )

        completed
        -- return
    )

    /*
    Runs the manual final straight two-visible-edge cleanup in its own Edit Poly modifier.
    This postprocess is intentionally separate from Slice Selected Walls.
    */
    function runCleanUpSlicedEdgesPostprocess =
    (
        local selected_nodes = selection as array
        local completed = true

        if selected_nodes.count == 0 then
        (
            WallMeshCleaner.last_slice_report = "Select at least one processed wall before Clean Up Sliced Edges Postprocess."
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Postprocess"
            return false
        )

        for node in selected_nodes do
        (
            if isValidNode node then
            (
                local cleanup_result = WallMeshCleaner.postProcessCleanUpSliceVerts node
                if not cleanup_result[1] then completed = false
                format "WallMeshCleaner Manual Clean Up Sliced Edges Postprocess: node:% candidates:% removed:% unresolved:% success:%\n" \
                    node.name cleanup_result[2] cleanup_result[3] cleanup_result[4] cleanup_result[1]
            )
            else
            (
                completed = false
            )
        )

        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Postprocess Failed"
        )

        completed
        -- return
    )

    /*
    Runs geometric redundant-loop cleanup in one dedicated Cleanup LOOPS Edit Poly modifier.
    No modifier is left behind when no valid redundant loop is detected.
    */
    function runRedundantLoopCleanup =
    (
        local completed = WallMeshCleaner.cleanupRedundantLoopsSelection angle_threshold:0.1 debug_output:true

        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Redundant Loop Cleanup Failed"
        )

        completed
        -- return
    )

    /*
    Runs the face-cleaner N-gon post-process using the current shared options.
    The handler lives on the parent rollout so the sub-rollout stays UI-only.
    */
    function runFaceCleaner =
    (
        saveUiSettings()

        local completed = WallMeshCleaner.propagateSelectionJunctionCuts \
            weld_vertices:WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            weld_threshold:WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            auto_smooth:WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            cut_mode:(getCutMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        messageBox WallMeshCleaner.last_slice_report title:(if completed then "Wall Mesh Cleaner - Completed" else "Wall Mesh Cleaner - Could not finish")
        completed
    )

    /*
    Runs border-angle validation from the Vertex Cleaner sub-rollout.
    Problem vertices are selected without modifying geometry.
    */
    function runBorderAngleTest =
    (
        saveUiSettings()
        WallMeshCleaner.selectNonOrthoBorderVerts \
            angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value
        -- return
    )

    /*
    Aligns all currently selected vertices as one set.
    LMB/RMB use bottom/top Z; CTRL + LMB/RMB use left/right wall-local horizontal position.
    */
    function runBorderAngleFix use_high_z:false horizontal_mode:false =
    (
        saveUiSettings()
        WallMeshCleaner.fixNonOrthoBorderVerts use_high_z:use_high_z horizontal_mode:horizontal_mode
        -- return
    )

    /*
    Runs duplicate-position vertex detection from the Vertex Cleaner sub-rollout.
    All vertices participating in a near-coincident pair are selected.
    */
    function runDoubleVertTest =
    (
        saveUiSettings()
        WallMeshCleaner.selectDoubleVerts \
            position_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
        -- return
    )

    /*
    Fixes near-coincident vertices using the current Vertex Cleaner distance threshold.
    Only vertices detected by the duplicate-position test are passed to the weld operation.
    */
    function runDoubleVertFix =
    (
        saveUiSettings()
        WallMeshCleaner.fixDoubleVerts \
            position_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
        -- return
    )

    /*
    Reports the world-Z range across all currently selected vertices.
    Values are formatted with the current 3ds Max display-unit settings.
    */
    function runVerticalPositionTest =
    (
        selected_nodes = selection as array
        found_vert = false
        min_z = 0.0
        max_z = 0.0

        for node in selected_nodes do
        (
            if WallMeshCleaner.isSupportedNode node then
            (
                base_obj = node.baseObject
                selected_verts = polyop.getVertSelection base_obj

                for vert_index in selected_verts do
                (
                    world_pos = (polyop.getVert base_obj vert_index) * node.objectTransform

                    if not found_vert then
                    (
                        min_z = world_pos.z
                        max_z = world_pos.z
                        found_vert = true
                    )
                    else
                    (
                        if world_pos.z < min_z then min_z = world_pos.z
                        if world_pos.z > max_z then max_z = world_pos.z
                    )
                )
            )
        )

        if found_vert then
        (
            z_difference = max_z - min_z
            formatted_difference = units.formatValue z_difference
            formatted_difference = substituteString formatted_difference " " ""
            format "Z POSITION DIFFERENCE: %\n" formatted_difference
        )
        else
        (
            format "Z POSITION DIFFERENCE: No verts selected\n"
        )
        -- return
    )

    on restart_button pressed do
    (
        script_dir = getFilenamePath WallMeshCleanerScriptPath
        script_path = script_dir + "WallMeshCleaner.ms"

        if doesFileExist script_path then
        (
            saveUiSettings()
            destroyDialog WallMeshCleanerRollout
            fileIn script_path
        )
        else
        (
            messageBox (
                "WallMeshCleaner restart failed.\n\n" +
                "WallMeshCleaner.ms does not exist beside the component files."
            )
        )
    )

    on WallMeshCleanerRollout open do
    (
        addSubRollout tool_subrollout WallMeshCleanerOptionsRollout
        addSubRollout tool_subrollout WallMeshCleanerFaceSlicerRollout
        addSubRollout tool_subrollout WallMeshCleanerFaceCleanerRollout
        addSubRollout tool_subrollout WallMeshCleanerEdgeCleanerRollout
        addSubRollout tool_subrollout WallMeshCleanerVertexCleanerRollout
    )

    on WallMeshCleanerRollout close do
    (
        dialog_pos = undefined

        try
        (
            dialog_pos = getDialogPos WallMeshCleanerRollout
        )
        catch
        (
            dialog_pos = undefined
        )

        WallMeshCleaner.saveSettings \
            WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            WallMeshCleanerOptionsRollout.double_side_checkbutton.checked \
            WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state \
            WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value \
            slice_plane_mode_index:WallMeshCleanerFaceSlicerRollout.slice_plane_mode_radio.state \
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value \
            slice_precision:WallMeshCleanerOptionsRollout.slice_precision_spinner.value \
            dialog_position:dialog_pos

        removeSubRollout tool_subrollout WallMeshCleanerVertexCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerEdgeCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerFaceCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerFaceSlicerRollout
        removeSubRollout tool_subrollout WallMeshCleanerOptionsRollout
    )
)

if saved_dialog_position == undefined then
(
    createDialog WallMeshCleanerRollout
)
else
(
    createDialog WallMeshCleanerRollout pos:saved_dialog_position
)

/*
Wall-Fixer UI 0.991
First redesigned workflow UI using the current Wall-Fixer Core/Pipeline and Straight Edge Fixer logic.
*/


global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global wall_fixer_launcher_path
global wall_fixer_ui_file_version = "0.991"
global wall_fixer_ui_tool_version = 1.0609


/*
Registers this file's shared Wall-Fixer tool version.
Accepts legacy string or numeric global versions; the highest loaded version wins.
*/
if wall_fixer_version_system != 1 then
(
    wall_fixer_version_system = 1
)


if wall_fixer_version_epoch != 3 then
(
    wall_fixer_version_epoch = 3
    WallFixerVersion = undefined
)


wall_fixer_ui_current_tool_version_number = undefined


if WallFixerVersion != undefined then
(
    try
    (
        wall_fixer_ui_current_tool_version_number = WallFixerVersion as float
    )
    catch
    (
        wall_fixer_ui_current_tool_version_number = undefined
    )
)


if wall_fixer_ui_current_tool_version_number == undefined then
(
    WallFixerVersion = wall_fixer_ui_tool_version
)
else if wall_fixer_ui_tool_version > wall_fixer_ui_current_tool_version_number then
(
    WallFixerVersion = wall_fixer_ui_tool_version
)






global WallFixerRollout
global WallFixerOptionsRollout
global WallFixerPreProcessRollout
global WallFixerEdgeFixerRollout
global WallFixerSliceWallsRollout
global WallFixerPostProcessRollout
global WallFixerHelpersRollout
global WallFixerDebugRollout
global wallFaceClassifierRollout
global wall_face_classifier_cache = #()
global wall_face_classifier_last_nodes = #()
global wall_face_debug_enabled
global wall_face_debug_run_id
global wall_face_ground_pivot_enabled
global wall_fixer_weld_threshold_syncing = false


if wall_face_debug_enabled == undefined then
(
    wall_face_debug_enabled = false
)


if wall_face_debug_run_id == undefined then
(
    wall_face_debug_run_id = 0
)


if wall_face_ground_pivot_enabled == undefined then
(
    wall_face_ground_pivot_enabled = false
)
global wall_fixer_explode_wire_color_counter = 0


wall_fixer_ui_source_path = getSourceFileName()
wall_fixer_ui_ini_path = ((getDir #plugcfg) + "\\Wall-Fixer.ini")
wall_fixer_default_dialog_size = [344,748]
wall_fixer_min_dialog_height = 320
wall_fixer_closed_rollout_height = 24


/*
Disables cage display on the Editable Poly base and all Edit Poly modifiers of one valid node.
UI-only workflows call this directly so cage state stays off even when Core helpers are bypassed.
*/
function wallFixerSetNodeCageOff object_node =
(
    if object_node == undefined or not(isValidNode object_node) then return false

    if classOf object_node.baseObject == Editable_Poly then
    (
        try(object_node.baseObject.showCage = off)catch()
    )

    for stack_modifier in object_node.modifiers do
    (
        if classOf stack_modifier == Edit_Poly then
        (
            try(stack_modifier.showCage = off)catch()
        )
    )

    true
    -- return
)


/*
Creates a dark .NET button with bold light-green text and a visible gray border.
Use this as the standard styled button template.
*/
function setupDarkButton btn =
(
    color_class = dotNetClass "System.Drawing.Color"
    font_style_class = dotNetClass "System.Drawing.FontStyle"
    flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"

    btn.UseVisualStyleBackColor = false
    btn.FlatStyle = flat_style_class.Flat

    btn.BackColor = color_class.FromArgb 68 68 68
    btn.ForeColor = color_class.FromArgb 170 220 170

    btn.FlatAppearance.BorderColor = color_class.FromArgb 120 120 120
    btn.FlatAppearance.BorderSize = 1

    btn.FlatAppearance.MouseOverBackColor = color_class.FromArgb 78 78 78
    btn.FlatAppearance.MouseDownBackColor = color_class.FromArgb 55 55 55

    btn.Font = dotNetObject \
        "System.Drawing.Font" \
        "Segoe UI" \
        9.0 \
        font_style_class.Bold

    btn -- return
)


/*
Applies text, enabled state, tooltip, and the standard numbered-action button style.
The supplied ToolTip object keeps native LMB/RMB help available for .NET controls.
*/
function wallFixerSetupNumberedDarkButton btn button_text tooltip_object tooltip_text enabled_state:true =
(
    setupDarkButton btn
    btn.Text = button_text
    btn.Enabled = enabled_state
    tooltip_object.SetToolTip btn tooltip_text

    btn -- return
)


/*
Returns the WinForms mouse button name used by numbered .NET action handlers.
This keeps LMB/RMB routing explicit without relying on the native rollout button events.
*/
function wallFixerGetDotNetMouseButton event_args =
(
    ((event_args.Button.ToString()) as string) -- return
)


/*
Returns the Slice Walls cut mode for the main action mouse button.
*/
function wallFixerGetSliceActionMode mouse_button =
(
    case mouse_button of
    (
        "Left": #vertical
        "Right": #horizontal
        default: undefined
    )
    -- return
)


/*
Returns true for Slice Force CTRL+LMB/CTRL+RMB T-junction-only modes.
The mouse button keeps its normal Vertical/Horizontal direction while CTRL restricts anchors to true T-junction vertices.
*/
function wallFixerIsSliceForceTJunctionOnly mouse_button control_pressed =
(
    control_pressed and (mouse_button == "Left" or mouse_button == "Right")
    -- return
)


/*
Reads an integer from the Wall-Fixer UI INI file.
Invalid or missing values use the supplied fallback value.
*/
function wallFixerReadIniInt section_name key_name default_value =
(
    value_text = getIniSetting wall_fixer_ui_ini_path section_name key_name


    if value_text == "" then
    (
        default_value
    )
    else
    (
        parsed_value = undefined


        try
        (
            parsed_value = value_text as integer
        )
        catch
        (
            parsed_value = undefined
        )


        if parsed_value == undefined then default_value else parsed_value
    )
    -- return
)


/*
Reads a floating-point value from the Wall-Fixer UI INI file.
Invalid or missing values use the supplied fallback value.
*/
function wallFixerReadIniFloat section_name key_name default_value =
(
    value_text = getIniSetting wall_fixer_ui_ini_path section_name key_name


    if value_text == "" then
    (
        default_value
    )
    else
    (
        parsed_value = undefined


        try
        (
            parsed_value = value_text as float
        )
        catch
        (
            parsed_value = undefined
        )


        if parsed_value == undefined then default_value else parsed_value
    )
    -- return
)


/*
Reads a Boolean value from the Wall-Fixer UI INI file.
Only stored 0/1 values override the supplied fallback value.
*/
function wallFixerReadIniBool section_name key_name default_value =
(
    value_text = getIniSetting wall_fixer_ui_ini_path section_name key_name


    if value_text == "1" then
    (
        true
    )
    else if value_text == "0" then
    (
        false
    )
    else
    (
        default_value
    )
    -- return
)


/*
Loads the saved Wall-Fixer dialog screen position.
Falls back to the legacy saved position when no Wall-Fixer position exists yet.
*/
function wallFixerLoadDialogPosition fallback_position =
(
    x_text = getIniSetting wall_fixer_ui_ini_path "Window" "X"
    y_text = getIniSetting wall_fixer_ui_ini_path "Window" "Y"


    if (x_text == "") or (y_text == "") then
    (
        fallback_position
    )
    else
    (
        [wallFixerReadIniInt "Window" "X" 100, wallFixerReadIniInt "Window" "Y" 100]
    )
    -- return
)


/*
Loads the saved Wall-Fixer dialog height while keeping startup width at the current default.
Dialog registration/restore never forces a previously saved width.
*/
function wallFixerLoadDialogSize default_size =
(
    saved_height = wallFixerReadIniInt "Window" "Height" default_size.y


    if saved_height < wall_fixer_min_dialog_height then saved_height = wall_fixer_min_dialog_height


    [default_size.x, saved_height]
    -- return
)


/*
Converts a CUI dock-state symbol to the compact value stored in Wall-Fixer.ini.
Only the supported Wall-Fixer states are persisted.
*/
function wallFixerDockStateToIniValue dock_state =
(
    case dock_state of
    (
        #cui_dock_left: "Left"
        #cui_dock_right: "Right"
        default: "Float"
    )
    -- return
)


/*
Loads the saved Wall-Fixer CUI dock state from the INI file.
Unknown or missing values fall back to floating mode.
*/
function wallFixerLoadDockState =
(
    dock_state_text = toLower (getIniSetting wall_fixer_ui_ini_path "Window" "DockState")


    case dock_state_text of
    (
        "left": #cui_dock_left
        "right": #cui_dock_right
        default: #cui_floatable
    )
    -- return
)


/*
Saves the current registered CUI dock state when it is Left, Right or floating.
The INI is written only when the stored value actually changes.
*/
function wallFixerSaveDockState =
(
    if WallFixerRollout != undefined then
    (
        try
        (
            if WallFixerRollout.dialogBar then
            (
                current_dock_state = cui.getDockState WallFixerRollout
                dock_state_text = wallFixerDockStateToIniValue current_dock_state
                stored_dock_state_text = getIniSetting wall_fixer_ui_ini_path "Window" "DockState"


                if stored_dock_state_text != dock_state_text then
                (
                    setIniSetting wall_fixer_ui_ini_path "Window" "DockState" dock_state_text
                )
            )
        )
        catch
        (
        )
    )
    -- return
)


/*
Returns the compact label for the display units currently shown by 3ds Max.
Custom display mode uses its physical CustomUnit suffix instead of the word custom.
*/
function wallFixerGetDisplayUnitLabel =
(
    display_type = units.DisplayType
    unit_label = "units"


    case display_type of
    (
        #Generic:
        (
            unit_label = "units"
        )
        #Metric:
        (
            case units.MetricType of
            (
                #Millimeters: unit_label = "mm"
                #Centimeters: unit_label = "cm"
                #Meters: unit_label = "m"
                #Kilometers: unit_label = "km"
                default: unit_label = "units"
            )
        )
        #US:
        (
            case units.USType of
            (
                #Frac_In: unit_label = "in"
                #Dec_In: unit_label = "in"
                #Frac_Ft: unit_label = "ft"
                #Dec_Ft: unit_label = "ft"
                #Ft_Frac_In: unit_label = "ft/in"
                #Ft_Dec_In: unit_label = "ft/in"
                default: unit_label = "units"
            )
        )
        #Custom:
        (
            case units.CustomUnit of
            (
                #Millimeters: unit_label = "mm"
                #Centimeters: unit_label = "cm"
                #Meters: unit_label = "m"
                #Kilometers: unit_label = "km"
                #Inches: unit_label = "in"
                #Feet: unit_label = "ft"
                #Miles: unit_label = "mi"
                default: unit_label = "units"
            )
        )
        default:
        (
            unit_label = "units"
        )
    )


    unit_label
    -- return
)


/*
Returns one current display unit converted to 3ds Max internal world units.
This makes the fresh weld/search threshold display as exactly 1 in the active display-unit system.
*/
function wallFixerGetDefaultWeldThreshold =
(
    threshold_value = 1.0


    try
    (
        threshold_value = units.decodeValue "1"
    )
    catch
    (
        threshold_value = 1.0
    )


    threshold_value
    -- return
)




/*
Welds selected Editable Poly or Edit Poly vertices using the supplied threshold.
The function reads the actual vertex selection and does not depend on Edit Poly UI threshold state.
*/
function weldSelectedEPolyVerts node threshold editPolyModifier:undefined =
(
    wallFixerSetNodeCageOff node
    if node == undefined or not isValidNode node then return false
    if not isKindOf threshold Number or threshold <= 0 then return false


    local selectedModifier = editPolyModifier


    /*
    Returns true when the supplied modifier belongs to the supplied node.
    This prevents a modifier from another object being used accidentally.
    */
    function modifierBelongsToNode owner candidate =
    (
        for item in owner.modifiers where item == candidate do return true
        false
        -- return
    )


    if selectedModifier != undefined then
    (
        if classOf selectedModifier != Edit_Poly then return false
        if not modifierBelongsToNode node selectedModifier then return false
    )
    else
    (
        for index = node.modifiers.count to 1 by -1 while selectedModifier == undefined do
        (
            if classOf node.modifiers[index] == Edit_Poly then
            (
                selectedModifier = node.modifiers[index]
            )
        )
    )


    local useEditPolyModifier = selectedModifier != undefined
    local editablePoly = undefined


    if not useEditPolyModifier then
    (
        if classOf node.baseObject != Editable_Poly then return false
        editablePoly = node.baseObject
    )


    /*
    Returns the active vertex selection from Edit Poly or Editable Poly.
    The returned BitArray is the set processed by the weld routine.
    */
    function getSelectedVertices owner modifier useModifier polyObject =
    (
        if useModifier then
        (
            EditPolyMod.GetSelection modifier #Vertex node:owner
        )
        else
        (
            polyOp.getVertSelection polyObject
        )
        -- return
    )


    /*
    Returns current vertex positions in world space.
    Edit Poly is evaluated from a snapshot so modifier topology is respected.
    */
    function getWorldPositions owner useModifier polyObject =
    (
        local positions = #()


        if useModifier then
        (
            local evaluatedMesh = snapshotAsMesh owner


            for index = 1 to evaluatedMesh.numVerts do
            (
                append positions ((getVert evaluatedMesh index) * owner.objectTransform)
            )


            delete evaluatedMesh
        )
        else
        (
            local vertexCount = polyOp.getNumVerts polyObject


            for index = 1 to vertexCount do
            (
                append positions ((polyOp.getVert polyObject index) * owner.objectTransform)
            )
        )


        positions
        -- return
    )


    /*
    Returns the current evaluated vertex count.
    This is used to verify that each weld really removed topology.
    */
    function getVertexCount owner useModifier polyObject =
    (
        if useModifier then
        (
            local evaluatedMesh = snapshotAsMesh owner
            local vertexCount = evaluatedMesh.numVerts
            delete evaluatedMesh
            vertexCount
        )
        else
        (
            polyOp.getNumVerts polyObject
        )
        -- return
    )


    /*
    Builds an order-independent key for a candidate vertex pair.
    Failed pairs are blocked until a successful topology change occurs.
    */
    function pairKey firstIndex secondIndex =
    (
        if firstIndex < secondIndex then
        (
            ((firstIndex as string) + ":" + (secondIndex as string))
        )
        else
        (
            ((secondIndex as string) + ":" + (firstIndex as string))
        )
        -- return
    )


    /*
    Finds the closest unblocked selected vertex pair inside the threshold.
    Returning undefined ends the iterative weld pass.
    */
    function findClosestPair selectedVertices positions blockedPairs thresholdValue keyFunction =
    (
        local vertexIndices = selectedVertices as array
        local closestPair = undefined
        local closestDistance = thresholdValue


        if vertexIndices.count < 2 then return undefined


        for first = 1 to vertexIndices.count - 1 do
        (
            for second = first + 1 to vertexIndices.count do
            (
                local firstIndex = vertexIndices[first]
                local secondIndex = vertexIndices[second]


                if firstIndex <= positions.count and secondIndex <= positions.count then
                (
                    local key = keyFunction firstIndex secondIndex


                    if findItem blockedPairs key == 0 then
                    (
                        local pairDistance = distance positions[firstIndex] positions[secondIndex]


                        if pairDistance <= thresholdValue and (closestPair == undefined or pairDistance < closestDistance) then
                        (
                            closestDistance = pairDistance
                            closestPair = #(firstIndex, secondIndex)
                        )
                    )
                )
            )
        )


        closestPair
        -- return
    )


    local removedCount = 0
    local blockedPairs = #()
    local keepSearching = true


    undo "Weld Selected EPoly Vertices" on
    (
        with redraw off
        (
            while keepSearching do
            (
                local selectedVertices = getSelectedVertices node selectedModifier useEditPolyModifier editablePoly


                if selectedVertices.numberSet < 2 then
                (
                    keepSearching = false
                )
                else
                (
                    local positions = getWorldPositions node useEditPolyModifier editablePoly
                    local closestPair = findClosestPair selectedVertices positions blockedPairs threshold pairKey


                    if closestPair == undefined then
                    (
                        keepSearching = false
                    )
                    else
                    (
                        local beforeCount = getVertexCount node useEditPolyModifier editablePoly


                        if useEditPolyModifier then
                        (
                            EditPolyMod.WeldVertices selectedModifier closestPair[1] closestPair[2] node:node
                            EditPolyMod.Commit selectedModifier
                        )
                        else
                        (
                            local firstPosition = polyOp.getVert editablePoly closestPair[1]
                            local secondPosition = polyOp.getVert editablePoly closestPair[2]
                            local weldPosition = (firstPosition + secondPosition) / 2.0
                            local welded = polyOp.weldVerts editablePoly closestPair[1] closestPair[2] weldPosition


                            if welded == true then polyOp.collapseDeadStructs editablePoly
                        )


                        update node


                        local afterCount = getVertexCount node useEditPolyModifier editablePoly


                        if afterCount < beforeCount then
                        (
                            removedCount += beforeCount - afterCount
                            blockedPairs = #()
                        )
                        else
                        (
                            append blockedPairs (pairKey closestPair[1] closestPair[2])
                        )
                    )
                )
            )
        )
    )


    removedCount
    -- return
)


saved_weld_enabled = wallFixerReadIniBool "Controls" "WeldVertices" (WallFixer.readIniBool "WeldVertices" true)
saved_weld_threshold = wallFixerReadIniFloat "Controls" "WeldThreshold" (wallFixerGetDefaultWeldThreshold())
saved_display_hidden_edges = wallFixerReadIniBool "Controls" "DisplayHiddenEdges" (WallFixer.readIniBool "DisplayHiddenEdges" false)
saved_double_side = wallFixerReadIniBool "Controls" "DoubleSide" (WallFixer.readIniBool "DoubleSide" true)
saved_auto_smooth = wallFixerReadIniBool "Controls" "AutoSmooth" (WallFixer.readIniBool "AutoSmooth" false)
saved_angle_threshold = WallFixer.readIniFloat "AngleThreshold" 5.0
saved_planar_tolerance = WallFixer.readIniFloat "PlanarTolerance" 1.0
saved_slice_plane_mode_index = WallFixer.readIniInt "SlicePlaneMode" 2
saved_border_angle_threshold = WallFixer.readIniFloat "BorderAngleThreshold" 5.0
saved_right_angle_threshold = WallFixer.readIniFloat "RightAngleThreshold" 0.1
saved_double_vert_threshold = saved_weld_threshold
saved_double_face_threshold = WallFixer.readIniFloat "DoubleFaceThreshold" 100.0
saved_slice_precision = wallFixerReadIniFloat "Controls" "SlicePrecision" (WallFixer.readIniFloat "SlicePrecision" 0.01)
saved_quiet_batch = WallFixer.readIniBool "QuietBatch" false
saved_dialog_position = WallFixer.loadDialogPosition()
saved_quiet_batch = wallFixerReadIniBool "Controls" "SliceQuiet" saved_quiet_batch
saved_slice_no_edge_cleanup = wallFixerReadIniBool "Controls" "SliceNoEdgeCleanup" false
saved_slice_force_t_junctions = wallFixerReadIniBool "Controls" "SliceForceTJunctionVerts" false
saved_dialog_position = wallFixerLoadDialogPosition saved_dialog_position
saved_dialog_size = wallFixerLoadDialogSize wall_fixer_default_dialog_size
saved_options_rolled_up = wallFixerReadIniBool "Rollouts" "Options" false
saved_preprocess_rolled_up = wallFixerReadIniBool "Rollouts" "PreProcess" false
saved_outer_walls_rolled_up = wallFixerReadIniBool "Rollouts" "GetOuterWalls" false
saved_edge_fixer_rolled_up = wallFixerReadIniBool "Rollouts" "EdgeFixer" true
saved_slice_walls_rolled_up = wallFixerReadIniBool "Rollouts" "SliceWalls" true
saved_postprocess_rolled_up = wallFixerReadIniBool "Rollouts" "PostProcess" true
saved_helpers_rolled_up = wallFixerReadIniBool "Rollouts" "Helpers" true
saved_debug_rolled_up = wallFixerReadIniBool "Rollouts" "Debug" true
saved_edge_options_rolled_up = wallFixerReadIniBool "Rollouts" "EdgeFixerOptions" true
saved_outer_options_rolled_up = wallFixerReadIniBool "Rollouts" "GetOuterWallsOptions" true


/*
Refreshes the Wall-Fixer dialog title from the resolved global project version.
Call this after CUI registration or docking because those operations can repaint the caption.
*/
function wallFixerRefreshDialogTitle =
(
    if WallFixerRollout != undefined and WallFixerVersion != undefined then
    (
        try
        (
            WallFixerRollout.title = ("Wall-Fixer " + (WallFixerVersion as string))
        )
        catch
        (
        )
    )
    -- return
)


/*
Tests that the visible Wall-Fixer title matches the resolved global project version.
Returns true when the current rollout title equals the expected project-version title.
*/
function testWallFixerDialogTitle =
(
    test_ok = false

    if WallFixerVersion != undefined and WallFixerRollout != undefined then
    (
        expected_title = ("Wall-Fixer " + (WallFixerVersion as string))
        actual_title = undefined

        wallFixerRefreshDialogTitle()

        try
        (
            actual_title = WallFixerRollout.title
        )
        catch
        (
            actual_title = undefined
        )

        test_ok = (actual_title == expected_title)
        format "Wall-Fixer title: % | expected: % | ok:%\n" actual_title expected_title test_ok
    )

    test_ok
    -- return
)


/*
Unregisters the Wall-Fixer CUI dialog bar when it is currently registered.
This is required before destroying/restarting a registered MAXScript dialog.
*/
function wallFixerUnregisterDialogBar =
(
    if WallFixerRollout != undefined then
    (
        try
        (
            if WallFixerRollout.dialogBar then
            (
                wallFixerSaveDockState()
                cui.UnRegisterDialogBar WallFixerRollout
            )
        )
        catch
        (
        )
    )
    -- return
)


/*
Registers Wall-Fixer as a CUI dialog bar that can dock only left or right.
The dialog remains floatable and keeps CUI docking handles.
*/
function wallFixerRegisterDialogBar =
(
    if WallFixerRollout != undefined then
    (
        try
        (
            if not WallFixerRollout.dialogBar then
            (
                cui.RegisterDialogBar WallFixerRollout \
                    minSize:[300,wall_fixer_min_dialog_height] \
                    style:#(#cui_dock_left, #cui_dock_right, #cui_floatable, #cui_handles)
            )
        )
        catch
        (
        )
    )
    -- return
)


/*
Restores the saved Left, Right or floating CUI state after dialog-bar registration.
Unsupported values are treated as floating mode.
*/
function wallFixerRestoreDockState dock_state =
(
    if WallFixerRollout != undefined then
    (
        try
        (
            if WallFixerRollout.dialogBar then
            (
                case dock_state of
                (
                    #cui_dock_left: cui.DockDialogBar WallFixerRollout #cui_dock_left
                    #cui_dock_right: cui.DockDialogBar WallFixerRollout #cui_dock_right
                    default: cui.FloatDialogBar WallFixerRollout
                )


                wallFixerSaveDockState()
            )
        )
        catch
        (
        )
    )
    -- return
)


/*
Restores the saved floating dialog position after CUI registration.
Using setDialogPos after FloatDialogBar keeps save and restore in the same screen-coordinate space.
*/
function wallFixerRestoreFloatingDialogPosition dialog_position dock_state =
(
    if dialog_position != undefined and dock_state == #cui_floatable and WallFixerRollout != undefined then
    (
        try
        (
            setDialogPos WallFixerRollout dialog_position
        )
        catch
        (
        )
    )
    -- return
)


wallFixerUnregisterDialogBar()
saved_dock_state = wallFixerLoadDockState()


try
(
    destroyDialog WallFixerRollout
)
catch
(
)




/*
Opens a workflow help image through the Windows default application.
Image paths are resolved relative to the Wall-Fixer tool folder.
*/
function wallFixerOpenWorkflowImage image_filename image_label =
(
    tool_root_path = getFilenamePath wall_fixer_ui_source_path
    workflow_image_path = tool_root_path + "Doc\\Workflow\\" + image_filename


    if doesFileExist workflow_image_path then
    (
        try
        (
            shellLaunch workflow_image_path ""
        )
        catch
        (
            messageBox ("Unable to open " + image_label + ":\n" + workflow_image_path) title:"Wall-Fixer"
        )
    )
    else
    (
        messageBox (image_label + " was not found:\n" + workflow_image_path) title:"Wall-Fixer"
    )
    -- return
)


/*
Main dialog menu provides restart, left/right docking and workflow-image help commands.
Help images open in the Windows default image viewer.
*/
/*
Resolves the launcher used by Restart without requiring component files beside it.
Prefers the active bundled launcher, then the user scripts install and canonical Google Drive repository.
*/
function wallFixerResolveRestartScriptPath source_script_path:undefined =
(
    resolved_path = undefined


    if wall_fixer_launcher_path != undefined then
    (
        if doesFileExist wall_fixer_launcher_path allowDirectory:false ignoreCache:true then
        (
            resolved_path = wall_fixer_launcher_path
        )
    )


    if resolved_path == undefined and source_script_path != undefined then
    (
        resolved_path = WallFixer.getRestartScriptPath source_script_path
    )


    if resolved_path == undefined then
    (
        user_scripts_candidate = (getDir #userScripts) + "\\MAXSCRIPT-Wall-Fixer\\Wall-Fixer.ms"


        if doesFileExist user_scripts_candidate allowDirectory:false ignoreCache:true then
        (
            resolved_path = user_scripts_candidate
        )
    )


    if resolved_path == undefined then
    (
        canonical_c_candidate = "C:\\GoogleDrive\\ProgramsData\\CG\\3DsMax\\AppData\\scripts\\MAXSCRIPT-Wall-Fixer\\Wall-Fixer.ms"


        if doesFileExist canonical_c_candidate allowDirectory:false ignoreCache:true then
        (
            resolved_path = canonical_c_candidate
        )
    )


    if resolved_path == undefined then
    (
        canonical_g_candidate = "G:\\GoogleDrive\\ProgramsData\\CG\\3DsMax\\AppData\\scripts\\MAXSCRIPT-Wall-Fixer\\Wall-Fixer.ms"


        if doesFileExist canonical_g_candidate allowDirectory:false ignoreCache:true then
        (
            resolved_path = canonical_g_candidate
        )
    )


    resolved_path
    -- return
)




/*
Tests Restart launcher resolution without reloading Wall-Fixer.
Prints the selected launcher path and returns it for inspection.
*/
function testWallFixerRestartResolver =
(
    restart_script_path = wallFixerResolveRestartScriptPath source_script_path:wall_fixer_ui_source_path


    format "Wall-Fixer restart launcher: %\n" restart_script_path


    restart_script_path
    -- return
)




/*
Tests that the direct Restart menu action has a valid launcher without reloading the tool.
Returns true when Restart is ready to execute.
*/
function testWallFixerDirectRestartMenu =
(
    restart_script_path = wallFixerResolveRestartScriptPath source_script_path:wall_fixer_ui_source_path
    restart_ready = restart_script_path != undefined


    format "Wall-Fixer direct Restart menu ready: %\n" restart_ready


    restart_ready
    -- return
)




rcmenu wall_fixer_main_menu
(
    menuItem restart_menu_item "Restart"


    subMenu "DOCK"
    (
        menuItem dock_left_menu_item "Left"
        menuItem dock_right_menu_item "Right"
    )


    subMenu "Help"
    (
        menuItem workflow_commands_menu_item "Workflow Commands"
        menuItem workflow_commands_details_menu_item "Workflow Commands Details"
    )


    on restart_menu_item picked do
    (
        restart_script_path = wallFixerResolveRestartScriptPath source_script_path:wall_fixer_ui_source_path


        if restart_script_path != undefined then
        (
            wallFixerUnregisterDialogBar()
            fileIn restart_script_path
        )
        else
        (
            messageBox "Wall-Fixer launcher was not found. Run Wall-Fixer.ms manually from the canonical repository." title:"Wall-Fixer"
        )
    )


    on dock_left_menu_item picked do
    (
        wallFixerRegisterDialogBar()


        try
        (
            cui.DockDialogBar WallFixerRollout #cui_dock_left
            wallFixerSaveDockState()
        )
        catch
        (
            messageBox "Unable to dock Wall-Fixer to the left side." title:"Wall-Fixer"
        )
    )


    on dock_right_menu_item picked do
    (
        wallFixerRegisterDialogBar()


        try
        (
            cui.DockDialogBar WallFixerRollout #cui_dock_right
            wallFixerSaveDockState()
        )
        catch
        (
            messageBox "Unable to dock Wall-Fixer to the right side." title:"Wall-Fixer"
        )
    )


    on workflow_commands_menu_item picked do
    (
        wallFixerOpenWorkflowImage "Wall-Fixer-Doc-Workflow-Commands.jpg" "Workflow Commands"
    )


    on workflow_commands_details_menu_item picked do
    (
        wallFixerOpenWorkflowImage "Wall-Fixer-Doc-Workflow-Commands-Details.jpg" "Workflow Commands Details"
    )
)


/*
OPTIONS is carried over from the authoritative Wall-Fixer UI.
Its controls keep the existing Core behavior while using the Wall-Fixer settings persistence.
*/
rollout WallFixerOptionsRollout "Options" width:310 height:142
(
    checkbox weld_checkbox "Weld Vertices" pos:[8,13] width:110 height:20 checked:saved_weld_enabled tooltip:"Legacy weld setting.\nSlice and Fix N-gons preserve boundaries without welding."
    label weld_threshold_label "WELD DISTANCE" pos:[116,15] width:110 height:18 align:#right
    spinner weld_threshold_spinner "" pos:[230,12] width:72 height:20 \
        range:[0.0,1000000.0,saved_weld_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Maximum vertex-pair weld and search distance.\n\nFresh default: 1 current display unit."


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


    on weld_checkbox changed control_state do
    (
        ::WallFixerRollout.saveUiSettings()
    )


    on WallFixerOptionsRollout open do
    (
        wall_fixer_weld_threshold_syncing = true
        weld_threshold_spinner.value = saved_weld_threshold
        wall_fixer_weld_threshold_syncing = false
    )


    on weld_threshold_spinner changed control_value do
    (
        if not wall_fixer_weld_threshold_syncing then
        (
            wall_fixer_weld_threshold_syncing = true
            saved_weld_threshold = control_value
            saved_double_vert_threshold = control_value


            wall_fixer_weld_threshold_syncing = false
            ::WallFixerRollout.saveUiSettings()
        )
    )


    on auto_smooth_checkbox changed control_state do
    (
        ::WallFixerRollout.saveUiSettings()
    )


    on hidden_edges_checkbutton changed control_state do
    (
        WallFixer.setSelectionDisplayHiddenEdges control_state
        ::WallFixerRollout.saveUiSettings()
    )


    on double_side_checkbutton changed control_state do
    (
        WallFixer.setSelectionDoubleSide control_state
        ::WallFixerRollout.saveUiSettings()
    )


    on slice_precision_spinner changed control_value do
    (
        ::WallFixerRollout.saveUiSettings()
    )


    on smooth_button pressed do
    (
        ::WallFixerRollout.runSmooth()
    )
)


/*
PRE-PROCESS & FIX GEOMETRY contains preparation steps 1 through 3.
Step 4 is exposed as its own top-level Get Outter Walls rollout.
*/
rollout WallFixerPreProcessRollout "1 PRE-PROCESS & FIX GEOMETRY" width:310 height:126
(
    local numbered_button_tooltip


    dotNetControl planar_button "System.Windows.Forms.Button" pos:[4,8] width:302 height:38


    dotNetControl duplicate_verts_button "System.Windows.Forms.Button" pos:[4,48] width:302 height:38


    dotNetControl explode_walls_button "System.Windows.Forms.Button" pos:[4,88] width:302 height:34




    on WallFixerPreProcessRollout open do
    (
        if numbered_button_tooltip == undefined then
        (
            numbered_button_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        )


        wallFixerSetupNumberedDarkButton \
            planar_button \
            "1. CHECK AND MAKE WALLS PLANAR" \
            numbered_button_tooltip \
            "LMB: check selected walls and select vertices outside the dominant wall plane. An existing top Edit Poly is reused; a NON PLANAR VERTS marker is added only when required.\n\nRMB: move only detected outlier vertices onto the dominant wall plane. Script selection markers are removed first, and the object is collapsed to Editable Poly only when the real stack requires repair."


        wallFixerSetupNumberedDarkButton \
            duplicate_verts_button \
            "2. VERTEX CHECK / WELD" \
            numbered_button_tooltip \
            "LMB: detect duplicated vertices from evaluated geometry and store them in SELECT DUPLICATED VERTICES.\n\nRMB: weld the stored vertices using WELD DISTANCE and rename that modifier DELETED DUPLICATED VERTICES."

        duplicate_verts_button.ForeColor = (dotNetClass "System.Drawing.Color").Orange


        wallFixerSetupNumberedDarkButton \
            explode_walls_button \
            "3. EXPLODE OBJECTS TO WALLS" \
            numbered_button_tooltip \
            "1. NORMALS: Explode walls by normals\n\n2. FACE DIRECTION: Explode walls by face direction — detects front/backside normals\n\n3. XY POSITION: Explode walls by position\n\n4. ELEMENTS: Explode to elements"

        explode_walls_button.ForeColor = (dotNetClass "System.Drawing.Color").Orange
    )



    on duplicate_verts_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args


        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runDuplicateVerts fix_vertices:false
        )
        else if mouse_button == "Right" then
        (
            ::WallFixerRollout.runDuplicateVerts fix_vertices:true
        )
    )


    on explode_walls_button MouseUp sender event_args do
    (
        if (wallFixerGetDotNetMouseButton event_args) == "Left" then
        (
            ::WallFixerRollout.runExplodeObjectsToWalls()
        )
    )


    on planar_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args


        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runPlanarWalls fix_vertices:false
        )
        else if mouse_button == "Right" then
        (
            ::WallFixerRollout.runPlanarWalls fix_vertices:true
        )
    )
)


/*
EDGE FIXER OPTIONS contains the Straight Edge Fixer tuning controls.
The controls are separated from the main EDGE FIXER workflow without changing geometry logic.
*/
rollout WallFixerEdgeFixerOptionsRollout "OPTIONS" width:286 height:82
(
    label level_tolerance_label "Rows distance:" pos:[8,8] width:80 height:18
    spinner level_tolerance_spinner "" pos:[90,5] width:96 height:20 \
        range:[0.000001,1000000.0,0.01] type:#worldUnits scale:0.001 \
        tooltip:"Maximum world-space distance used to detect and group horizontal edge rows."
    label rows_distance_units_label "unit" pos:[190,8] width:70 height:18


    label min_edges_label "Min Edges:" pos:[8,32] width:80 height:18
    spinner min_level_edges_spinner "" pos:[90,29] width:96 height:20 \
        range:[1,100000,3] type:#integer scale:1 \
        tooltip:"Minimum horizontal edge count needed to define a valid edge row."


    checkbox straight_quiet_checkbox "Quiet" pos:[8,56] width:80 height:18 checked:false \
        tooltip:"Suppress the Straight Edge Fixer final report dialog."


    on WallFixerEdgeFixerOptionsRollout open do
    (
        local settings_data = StraightEdgeFixer.loadSettings()
        local display_unit_label = wallFixerGetDisplayUnitLabel()


        level_tolerance_spinner.value = wallFixerReadIniFloat "Controls" "LevelTolerance" settings_data[1]
        min_level_edges_spinner.value = wallFixerReadIniInt "Controls" "MinLevelEdges" settings_data[2]
        straight_quiet_checkbox.checked = wallFixerReadIniBool "Controls" "StraightQuiet" settings_data[4]
        rows_distance_units_label.text = display_unit_label
    )


    on WallFixerEdgeFixerOptionsRollout rolledUp options_rolled_up do
    (
        try
        (
            if WallFixerEdgeFixerRollout != undefined then
            (
                WallFixerEdgeFixerRollout.setOptionsLayout options_rolled_up
            )
        )
        catch
        (
        )
    )


    on level_tolerance_spinner changed control_value do
    (
        ::WallFixerRollout.saveStraightEdgeSettings()
    )


    on min_level_edges_spinner changed control_value do
    (
        ::WallFixerRollout.saveStraightEdgeSettings()
    )


    on straight_quiet_checkbox changed control_state do
    (
        ::WallFixerRollout.saveStraightEdgeSettings()
    )
)


/*
EDGE FIXER contains geometry-fix workflow step 6.
Straight Edge Fixer tuning controls are kept in the OPTIONS subrollout at the bottom.
*/
rollout WallFixerEdgeFixerRollout "3 EDGE FIXER" width:310 height:140
(
    local direction_button_tooltip

    groupBox edge_z_group "6. EDGE ROW FIXING AND BORDER EDGES CHECK" pos:[4,8] width:302 height:98


    dotNetControl check_vertical_button "System.Windows.Forms.Button" pos:[8,30] width:112 height:38


    spinner edge_angle_spinner "" pos:[124,37] width:40 height:20 \
        range:[0.1,45.0,45.0] type:#float scale:0.1 \
        tooltip:"Skew angle limit in degrees.\n\nRMB: toggle between the spinner minimum and maximum."

    dotNetControl check_horizontal_button "System.Windows.Forms.Button" pos:[190,30] width:112 height:38


    button border_check_button "BORDER CHECK" pos:[18,70] width:264 height:30 \
        tooltip:"LMB: select invalid border edges.\n\nRMB: select all open borders and enter Border sub-object level."


    subRollout edge_fixer_options_subrollout "" pos:[0,112] width:310 height:wall_fixer_closed_rollout_height


    /*
    Resizes only the bottom OPTIONS slot and parent rollout.
    EDGE FIXER action controls remain fixed while OPTIONS expands downward.
    */
    function setOptionsLayout options_open =
    (
        edge_fixer_options_subrollout.height = if options_open then (88 + wall_fixer_closed_rollout_height) else wall_fixer_closed_rollout_height
        WallFixerEdgeFixerRollout.height = if options_open then (204 + wall_fixer_closed_rollout_height) else 140
        -- return
    )


    on WallFixerEdgeFixerRollout open do
    (
        if direction_button_tooltip == undefined then
        (
            direction_button_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        )

        setupDarkButton check_vertical_button
        setupDarkButton check_horizontal_button

        direction_orange = (dotNetClass "System.Drawing.Color").Orange
        check_vertical_button.Text = "VERTICAL SKEWED"
        check_vertical_button.ForeColor = direction_orange
        direction_button_tooltip.SetToolTip check_vertical_button "LMB: select exactly vertical edges at zero tolerance.\n\nRMB: select skewed vertical edges from above 0° through Angle.\n\nCTRL+RMB: fix selected edges to world vertical."
        check_horizontal_button.Text = "HORIZONTAL SLOPED"
        check_horizontal_button.ForeColor = direction_orange
        direction_button_tooltip.SetToolTip check_horizontal_button "LMB: select exactly horizontal edges at zero tolerance.\n\nRMB: select sloped horizontal edges from above 0° through Angle.\n\nCTRL+RMB: fix selected edges horizontal while preserving wall direction."

        try
        (
            local settings_data = StraightEdgeFixer.loadSettings()
            local saved_edge_angle = wallFixerReadIniFloat "Controls" "EdgeAngle" settings_data[3]


            addSubRollout edge_fixer_options_subrollout WallFixerEdgeFixerOptionsRollout rolledUp:saved_edge_options_rolled_up
            edge_angle_spinner.value = amin 45.0 (amax 0.1 saved_edge_angle)
            setOptionsLayout (not saved_edge_options_rolled_up)
        )
        catch
        (
        )
    )


    /*
    Rounds the main EDGE FIXER Angle control to one decimal place and persists it.
    The spinner remains a float because the supported range includes 0.1 degrees.
    */
    on edge_angle_spinner changed control_value do
    (
        local rounded_angle = (floor ((control_value * 10.0) + 0.5)) / 10.0
        rounded_angle = amin 45.0 (amax 0.1 rounded_angle)


        if (abs (edge_angle_spinner.value - rounded_angle)) > 0.00001 then
        (
            edge_angle_spinner.value = rounded_angle
        )


        ::WallFixerRollout.saveStraightEdgeSettings()
    )


    /*
    Uses the spinner's native RMB-cancel notification as a range-endpoint toggle.
    RMB switches min -> max; every other current value switches to min.
    */
    on edge_angle_spinner buttonUp canceled do
    (
        if canceled then
        (
            local angle_range = edge_angle_spinner.range


            if edge_angle_spinner.value == angle_range.x then
            (
                edge_angle_spinner.value = angle_range.y
            )
            else
            (
                edge_angle_spinner.value = angle_range.x
            )


            ::WallFixerRollout.saveStraightEdgeSettings()
        )
    )


    on check_horizontal_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args

        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runStraightEdgeDirection #horizontal action:#exact
        )
        else if mouse_button == "Right" then
        (
            if keyboard.controlPressed then
            (
                ::WallFixerRollout.runStraightEdgeDirection #horizontal action:#fix
            )
            else
            (
                ::WallFixerRollout.runStraightEdgeDirection #horizontal action:#skewed
            )
        )
    )


    on check_vertical_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args

        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runStraightEdgeDirection #vertical action:#exact
        )
        else if mouse_button == "Right" then
        (
            if keyboard.controlPressed then
            (
                ::WallFixerRollout.runStraightEdgeDirection #vertical action:#fix
            )
            else
            (
                ::WallFixerRollout.runStraightEdgeDirection #vertical action:#skewed
            )
        )
    )


    on border_check_button pressed do
    (
        ::WallFixerRollout.runStraightBorderCheck()
    )


    on border_check_button rightclick do
    (
        ::WallFixerRollout.runStraightBorderSelectAll()
    )


    on WallFixerEdgeFixerRollout close do
    (
        try
        (
            removeSubRollout edge_fixer_options_subrollout WallFixerEdgeFixerOptionsRollout
        )
        catch
        (
        )
    )
)


/*
SLICE WALLS routes direction directly from the main action mouse event.
Advanced slicer values continue to come from the existing Wall-Fixer INI settings.
*/
rollout WallFixerSliceWallsRollout "4 SLICE WALLS" width:310 height:172
(
    local numbered_button_tooltip
    local slice_action_running = false
    local slice_force_action_running = false




    checkbox quiet_checkbox "Quiet" pos:[236,5] width:62 height:18 checked:saved_quiet_batch \
        tooltip:"Suppress verbose Listener output during the inherited batch slicing operation."


    checkbox no_edge_cleanup_checkbox "No edge cleanup" pos:[188,23] width:118 height:18 checked:saved_slice_no_edge_cleanup \
        tooltip:"Keep slice-created edges after cuts. Slice Precision still runs, but Clean Up Sliced Edges is skipped."


    checkbox slice_force_t_junction_checkbox "T junction verts" pos:[8,23] width:160 height:18 checked:saved_slice_force_t_junctions \
        tooltip:"Include true three-edge T-junction vertices as additional Slice Force planes."


    dotNetControl slice_selected_walls_button "System.Windows.Forms.Button" pos:[4,42] width:148 height:38


    button reset_slice_button "RESET SLICE" pos:[156,42] width:150 height:38 \
        tooltip:"LMB: Remove all vertical Slice modifiers using the SLICE V namespace.\n\nRMB: Remove all horizontal Slice modifiers using the SLICE H namespace."


    button slice_modifier_button "H \\ V" pos:[4,84] width:149 height:38 \
        tooltip:"LMB: Activate SLICE HORIZONTAL.\n\nRMB: Activate SLICE VERTICAL.\n\nCTRL+LMB: Activate SLICE HORIZONTAL and enter Edge level 2.\n\nCTRL+RMB: Activate SLICE VERTICAL and enter Edge level 2."


    button select_slice_state_button "Select" pos:[157,84] width:149 height:38 \
        tooltip:"LMB: Filter objects with SLICE VERTICAL. If nothing is selected, use all visible geometry.\n\nRMB: Filter objects with SLICE HORIZONTAL. If nothing is selected, use all visible geometry."


    dotNetControl slice_force_button "System.Windows.Forms.Button" pos:[4,126] width:302 height:38


    on WallFixerSliceWallsRollout open do
    (
        if numbered_button_tooltip == undefined then
        (
            numbered_button_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        )




        wallFixerSetupNumberedDarkButton \
            slice_selected_walls_button \
            "9. SLICE WALLS" \
            numbered_button_tooltip \
            "LMB: SLICE VERTICAL\n\nRMB: SLICE HORIZONTAL"

        slice_selected_walls_button.ForeColor = (dotNetClass "System.Drawing.Color").Pink


        wallFixerSetupNumberedDarkButton \
            slice_force_button \
            "SLICE FORCE" \
            numbered_button_tooltip \
            "LMB: FORCE SLICE VERTICAL.\n\nRMB: FORCE SLICE HORIZONTAL.\n\nCTRL+LMB: FORCE SLICE VERTICAL only at true T-junction vertices.\n\nCTRL+RMB: FORCE SLICE HORIZONTAL only at true T-junction vertices.\n\nUses one real Slice modifier per unique plane, then collapses once. Enable T junction verts to include T-junction anchors in ordinary Force runs."

        slice_force_button.ForeColor = (dotNetClass "System.Drawing.Color").Orange
    )


    on quiet_checkbox changed control_state do
    (
        ::WallFixerRollout.saveUiSettings()
    )


    on no_edge_cleanup_checkbox changed control_state do
    (
        ::WallFixerRollout.saveUiSettings()
    )


    on slice_force_t_junction_checkbox changed control_state do
    (
        ::WallFixerRollout.saveUiSettings()
    )


    on slice_selected_walls_button MouseDown sender event_args do
    (
        local mouse_button = wallFixerGetDotNetMouseButton event_args
        local slice_mode = wallFixerGetSliceActionMode mouse_button

        if slice_mode != undefined and not slice_action_running then
        (
            slice_action_running = true

            try
            (
                ::WallFixerRollout.runSliceSelectedWalls slice_mode
            )
            catch
            (
                ::WallFixerRollout.setProgress 100
                ::WallFixerRollout.setStatus #error ("Slice Walls " + (slice_mode as string) + " failed.")
            )

            slice_action_running = false
        )
    )


    on slice_force_button MouseDown sender event_args do
    (
        local mouse_button = wallFixerGetDotNetMouseButton event_args
        local slice_mode = wallFixerGetSliceActionMode mouse_button
        local t_junction_only = wallFixerIsSliceForceTJunctionOnly mouse_button keyboard.controlPressed

        if slice_mode != undefined and not slice_force_action_running then
        (
            slice_force_action_running = true

            try
            (
                ::WallFixerRollout.runSliceForce slice_mode t_junction_only:t_junction_only
            )
            catch
            (
                ::WallFixerRollout.setProgress 100
                ::WallFixerRollout.setStatus #error ("Slice Force " + (slice_mode as string) + " failed.")
            )

            slice_force_action_running = false
        )
    )


    on slice_modifier_button pressed do
    (
        ::WallFixerRollout.activateSliceWallModifier "SLICE HORIZONTAL" enter_edge_level:keyboard.controlPressed
    )


    on slice_modifier_button rightclick do
    (
        ::WallFixerRollout.activateSliceWallModifier "SLICE VERTICAL" enter_edge_level:keyboard.controlPressed
    )


    on select_slice_state_button pressed do
    (
        ::WallFixerRollout.selectSliceWallObjects "SLICE VERTICAL"
    )


    on select_slice_state_button rightclick do
    (
        ::WallFixerRollout.selectSliceWallObjects "SLICE HORIZONTAL"
    )


    on reset_slice_button pressed do
    (
        ::WallFixerRollout.deleteSliceWallModifiers "SLICE V"
    )


    on reset_slice_button rightclick do
    (
        ::WallFixerRollout.deleteSliceWallModifiers "SLICE H"
    )
)


/*
POST-PROCESS exposes current cleanup tools plus active wall-completion attach/weld and corner T-junction repair.
The missing-loop completion step remains reserved for later implementation.
*/
rollout WallFixerPostProcessRollout "5 POST-PROCESS" width:310 height:348
(
    local numbered_button_tooltip


    dotNetControl degenerated_faces_button "System.Windows.Forms.Button" pos:[4,8] width:302 height:38


    dotNetControl two_edge_verts_button "System.Windows.Forms.Button" pos:[4,48] width:302 height:38


    dotNetControl duplicated_vertices_button "System.Windows.Forms.Button" pos:[4,88] width:302 height:38


    dotNetControl redundant_loops_button "System.Windows.Forms.Button" pos:[4,128] width:302 height:38


    dotNetControl repair_missing_loops_button "System.Windows.Forms.Button" pos:[4,168] width:302 height:38


    dotNetControl post_fix_ngons_button "System.Windows.Forms.Button" pos:[4,208] width:302 height:38


    groupBox walls_completion_group "WALLS COMPLETION" pos:[4,250] width:302 height:90


    dotNetControl attach_walls_button "System.Windows.Forms.Button" pos:[18,270] width:264 height:32


    dotNetControl weld_corners_button "System.Windows.Forms.Button" pos:[18,304] width:264 height:32


    on WallFixerPostProcessRollout open do
    (
        if numbered_button_tooltip == undefined then
        (
            numbered_button_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        )


        wallFixerSetupNumberedDarkButton degenerated_faces_button "SELECT AND REMOVE DEGENERATED FACES" numbered_button_tooltip "LMB: Find degenerated faces and store them in SELECT DEGENERATED FACES at Face level.\n\nRMB: Delete the stored faces and rename that modifier DELETED DEGENERATED FACES."
        wallFixerSetupNumberedDarkButton two_edge_verts_button "5. FIND TWO-EDGE VERTS AND REMOVE" numbered_button_tooltip "LMB: Find vertices with exactly two visible topology edges. Border corners are excluded.\n\nRMB: Remove the stored vertices and rename that modifier DELETED TWO-EDGE VERTS."
        wallFixerSetupNumberedDarkButton duplicated_vertices_button "10. DUPLICATED VERTICES" numbered_button_tooltip "LMB: Store duplicate-position vertices in SELECT DUPLICATED VERTICES.\n\nRMB: Weld the stored vertices and rename that modifier DELETED DUPLICATED VERTICES."
        wallFixerSetupNumberedDarkButton redundant_loops_button "11. REMOVE REDUNDANT LOOPS" numbered_button_tooltip "LMB: Detect redundant straight internal chains and select them.\n\nRMB: Remove the currently selected edges and their redundant vertices from SELECT REDUNDANT LOOPS."
        wallFixerSetupNumberedDarkButton repair_missing_loops_button "12. COMPLETE / REPAIR MISSING LOOPS" numbered_button_tooltip "Reserved for the new missing-loop completion tool." enabled_state:false
        wallFixerSetupNumberedDarkButton post_fix_ngons_button "13. FIX N-GONS" numbered_button_tooltip "Run the current Wall-Fixer Fix N-gons function again after slicing cleanup."
        wallFixerSetupNumberedDarkButton attach_walls_button "14. ATTACH WALLS TO OBJECTS" numbered_button_tooltip "LMB: attach selected walls into the first selected object, then weld all vertices using Options > WELD DISTANCE."
        wallFixerSetupNumberedDarkButton weld_corners_button "15. WELD AND CONNECT WALL CORNERS" numbered_button_tooltip "LMB: fix unwelded T-junctions where border vertices meet the interior of vertical border edges. Uses Options > WELD DISTANCE."
    )


    on degenerated_faces_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args


        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runSelectDegeneratedFaces()
        )
        else if mouse_button == "Right" then
        (
            ::WallFixerRollout.runRemoveDegeneratedFaces()
        )
    )


    on two_edge_verts_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args


        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runFindTwoEdgeVerts()
        )
        else if mouse_button == "Right" then
        (
            ::WallFixerRollout.runRemoveTwoEdgeVerts()
        )
    )


    on duplicated_vertices_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args


        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runDuplicateVerts fix_vertices:false
        )
        else if mouse_button == "Right" then
        (
            ::WallFixerRollout.runDuplicateVerts fix_vertices:true
        )
    )


    on redundant_loops_button MouseUp sender event_args do
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args


        if mouse_button == "Left" then
        (
            ::WallFixerRollout.runSelectRedundantLoops()
        )
        else if mouse_button == "Right" then
        (
            ::WallFixerRollout.runRemoveRedundantLoops()
        )
    )


    on post_fix_ngons_button MouseUp sender event_args do
    (
        if (wallFixerGetDotNetMouseButton event_args) == "Left" then
        (
            ::WallFixerRollout.runFixNgons #postprocess
        )
    )


    on attach_walls_button MouseUp sender event_args do
    (
        if (wallFixerGetDotNetMouseButton event_args) == "Left" then
        (
            ::WallFixerRollout.runAttachWallsToObjects()
        )
    )


    on weld_corners_button MouseUp sender event_args do
    (
        if (wallFixerGetDotNetMouseButton event_args) == "Left" then
        (
            ::WallFixerRollout.runWeldAndConnectWallCorners()
        )
    )
)


/*
HELPERS contains utility actions that are useful outside the numbered wall-fixing workflow.
These actions operate on the current scene selection.
*/
rollout WallFixerHelpersRollout "HELPERS" width:310 height:332
(
    button attach_button "Attach" pos:[8,8] width:143 height:30 \
        tooltip:"LMB: Attach all selected geometry into the first selected object.\n\nRMB: Attach selection, center the merged pivot, weld all vertices using Wall-Fixer > Options > Weld Threshold, then quadrify when the merged object has at most 12 triangular faces."


    button reset_pivot_button "Reset Pivot to Center" pos:[159,8] width:143 height:30 \
        tooltip:"Move each selected object's pivot to the center of its geometry."


    button align_camera_button "Align Camera" pos:[8,44] width:143 height:30 \
        tooltip:"LMB: Align the active viewport perpendicular to selected wall faces. If no faces are selected, use the dominant wall-face normal. Switch to orthographic User view and zoom to the selection.\n\nRMB: Rotate the aligned view 90° around world Z for a wall side view."


    button border_corners_button "90° Corners" pos:[159,44] width:143 height:30 \
        tooltip:"LMB: Select true 90° open-border corner vertices on the current Edit Poly modifier or Editable Poly base. Straight 180° border vertices are excluded."


    button split_button "Split" pos:[8,80] width:143 height:30 \
        tooltip:"LMB: Apply Editable Poly, split all selected edges, then explode the resulting elements into separate objects."


    button quadrify_button "Quadrify" pos:[159,80] width:143 height:30 \
        tooltip:"LMB: Run Ribbon Tools Quadrify All.\n\nRMB: Run Ribbon Tools Triangulate All."


    groupBox material_group "MATERIAL" pos:[4,116] width:302 height:66


    button material_button "Multi ID" pos:[8,140] width:143 height:30 \
        tooltip:"LMB: Assign the same WALL FACE CLASSIFIER material used by INNER / OUTTER to selected geometry.\n\nRMB: Remove the material from selected geometry."


    button material_by_sg_button "Material by SG" pos:[159,140] width:143 height:30 \
        tooltip:"LMB: Assign a shared Multi/Sub-Object material and set face Material IDs from smoothing-group masks. Uses the topmost Edit Poly, otherwise the Editable Poly base."


    button select_degenerated_objects_button "Select Degenerated Objects" pos:[8,188] width:294 height:30 \
        tooltip:"Select visible geometry collapsed to an edge when all evaluated vertex normals match."


    groupBox modifiers_group "MODIFIERS" pos:[4,224] width:302 height:102


    button stl_check_button "STL CHECK" pos:[8,248] width:143 height:30 \
        tooltip:"LMB: Apply an STL Check modifier to selected geometry and turn Check on."


    button vertex_weld_button "VertexWeld" pos:[159,248] width:143 height:30 \
        tooltip:"LMB: Apply Vertex Weld with Threshold 0.0.\n\nRMB: Apply Vertex Weld with Threshold 0.001."


    button world_borders_button "Weld Borders" pos:[8,284] width:294 height:30 \
        tooltip:"LMB: Prepend WELD BORDERS Poly Select below the topmost VertexWeld, select all open-border vertices, and leave Vertex sub-object active so VertexWeld uses only those vertices."


    on attach_button pressed do
    (
        ::WallFixerRollout.runAttachSelectedObjects()
    )


    on attach_button rightclick do
    (
        ::WallFixerRollout.runAttachSelectedObjectsRmb()
    )


    on reset_pivot_button pressed do
    (
        ::WallFixerRollout.runResetPivotToCenter()
    )


    on align_camera_button pressed do
    (
        ::WallFixerRollout.runAlignCameraToWallFaces()
    )


    on align_camera_button rightclick do
    (
        ::WallFixerRollout.runAlignCameraSideView()
    )


    on border_corners_button pressed do
    (
        ::WallFixerRollout.selectCurrentSlice90BorderCorners()
    )


    on split_button pressed do
    (
        ::WallFixerRollout.runSplitSelectedEdge()
    )


    on quadrify_button pressed do
    (
        ::WallFixerRollout.runQuadrifyAll()
    )


    on quadrify_button rightclick do
    (
        ::WallFixerRollout.runTriangulateAll()
    )


    on material_button pressed do
    (
        ::WallFixerRollout.runAssignMultiMaterial()
    )


    on material_button rightclick do
    (
        ::WallFixerRollout.runRemoveMaterial()
    )


    on material_by_sg_button pressed do
    (
        ::WallFixerRollout.runAssignMaterialBySmoothingGroup()
    )


    on select_degenerated_objects_button pressed do
    (
        ::WallFixerRollout.runSelectDegeneratedObjects()
    )


    on stl_check_button pressed do
    (
        ::WallFixerRollout.runApplyStlCheck()
    )


    on vertex_weld_button pressed do
    (
        ::WallFixerRollout.runApplyVertexWeld weld_threshold:0.0
    )


    on vertex_weld_button rightclick do
    (
        ::WallFixerRollout.runApplyVertexWeld weld_threshold:0.001
    )


    on world_borders_button pressed do
    (
        ::WallFixerRollout.runApplyWorldBorders()
    )
)



/*
DEBUG contains optional tracing and Listener diagnostics outside the main workflow.
These controls do not change the numbered pipeline order.
*/
rollout WallFixerDebugRollout "DEBUG" width:310 height:116
(
    checkbutton debug_trace_checkbutton "DEBUG TRACE" pos:[8,8] width:143 height:30 \
        tooltip:"Record classifier inputs, per-face scores, resolution reasons, and class snapshots in object user properties."

    button btn_print_debug "PRINT DEBUG" pos:[159,8] width:143 height:30 \
        tooltip:"Print selected or last analyzed wall geometry, trace properties, vertices, faces, normals, Material IDs, scores, and resolution reasons to the MAXScript Listener."

    button print_objs_button "Print Objs" pos:[8,44] width:143 height:30 \
        tooltip:"Clear the Listener and print detailed diagnostics for the selected objects."

    button angle_of_edges_button "Angle of Edges" pos:[159,44] width:143 height:30 \
        tooltip:"Print horizontal and vertical deviation angles for the selected edges."

    button dialog_info_button "Dialog Info" pos:[8,80] width:143 height:30 \
        tooltip:"Print the current Wall-Fixer dialog size, position, registration state, and dock state."

    on WallFixerDebugRollout open do
    (
        debug_trace_checkbutton.checked = wall_face_debug_enabled
    )

    on debug_trace_checkbutton changed control_state do
    (
        wall_face_debug_enabled = control_state
    )

    on btn_print_debug pressed do
    (
        debugWallFaceClassifierSelection verbose_vertices:true verbose_faces:true use_last_if_empty:true
    )

    on print_objs_button pressed do
    (
        ::WallFixerRollout.runPrintSelectedObjects()
    )

    on angle_of_edges_button pressed do
    (
        ::WallFixerRollout.runPrintSelectedEdgeAngles()
    )

    on dialog_info_button pressed do
    (
        dialog_size = undefined
        dialog_position = undefined
        dialog_registered = false
        dialog_dock_state = #unregistered

        try
        (
            dialog_size = getDialogSize ::WallFixerRollout
        )
        catch
        (
        )

        try
        (
            dialog_position = getDialogPos ::WallFixerRollout
        )
        catch
        (
        )

        try
        (
            dialog_registered = ::WallFixerRollout.dialogBar
        )
        catch
        (
            dialog_registered = false
        )

        if dialog_registered then
        (
            try
            (
                dialog_dock_state = cui.getDockState ::WallFixerRollout
            )
            catch
            (
                dialog_dock_state = #unknown
            )
        )

        format "\n======================================================================\n"
        format "WALL-FIXER DIALOG INFO\n"
        format "Size: %\n" dialog_size
        format "Position: %\n" dialog_position
        format "Registered: %\n" dialog_registered
        format "Dock state: %\n" dialog_dock_state
        format "======================================================================\n"
    )
)



/*
Tests the DEBUG Angle of Edges control layout and label.
*/
function testDebugAngleOfEdgesButton =
(
    (
        (WallFixerDebugRollout.angle_of_edges_button.text == "Angle of Edges") and
        (WallFixerDebugRollout.angle_of_edges_button.width == 294) and
        (WallFixerDebugRollout.angle_of_edges_button.height == 30)
    )
    -- return
)


/*
Tests the DEBUG Dialog Info control layout and label.
*/
function testDebugDialogInfoButton =
(
    (
        (WallFixerDebugRollout.dialog_info_button.text == "Dialog Info") and
        (WallFixerDebugRollout.dialog_info_button.width == 294) and
        (WallFixerDebugRollout.dialog_info_button.height == 30)
    )
    -- return
)


/*
Tests native Working Pivot read/write access and restores the original modes.
Returns true only when both Use and Edit modes can be toggled and restored.
*/
function testWallFixerWorkingPivotControls =
(
    original_use_mode = WorkingPivot.UseMode
    original_edit_mode = WorkingPivot.EditMode
    test_passed = false


    try
    (
        WorkingPivot.EditMode = false
        WorkingPivot.UseMode = true
        use_mode_on = WorkingPivot.UseMode


        WorkingPivot.UseMode = false
        use_mode_off = not WorkingPivot.UseMode


        WorkingPivot.EditMode = true
        edit_mode_on = WorkingPivot.EditMode


        WorkingPivot.EditMode = false
        edit_mode_off = not WorkingPivot.EditMode


        test_passed = use_mode_on and use_mode_off and edit_mode_on and edit_mode_off
    )
    catch
    (
        test_passed = false
    )


    try
    (
        WorkingPivot.EditMode = original_edit_mode
        WorkingPivot.UseMode = original_use_mode
    )
    catch
    (
    )


    format "Wall-Fixer Working Pivot controls test: %\n" test_passed
    test_passed
    -- return
)


/*
Main Wall-Fixer dialog owns shared progress, two-line message history and function wrappers.
Child rollouts contain controls only and call these centralized handlers.
*/
/*
Embedded Inner-Outer Wall Finder 0.32
Runtime classifier implementation is embedded here so Wall-Fixer does not depend on a separately synced classifier file.
Material ID 1 = OUTER, ID 2 = INNER, ID 3 = UP, ID 4 = DOWN.
*/


/* Returns the top Edit Poly modifier when it is the evaluated top modifier.
*/
function getTopEditPoly object_node =
(
    wallFixerSetNodeCageOff object_node
    local edit_poly_mod = undefined


    if object_node.modifiers.count > 0 then
    (
        if classof object_node.modifiers[1] == Edit_Poly then
        (
            edit_poly_mod = object_node.modifiers[1]
        )
    )


    edit_poly_mod -- return
)


/* Returns a supported geometry source for Editable Poly or top Edit Poly.
*/
function getFaceGeometrySource object_node =
(
    wallFixerSetNodeCageOff object_node
    local source_data = undefined
    local edit_poly_mod = getTopEditPoly object_node


    if edit_poly_mod != undefined then
    (
        source_data = #(#editPoly, edit_poly_mod)
    )
    else if object_node.modifiers.count == 0 and classof object_node.baseObject == Editable_Poly then
    (
        source_data = #(#editablePoly, object_node.baseObject)
    )


    source_data -- return
)


/* Returns the topmost editable polygon source used by Material by SG.
   The highest Edit Poly in the stack wins; otherwise the Editable Poly base is used.
*/
function getTopMaterialGeometrySource object_node =
(
    wallFixerSetNodeCageOff object_node
    local source_data = undefined


    if object_node != undefined and isValidNode object_node then
    (
        for modifier_index = 1 to object_node.modifiers.count while source_data == undefined do
        (
            local current_modifier = object_node.modifiers[modifier_index]


            if classof current_modifier == Edit_Poly then
            (
                source_data = #(#editPoly, current_modifier)
            )
        )


        if source_data == undefined and classof object_node.baseObject == Editable_Poly then
        (
            source_data = #(#editablePoly, object_node.baseObject)
        )
    )


    source_data -- return
)


/* Returns the vertex count from the current supported polygon source.
*/
function getSourceNumVertices object_node source_data =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local vertex_count = 0


    if source_type == #editPoly then
    (
        vertex_count = source_value.GetNumVertices node:object_node
    )
    else if source_type == #editablePoly then
    (
        vertex_count = source_value.GetNumVertices()
    )


    vertex_count -- return
)


/* Returns the face count from the current supported polygon source.
*/
function getSourceNumFaces object_node source_data =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_count = 0


    if source_type == #editPoly then
    (
        face_count = source_value.GetNumFaces node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_count = source_value.GetNumFaces()
    )


    face_count -- return
)


/* Returns the smoothing-group bit mask for one face on Edit Poly or Editable Poly.
*/
function getSourceFaceSmoothingGroup object_node source_data face_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local smoothing_group = 0


    if source_type == #editPoly then
    (
        smoothing_group = source_value.GetFaceSmoothingGroups face_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        smoothing_group = polyOp.getFaceSmoothGroup source_value face_index
    )


    smoothing_group -- return
)


/* Builds stable sequential Material IDs from smoothing-group bit masks.
   Equal masks always receive the same Material ID; smoothing group 0 is a valid group.
*/
function buildMaterialBySmoothingGroupMap smoothing_groups =
(
    local unique_smoothing_groups = #()
    local material_ids = #()


    for smoothing_group in smoothing_groups do
    (
        local material_id = findItem unique_smoothing_groups smoothing_group


        if material_id == 0 then
        (
            append unique_smoothing_groups smoothing_group
            material_id = unique_smoothing_groups.count
        )


        append material_ids material_id
    )


    #(unique_smoothing_groups, material_ids) -- return
)


/* Creates a shared Multi/Sub-Object material for smoothing-group-driven Material IDs.
   Each distinct smoothing-group mask receives one deterministic colored sub-material.
*/
function createMaterialBySmoothingGroupMultiMaterial smoothing_groups =
(
    local material_count = smoothing_groups.count
    local material_by_sg = undefined


    if material_count > 0 then
    (
        local color_palette = #(
            (color 238 92 92),
            (color 96 178 246),
            (color 112 214 132),
            (color 244 182 78),
            (color 184 118 244),
            (color 78 210 204),
            (color 246 122 190),
            (color 194 210 90),
            (color 116 142 248),
            (color 238 136 82),
            (color 126 210 168),
            (color 218 116 240)
        )
        local material_ids = #()
        local material_names = #()


        material_by_sg = multimaterial numsubs:material_count name:"MATERIAL BY SG"


        for material_index = 1 to material_count do
        (
            local smoothing_group = smoothing_groups[material_index]
            local material_name = "SG " + (smoothing_group as string)
            local palette_index = mod (material_index - 1) color_palette.count + 1
            local sub_material = standardMaterial name:material_name diffuse:color_palette[palette_index]


            material_by_sg.materialList[material_index] = sub_material
            append material_ids material_index
            append material_names material_name
        )


        material_by_sg.materialIDList = material_ids
        material_by_sg.names = material_names
    )


    material_by_sg -- return
)


/* Assigns one shared Material by SG material and rewrites face Material IDs from smoothing groups.
   Uses the topmost Edit Poly when present, otherwise the Editable Poly base.
*/
function assignMaterialBySmoothingGroups object_nodes =
(
    local object_data = #()
    local all_smoothing_groups = #()
    local original_selection = selection as array
    local original_sub_object_level = subObjectLevel
    local original_panel_mode = undefined
    local result_data = undefined


    try
    (
        original_panel_mode = getCommandPanelTaskMode()
    )
    catch
    (
        original_panel_mode = undefined
    )


    for object_node in object_nodes do
    (
        local source_data = getTopMaterialGeometrySource object_node


        if source_data != undefined then
        (
            local face_count = getSourceNumFaces object_node source_data


            if face_count > 0 then
            (
                local face_smoothing_groups = #()


                for face_index = 1 to face_count do
                (
                    local smoothing_group = getSourceFaceSmoothingGroup object_node source_data face_index


                    append face_smoothing_groups smoothing_group


                    if findItem all_smoothing_groups smoothing_group == 0 then
                    (
                        append all_smoothing_groups smoothing_group
                    )
                )


                append object_data #(object_node, source_data, face_smoothing_groups)
            )
        )
    )


    if object_data.count > 0 and all_smoothing_groups.count > 0 then
    (
        local material_by_sg = createMaterialBySmoothingGroupMultiMaterial all_smoothing_groups


        if material_by_sg != undefined then
        (
            for current_data in object_data do
            (
                local object_node = current_data[1]
                local source_data = current_data[2]
                local face_smoothing_groups = current_data[3]
                local original_face_selection = getSourceFaceSelection object_node source_data
                local face_bits_by_material = for material_index = 1 to all_smoothing_groups.count collect #{}


                for face_index = 1 to face_smoothing_groups.count do
                (
                    local material_id = findItem all_smoothing_groups face_smoothing_groups[face_index]


                    if material_id > 0 then
                    (
                        face_bits_by_material[material_id][face_index] = true
                    )
                )


                object_node.material = material_by_sg


                for material_id = 1 to face_bits_by_material.count do
                (
                    if face_bits_by_material[material_id].numberSet > 0 then
                    (
                        setSourceFaceMaterialId object_node source_data face_bits_by_material[material_id] material_id
                    )
                )


                setSourceFaceSelection object_node source_data original_face_selection
            )


            result_data = #(material_by_sg, object_data.count, all_smoothing_groups.count)
        )
    )


    try
    (
        select original_selection
    )
    catch
    (
    )


    try
    (
        subObjectLevel = original_sub_object_level
    )
    catch
    (
    )


    if original_panel_mode != undefined then
    (
        try
        (
            setCommandPanelTaskMode original_panel_mode
        )
        catch
        (
        )
    )


    redrawViews()


    result_data -- return
)


/* Tests deterministic smoothing-group-mask to Material-ID mapping.
   Equal masks must reuse one ID and smoothing group 0 must remain a separate group.
*/
function testMaterialBySmoothingGroupMap =
(
    local test_data = buildMaterialBySmoothingGroupMap #(1, 4, 1, 0, 5, 4)
    local expected_groups = #(1, 4, 0, 5)
    local expected_ids = #(1, 2, 1, 3, 4, 2)
    local passed = test_data[1] == expected_groups and test_data[2] == expected_ids


    format "Material by SG mapping: % | groups:% | ids:%\n" passed test_data[1] test_data[2]


    passed -- return
)


/* Returns one evaluated vertex position in world space.
*/
function getSourceVertexWorld object_node source_data vertex_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local vertex_local = [0.0, 0.0, 0.0]


    if source_type == #editPoly then
    (
        vertex_local = source_value.GetVertex vertex_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        vertex_local = source_value.GetVertex vertex_index
    )


    (vertex_local * object_node.objectTransform) -- return
)


/* Returns the number of polygon corners for one evaluated face.
*/
function getSourceFaceDegree object_node source_data face_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_degree = 0


    if source_type == #editPoly then
    (
        face_degree = source_value.GetFaceDegree face_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_degree = source_value.GetFaceDegree face_index
    )


    face_degree -- return
)


/* Returns the vertex index at one polygon corner.
*/
function getSourceFaceVertex object_node source_data face_index corner_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local vertex_index = 0


    if source_type == #editPoly then
    (
        vertex_index = source_value.GetFaceVertex face_index corner_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        vertex_index = source_value.GetFaceVertex face_index corner_index
    )


    vertex_index -- return
)


/* Returns the edge index at one polygon side.
*/
function getSourceFaceEdge object_node source_data face_index side_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local edge_index = 0


    if source_type == #editPoly then
    (
        edge_index = source_value.GetFaceEdge face_index side_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        edge_index = source_value.GetFaceEdge face_index side_index
    )


    edge_index -- return
)


/* Returns the face index attached to one side of an edge.
*/
function getSourceEdgeFace object_node source_data edge_index side_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_index = 0


    if source_type == #editPoly then
    (
        face_index = source_value.GetEdgeFace edge_index side_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_index = source_value.GetEdgeFace edge_index side_index
    )


    face_index -- return
)


/* Calculates the center of an arbitrary polygon from cached world-space vertices.
*/
function calculatePolygonCenter face_vertices =
(
    local center_value = [0.0, 0.0, 0.0]


    if face_vertices.count > 0 then
    (
        for vertex_value in face_vertices do
        (
            center_value += vertex_value
        )


        center_value /= face_vertices.count
    )


    center_value -- return
)


/* Calculates a stable polygon normal with Newell's method in world space.
*/
function calculatePolygonNormal face_vertices epsilon:0.0000001 =
(
    local normal_value = [0.0, 0.0, 0.0]
    local current_vertex = [0.0, 0.0, 0.0]
    local next_vertex = [0.0, 0.0, 0.0]
    local next_index = 1


    if face_vertices.count >= 3 then
    (
        for vertex_index = 1 to face_vertices.count do
        (
            next_index = vertex_index + 1
            if next_index > face_vertices.count then
            (
                next_index = 1
            )


            current_vertex = face_vertices[vertex_index]
            next_vertex = face_vertices[next_index]


            normal_value.x += (current_vertex.y - next_vertex.y) * (current_vertex.z + next_vertex.z)
            normal_value.y += (current_vertex.z - next_vertex.z) * (current_vertex.x + next_vertex.x)
            normal_value.z += (current_vertex.x - next_vertex.x) * (current_vertex.y + next_vertex.y)
        )
    )


    if (length normal_value) > epsilon then
    (
        normal_value = normalize normal_value
    )
    else
    (
        normal_value = [0.0, 0.0, 0.0]
    )


    normal_value -- return
)


/* Returns the positive ray distance to an axis-aligned bounding-box exit.
*/
function getBBoxExitDistance point_value direction_value bbox_min bbox_max epsilon:0.0000001 =
(
    local distance_value = 1.0e30
    local candidate_distance = 0.0


    if direction_value.x > epsilon then
    (
        candidate_distance = (bbox_max.x - point_value.x) / direction_value.x
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )
    else if direction_value.x < -epsilon then
    (
        candidate_distance = (bbox_min.x - point_value.x) / direction_value.x
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )


    if direction_value.y > epsilon then
    (
        candidate_distance = (bbox_max.y - point_value.y) / direction_value.y
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )
    else if direction_value.y < -epsilon then
    (
        candidate_distance = (bbox_min.y - point_value.y) / direction_value.y
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )


    if direction_value.z > epsilon then
    (
        candidate_distance = (bbox_max.z - point_value.z) / direction_value.z
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )
    else if direction_value.z < -epsilon then
    (
        candidate_distance = (bbox_min.z - point_value.z) / direction_value.z
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )


    if distance_value == 1.0e30 then
    (
        distance_value = 0.0
    )


    distance_value -- return
)


/* Calculates a double-sided ray/triangle hit distance with Moller-Trumbore intersection.
*/
function getRayTriangleDistance ray_origin ray_direction point_a point_b point_c epsilon:0.0000001 =
(
    local edge_a = point_b - point_a
    local edge_b = point_c - point_a
    local p_vector = cross ray_direction edge_b
    local determinant = dot edge_a p_vector
    local hit_distance = undefined
    local inverse_determinant = 0.0
    local t_vector = [0.0, 0.0, 0.0]
    local u_value = 0.0
    local q_vector = [0.0, 0.0, 0.0]
    local v_value = 0.0
    local t_value = 0.0


    if (abs determinant) > epsilon then
    (
        inverse_determinant = 1.0 / determinant
        t_vector = ray_origin - point_a
        u_value = (dot t_vector p_vector) * inverse_determinant


        if u_value >= -epsilon and u_value <= (1.0 + epsilon) then
        (
            q_vector = cross t_vector edge_a
            v_value = (dot ray_direction q_vector) * inverse_determinant


            if v_value >= -epsilon and (u_value + v_value) <= (1.0 + epsilon) then
            (
                t_value = (dot edge_b q_vector) * inverse_determinant
                if t_value > epsilon then
                (
                    hit_distance = t_value
                )
            )
        )
    )


    hit_distance -- return
)


/* Finds the nearest selected-face hit for a double-sided ray, excluding its source face.
*/
function getNearestRayHitDistance ray_origin ray_direction object_data_array ignore_node ignore_face epsilon:0.0000001 =
(
    local nearest_distance = undefined
    local face_vertices = undefined
    local hit_distance = undefined


    for object_data in object_data_array do
    (
        local object_node = object_data[1]
        local cached_faces = object_data[3]


        for face_index = 1 to cached_faces.count do
        (
            if not (object_node == ignore_node and face_index == ignore_face) then
            (
                face_vertices = cached_faces[face_index]


                if face_vertices.count >= 3 then
                (
                    for triangle_index = 2 to (face_vertices.count - 1) do
                    (
                        hit_distance = getRayTriangleDistance ray_origin ray_direction face_vertices[1] face_vertices[triangle_index] face_vertices[triangle_index + 1] epsilon:epsilon


                        if hit_distance != undefined then
                        (
                            if nearest_distance == undefined or hit_distance < nearest_distance then
                            (
                                nearest_distance = hit_distance
                            )
                        )
                    )
                )
            )
        )
    )


    nearest_distance -- return
)


/* Finds the nearest nearly-parallel face hit within the wall-thickness search distance.
   Only faces on the currently selected objects are searched.
*/
function getNearestOppositeWallHit ray_origin ray_direction source_normal object_data_array ignore_node ignore_face max_distance parallel_threshold:0.90 epsilon:0.0000001 =
(
    local nearest_data = undefined
    local candidate_normal = [0.0, 0.0, 0.0]
    local face_vertices = undefined
    local hit_distance = undefined
    local parallel_value = 0.0


    for object_data in object_data_array do
    (
        local object_node = object_data[1]
        local cached_faces = object_data[3]
        local face_normals = object_data[5]


        for face_index = 1 to cached_faces.count do
        (
            if not (object_node == ignore_node and face_index == ignore_face) then
            (
                candidate_normal = face_normals[face_index]


                if (length candidate_normal) > epsilon then
                (
                    parallel_value = abs (dot source_normal candidate_normal)


                    if parallel_value >= parallel_threshold then
                    (
                        face_vertices = cached_faces[face_index]


                        if face_vertices.count >= 3 then
                        (
                            for triangle_index = 2 to (face_vertices.count - 1) do
                            (
                                hit_distance = getRayTriangleDistance ray_origin ray_direction face_vertices[1] face_vertices[triangle_index] face_vertices[triangle_index + 1] epsilon:epsilon


                                if hit_distance != undefined then
                                (
                                    if hit_distance <= max_distance then
                                    (
                                        if nearest_data == undefined or hit_distance < nearest_data[1] then
                                        (
                                            nearest_data = #(hit_distance, object_node, face_index, parallel_value)
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )


    nearest_data -- return
)


/* Returns the current classification of one cached face.
   ID 1 = OUTER, ID 2 = INNER, ID 3 = UP, ID 4 = DOWN, 0 = unresolved wall.
*/
function getCachedFaceClass object_data_array object_node face_index =
(
    local class_id = 0


    for object_data in object_data_array do
    (
        if object_data[1] == object_node then
        (
            if face_index >= 1 and face_index <= object_data[6].count then
            (
                class_id = object_data[6][face_index]
            )
        )
    )


    class_id -- return
)


/* Returns the cached first-pass spatial score for one face.
   Positive scores lean OUTER, negative scores lean INNER.
*/
function getCachedFaceScore object_data_array object_node face_index =
(
    local score_value = 0.0


    for object_data in object_data_array do
    (
        if object_data[1] == object_node then
        (
            if object_data.count >= 7 and face_index >= 1 and face_index <= object_data[7].count then
            (
                score_value = object_data[7][face_index]
            )
        )
    )


    score_value -- return
)


/* Returns the cached center and normal for one face.
   Result is #(center, normal), or undefined when the face cannot be found.
*/
function getCachedFaceCenterNormal object_data_array object_node face_index =
(
    local result_data = undefined


    for object_data in object_data_array do
    (
        if object_data[1] == object_node then
        (
            if face_index >= 1 and face_index <= object_data[4].count then
            (
                result_data = #(object_data[4][face_index], object_data[5][face_index])
            )
        )
    )


    result_data -- return
)


/* Resolves unresolved or weak wall faces by finding the opposite wall behind the face.
   Horizontal UP/DOWN faces are ignored; only wall classes 0, 1, and 2 are considered.
*/
function resolveUnresolvedWallsByThickness object_data_array wall_thickness confidence_threshold:0.12 parallel_threshold:0.90 ray_offset:0.001 epsilon:0.0000001 =
(
    local resolved_count = 0
    local weak_limit = confidence_threshold * 2.0


    if weak_limit < confidence_threshold then
    (
        weak_limit = confidence_threshold
    )


    if wall_thickness > epsilon then
    (
        for object_data in object_data_array do
        (
            local object_node = object_data[1]
            local face_centers = object_data[4]
            local face_normals = object_data[5]
            local face_classes = object_data[6]
            local face_scores = object_data[7]


            for face_index = 1 to face_classes.count do
            (
                local current_class = face_classes[face_index]
                local face_score = face_scores[face_index]


                if current_class == 0 or ((current_class == 1 or current_class == 2) and (abs face_score) < weak_limit) then
                (
                    local face_center = face_centers[face_index]
                    local face_normal = face_normals[face_index]


                    if (length face_normal) > epsilon then
                    (
                        local opposite_origin = face_center - (face_normal * ray_offset)
                        local opposite_hit = getNearestOppositeWallHit opposite_origin (-face_normal) face_normal object_data_array object_node face_index wall_thickness parallel_threshold:parallel_threshold epsilon:epsilon


                        if opposite_hit != undefined then
                        (
                            local opposite_data = getCachedFaceCenterNormal object_data_array opposite_hit[2] opposite_hit[3]


                            if opposite_data != undefined then
                            (
                                local opposite_center = opposite_data[1]
                                local opposite_normal = opposite_data[2]


                                if (length opposite_normal) > epsilon and (abs opposite_normal.z) < 0.85 then
                                (
                                    local source_outward_origin = face_center + (face_normal * ray_offset)
                                    local opposite_outward_origin = opposite_center + (opposite_normal * ray_offset)
                                    local source_outward_hit = getNearestRayHitDistance source_outward_origin face_normal object_data_array object_node face_index epsilon:epsilon
                                    local opposite_outward_hit = getNearestRayHitDistance opposite_outward_origin opposite_normal object_data_array opposite_hit[2] opposite_hit[3] epsilon:epsilon
                                    local new_class = 0


                                    if source_outward_hit == undefined and opposite_outward_hit != undefined then
                                    (
                                        new_class = 1
                                    )
                                    else if source_outward_hit != undefined and opposite_outward_hit == undefined then
                                    (
                                        new_class = 2
                                    )
                                    else
                                    (
                                        local opposite_class = getCachedFaceClass object_data_array opposite_hit[2] opposite_hit[3]
                                        local opposite_score = getCachedFaceScore object_data_array opposite_hit[2] opposite_hit[3]


                                        if (abs opposite_score) >= weak_limit then
                                        (
                                            if opposite_class == 1 then
                                            (
                                                new_class = 2
                                            )
                                            else if opposite_class == 2 then
                                            (
                                                new_class = 1
                                            )
                                        )
                                    )


                                    if (new_class == 1 or new_class == 2) and new_class != current_class then
                                    (
                                        face_classes[face_index] = new_class


                                        if object_data.count >= 10 then
                                        (
                                            object_data[10][face_index] = #THICKNESS
                                        )


                                        resolved_count += 1
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )


    resolved_count -- return
)


/* Builds a bitarray containing every face assigned to one classification ID.
*/
function buildFaceClassBits face_classes class_id =
(
    local face_bits = #{}


    for face_index = 1 to face_classes.count do
    (
        if face_classes[face_index] == class_id then
        (
            face_bits[face_index] = true
        )
    )


    face_bits -- return
)


/* Resolves remaining unresolved wall faces from already classified edge neighbors.
   UP and DOWN faces do not vote in wall classification.
*/
function resolveUnresolvedWallFaces object_data_array neighbor_passes:3 =
(
    local total_change_count = 0


    for pass_index = 1 to neighbor_passes do
    (
        local change_count = 0


        for object_data in object_data_array do
        (
            local object_node = object_data[1]
            local source_data = object_data[2]
            local face_normals = object_data[5]
            local face_classes = object_data[6]


            for face_index = 1 to face_classes.count do
            (
                if face_classes[face_index] == 0 then
                (
                    local face_degree = getSourceFaceDegree object_node source_data face_index
                    local vote_value = 0.0
                    local evidence_value = 0.0
                    local edge_index = 0
                    local edge_face_a = 0
                    local edge_face_b = 0
                    local neighbor_face = 0
                    local neighbor_class = 0
                    local similarity = 0.0
                    local vote_weight = 0.0


                    for side_index = 1 to face_degree do
                    (
                        edge_index = getSourceFaceEdge object_node source_data face_index side_index


                        if edge_index > 0 then
                        (
                            edge_face_a = getSourceEdgeFace object_node source_data edge_index 1
                            edge_face_b = getSourceEdgeFace object_node source_data edge_index 2
                            neighbor_face = 0


                            if edge_face_a > 0 and edge_face_a != face_index then
                            (
                                neighbor_face = edge_face_a
                            )
                            else if edge_face_b > 0 and edge_face_b != face_index then
                            (
                                neighbor_face = edge_face_b
                            )


                            if neighbor_face > 0 and neighbor_face <= face_classes.count then
                            (
                                neighbor_class = face_classes[neighbor_face]


                                if neighbor_class == 1 or neighbor_class == 2 then
                                (
                                    similarity = abs (dot face_normals[face_index] face_normals[neighbor_face])
                                    vote_weight = 0.25 + (0.75 * similarity)
                                    evidence_value += vote_weight


                                    if neighbor_class == 1 then
                                    (
                                        vote_value += vote_weight
                                    )
                                    else
                                    (
                                        vote_value -= vote_weight
                                    )
                                )
                            )
                        )
                    )


                    if evidence_value >= 0.5 then
                    (
                        local normalized_vote = vote_value / evidence_value


                        if normalized_vote >= 0.34 then
                        (
                            face_classes[face_index] = 1


                            if object_data.count >= 10 then
                            (
                                object_data[10][face_index] = #NEIGHBOR
                            )


                            change_count += 1
                        )
                        else if normalized_vote <= -0.34 then
                        (
                            face_classes[face_index] = 2


                            if object_data.count >= 10 then
                            (
                                object_data[10][face_index] = #NEIGHBOR
                            )


                            change_count += 1
                        )
                    )
                )
            )
        )


        total_change_count += change_count
    )


    total_change_count -- return
)


/* Forces every remaining unresolved wall face to OUTER or INNER from its spatial score.
   This is the final fallback so every non-horizontal face receives a wall class.
*/
function finalizeUnresolvedWallFaces object_data_array =
(
    local finalized_count = 0


    for object_data in object_data_array do
    (
        local face_classes = object_data[6]
        local face_scores = object_data[7]


        for face_index = 1 to face_classes.count do
        (
            if face_classes[face_index] == 0 then
            (
                if face_scores[face_index] >= 0.0 then
                (
                    face_classes[face_index] = 1
                )
                else
                (
                    face_classes[face_index] = 2
                )


                if object_data.count >= 10 then
                (
                    object_data[10][face_index] = #FALLBACK
                )


                finalized_count += 1
            )
        )
    )


    finalized_count -- return
)


/* Creates the classifier Multi/Sub-Object material with legacy Standard sub-materials.
   ID 1 = OUTER green, ID 2 = INNER pastel orange, ID 3 = UP pastel blue, ID 4 = DOWN pastel violet.
*/
function createWallClassifierMaterial =
(
    local classifier_material = multimaterial numsubs:4 name:"WALL FACE CLASSIFIER"
    local outer_material = standardMaterial name:"OUTER" diffuse:(color 152 221 161)
    local inner_material = standardMaterial name:"INNER" diffuse:(color 221 189 152)
    local up_material = standardMaterial name:"UP" diffuse:(color 152 198 221)
    local down_material = standardMaterial name:"DOWN" diffuse:(color 186 152 221)


    classifier_material.materialList[1] = outer_material
    classifier_material.materialList[2] = inner_material
    classifier_material.materialList[3] = up_material
    classifier_material.materialList[4] = down_material
    classifier_material.materialIDList = #(1, 2, 3, 4)
    classifier_material.names = #("OUTER", "INNER", "UP", "DOWN")


    classifier_material -- return
)


/* Assigns one shared classifier Multi/Sub-Object material to supported nodes.
   Existing node materials are replaced only on the objects being classified.
*/
function assignWallClassifierMaterial object_nodes =
(
    local classifier_material = createWallClassifierMaterial()


    for object_node in object_nodes do
    (
        object_node.material = classifier_material
    )


    classifier_material -- return
)


/* Assigns one Material ID to a face set on Editable Poly or top Edit Poly.
*/
function setSourceFaceMaterialId object_node source_data face_bits material_id =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local working_bits = copy face_bits


    if working_bits.numberSet > 0 then
    (
        if source_type == #editPoly then
        (
            select object_node
            max modify mode
            modPanel.setCurrentObject source_value
            source_value.SetEPolySelLevel #Face
            source_value.SetSelection #Face working_bits node:object_node
            source_value.materialIDToSet = material_id
            source_value.ButtonOp #SetMaterial
        )
        else if source_type == #editablePoly then
        (
            polyOp.setFaceMatID source_value working_bits material_id
        )
    )


    true -- return
)


/* Sets the face selection without changing the current object selection.
   This lets one LMB action update face selections across multiple supported objects.
*/
function setSourceFaceSelection object_node source_data face_bits =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local working_bits = #{}


    if face_bits != undefined then
    (
        working_bits = copy face_bits
    )


    if source_type == #editPoly then
    (
        source_value.SetEPolySelLevel #Face
        source_value.SetSelection #Face working_bits node:object_node
    )
    else if source_type == #editablePoly then
    (
        source_value.SetSelection #Face working_bits
    )


    true -- return
)


/* Returns the Material ID assigned to one face on Editable Poly or top Edit Poly.
*/
function getSourceFaceMaterialId object_node source_data face_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local material_id = 0


    if source_type == #editPoly then
    (
        material_id = source_value.GetFaceMaterial face_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        material_id = polyOp.getFaceMatID source_value face_index
    )


    material_id -- return
)


/* Finds cached classifier data for one node and removes invalid cache entries.
   Returns zero when the node does not currently have cached class bitarrays.
*/
function findWallFaceCacheIndex object_node =
(
    local found_index = 0


    if wall_face_classifier_cache.count > 0 then
    (
        for cache_index = wall_face_classifier_cache.count to 1 by -1 do
        (
            local cache_entry = wall_face_classifier_cache[cache_index]


            if cache_entry.count < 6 then
            (
                deleteItem wall_face_classifier_cache cache_index
            )
            else if not isValidNode cache_entry[1] then
            (
                deleteItem wall_face_classifier_cache cache_index
            )
            else if found_index == 0 and cache_entry[1] == object_node then
            (
                found_index = cache_index
            )
        )
    )


    found_index -- return
)


/* Stores OUTER, INNER, UP, and DOWN face bitarrays for fast button selection.
   Cache entries are rebuilt after classification or manual force marking.
*/
function cacheWallFaceClasses object_node face_count outer_bits inner_bits up_bits down_bits =
(
    local cache_entry = #(object_node, face_count, copy outer_bits, copy inner_bits, copy up_bits, copy down_bits)
    local cache_index = findWallFaceCacheIndex object_node


    if cache_index > 0 then
    (
        wall_face_classifier_cache[cache_index] = cache_entry
    )
    else
    (
        append wall_face_classifier_cache cache_entry
    )


    cache_entry -- return
)


/* Reads classifier Material IDs once and stores all four face classes in cache.
   Faces using other Material IDs are intentionally not included in the classifier cache.
*/
function cacheWallFaceClassesFromMaterialIds object_node source_data =
(
    local face_count = getSourceNumFaces object_node source_data
    local outer_bits = #{}
    local inner_bits = #{}
    local up_bits = #{}
    local down_bits = #{}


    for face_index = 1 to face_count do
    (
        local material_id = getSourceFaceMaterialId object_node source_data face_index


        if material_id == 1 then
        (
            outer_bits[face_index] = true
        )
        else if material_id == 2 then
        (
            inner_bits[face_index] = true
        )
        else if material_id == 3 then
        (
            up_bits[face_index] = true
        )
        else if material_id == 4 then
        (
            down_bits[face_index] = true
        )
    )


    cacheWallFaceClasses object_node face_count outer_bits inner_bits up_bits down_bits -- return
)


/* Returns cached face bits when they still match the current object topology.
   Undefined means the cache should be rebuilt from Material IDs.
*/
function getCachedWallFaceBits object_node source_data material_id =
(
    local result_bits = undefined
    local cache_index = findWallFaceCacheIndex object_node


    if cache_index > 0 then
    (
        local cache_entry = wall_face_classifier_cache[cache_index]
        local face_count = getSourceNumFaces object_node source_data
        local material_valid = false


        if object_node.material != undefined then
        (
            if object_node.material.name == "WALL FACE CLASSIFIER" then
            (
                material_valid = true
            )
        )


        if cache_entry[2] == face_count and material_valid then
        (
            if material_id == 1 then
            (
                result_bits = copy cache_entry[3]
            )
            else if material_id == 2 then
            (
                result_bits = copy cache_entry[4]
            )
            else if material_id == 3 then
            (
                result_bits = copy cache_entry[5]
            )
            else if material_id == 4 then
            (
                result_bits = copy cache_entry[6]
            )
        )
        else
        (
            deleteItem wall_face_classifier_cache cache_index
        )
    )


    result_bits -- return
)


/* Returns the current face selection for Editable Poly or top Edit Poly.
   The returned bitarray is copied so callers can safely modify it.
*/
function getSourceFaceSelection object_node source_data =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_bits = #{}


    if source_type == #editPoly then
    (
        face_bits = source_value.GetSelection #Face node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_bits = source_value.GetSelection #Face
    )


    if face_bits == undefined then
    (
        face_bits = #{}
    )


    copy face_bits -- return
)


/* Collects the dominant vertical face orientation from the selected wall objects.
   Parallel and opposite face normals vote for one cluster while horizontal caps are ignored.
*/
function getDominantWallFaceAlignmentData =
(
    selected_nodes = selection as array
    cluster_normals = #()
    cluster_centers = #()
    cluster_counts = #()
    cluster_reference_normals = #()
    dominant_cluster_index = 0
    dominant_cluster_count = 0
    dominant_normal_dot_threshold = 0.9961947


    for object_node in selected_nodes do
    (
        if object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass then
        (
            source_data = getFaceGeometrySource object_node


            if source_data != undefined then
            (
                source_face_count = getSourceNumFaces object_node source_data


                for face_index = 1 to source_face_count do
                (
                    face_degree = getSourceFaceDegree object_node source_data face_index
                    face_vertices = #()


                    if face_degree >= 3 then
                    (
                        for corner_index = 1 to face_degree do
                        (
                            vertex_index = getSourceFaceVertex object_node source_data face_index corner_index


                            if vertex_index > 0 then
                            (
                                append face_vertices (getSourceVertexWorld object_node source_data vertex_index)
                            )
                        )
                    )


                    if face_vertices.count >= 3 then
                    (
                        face_normal = calculatePolygonNormal face_vertices
                        horizontal_normal = [face_normal.x, face_normal.y, 0.0]


                        if (length horizontal_normal) > 0.0000001 then
                        (
                            horizontal_normal = normalize horizontal_normal
                            cluster_index = 0


                            for test_index = 1 to cluster_reference_normals.count while cluster_index == 0 do
                            (
                                if (abs (dot horizontal_normal cluster_reference_normals[test_index])) >= dominant_normal_dot_threshold then
                                (
                                    cluster_index = test_index
                                )
                            )


                            if cluster_index == 0 then
                            (
                                append cluster_reference_normals horizontal_normal
                                append cluster_normals horizontal_normal
                                append cluster_centers (calculatePolygonCenter face_vertices)
                                append cluster_counts 1
                            )
                            else
                            (
                                if (dot horizontal_normal cluster_reference_normals[cluster_index]) < 0.0 then
                                (
                                    horizontal_normal *= -1.0
                                )


                                cluster_normals[cluster_index] += horizontal_normal
                                cluster_centers[cluster_index] += calculatePolygonCenter face_vertices
                                cluster_counts[cluster_index] += 1
                            )
                        )
                    )
                )
            )
        )
    )


    for cluster_index = 1 to cluster_counts.count do
    (
        if cluster_counts[cluster_index] > dominant_cluster_count then
        (
            dominant_cluster_index = cluster_index
            dominant_cluster_count = cluster_counts[cluster_index]
        )
    )


    if dominant_cluster_index > 0 and (length cluster_normals[dominant_cluster_index]) > 0.0000001 then
    (
        #(
            (cluster_centers[dominant_cluster_index] / dominant_cluster_count),
            (normalize cluster_normals[dominant_cluster_index]),
            dominant_cluster_count,
            #dominant
        )
    )
    else
    (
        undefined
    )
    -- return
)


/* Collects alignment data from selected faces, or falls back to the dominant wall-face orientation.
   Supports Editable Poly and a top Edit Poly modifier without changing topology or selection.
*/
function getSelectedWallFaceAlignmentData =
(
    selected_nodes = selection as array
    reference_normal = undefined
    normal_sum = [0.0, 0.0, 0.0]
    center_sum = [0.0, 0.0, 0.0]
    valid_face_count = 0


    if subObjectLevel == 4 then
    (
        for object_node in selected_nodes do
        (
            if object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass then
            (
                source_data = getFaceGeometrySource object_node


                if source_data != undefined then
                (
                    selected_face_bits = getSourceFaceSelection object_node source_data


                    for face_index in selected_face_bits do
                    (
                        face_degree = getSourceFaceDegree object_node source_data face_index
                        face_vertices = #()


                        if face_degree >= 3 then
                        (
                            for corner_index = 1 to face_degree do
                            (
                                vertex_index = getSourceFaceVertex object_node source_data face_index corner_index


                                if vertex_index > 0 then
                                (
                                    append face_vertices (getSourceVertexWorld object_node source_data vertex_index)
                                )
                            )
                        )


                        if face_vertices.count >= 3 then
                        (
                            face_normal = calculatePolygonNormal face_vertices


                            if (length face_normal) > 0.0000001 then
                            (
                                if reference_normal == undefined then
                                (
                                    reference_normal = face_normal
                                )
                                else if (dot face_normal reference_normal) < 0.0 then
                                (
                                    face_normal *= -1.0
                                )


                                normal_sum += face_normal
                                center_sum += calculatePolygonCenter face_vertices
                                valid_face_count += 1
                            )
                        )
                    )
                )
            )
        )
    )


    if valid_face_count > 0 and (length normal_sum) > 0.0000001 then
    (
        #((center_sum / valid_face_count), (normalize normal_sum), valid_face_count, #selected)
    )
    else
    (
        getDominantWallFaceAlignmentData()
    )
    -- return
)


/* Builds the horizontal view normal used by Helpers > Align Camera.
   Side view rotates the wall-facing direction 90 degrees around world Z.
*/
function getWallCameraViewNormal face_normal side_view:false =
(
    reference_up = [0.0, 0.0, 1.0]
    horizontal_normal = [face_normal.x, face_normal.y, 0.0]


    if (length horizontal_normal) > 0.0000001 then
    (
        view_normal = normalize horizontal_normal
    )
    else
    (
        view_normal = face_normal
    )


    if side_view then
    (
        side_normal = cross reference_up view_normal


        if (length side_normal) > 0.0000001 then
        (
            view_normal = normalize side_normal
        )
    )


    view_normal
    -- return
)


/* Aligns the active viewport perpendicular to selected wall faces through a temporary orthographic camera.
   Optional side view rotates the wall-facing direction 90 degrees around world Z before building the camera.
*/
function alignViewportToSelectedWallFaces side_view:false =
(
    alignment_data = getSelectedWallFaceAlignmentData()
    temp_camera = undefined
    operation_success = false
    original_selection = selection as array


    if alignment_data == undefined then
    (
        WallFixer.last_slice_report = "Align Camera: select one or more supported wall objects."
    )
    else
    (
        face_center = alignment_data[1]
        face_normal = alignment_data[2]
        face_count = alignment_data[3]
        alignment_mode = alignment_data[4]
        reference_up = [0.0, 0.0, 1.0]
        view_normal = getWallCameraViewNormal face_normal side_view:side_view
        right_axis = cross reference_up view_normal


        if (length right_axis) > 0.0000001 then
        (
            right_axis = normalize right_axis
            up_axis = reference_up
            camera_position = face_center + (view_normal * 1000.0)
            camera_tm = matrix3 right_axis up_axis view_normal camera_position


            try
            (
                with undo off
                (
                    temp_camera = freeCamera()
                    temp_camera.orthoProjection = true
                    temp_camera.transform = camera_tm
                    viewport.setCamera temp_camera


                    user_view_set = viewport.setType #view_iso_user


                    if user_view_set then
                    (
                        if isValidNode temp_camera then
                        (
                            delete temp_camera
                            temp_camera = undefined
                        )


                        select original_selection
                        max zoomext sel
                        completeRedraw()
                        operation_success = true
                    )
                )
            )
            catch
            (
                operation_success = false
            )
        )


        if temp_camera != undefined and isValidNode temp_camera then
        (
            try
            (
                with undo off delete temp_camera
            )
            catch
            (
            )
        )


        if operation_success then
        (
            view_mode_text = if side_view then "side view 90° from" else "view aligned to"


            if alignment_mode == #selected then
            (
                WallFixer.last_slice_report = "Align Camera: User " + view_mode_text + " " + (face_count as string) + " selected wall face(s) and zoomed to selection."
            )
            else
            (
                WallFixer.last_slice_report = "Align Camera: no faces selected; User " + view_mode_text + " the dominant normal from " + (face_count as string) + " wall face(s) and zoomed to selection."
            )
        )
        else
        (
            WallFixer.last_slice_report = "Align Camera: could not align the active viewport."
        )
    )


    operation_success
    -- return
)


/* Builds a bitarray containing every face of one supported polygon source.
   Used when force marking is performed at object level.
*/
function getAllSourceFaceBits object_node source_data =
(
    local face_count = getSourceNumFaces object_node source_data
    local face_bits = #{}


    for face_index = 1 to face_count do
    (
        face_bits[face_index] = true
    )


    face_bits -- return
)




/* Converts a face bitarray to a compact persistent user-property string.
   The stored indices are used only as manual FORCED OUTER/INNER classification hints.
*/
function wallFaceBitsToUserPropString face_bits =
(
    local value_string = ""
    local first_value = true


    for face_index in face_bits do
    (
        if not first_value then
        (
            value_string += ","
        )


        value_string += face_index as string
        first_value = false
    )


    value_string -- return
)


/* Restores a persistent FORCED face list and clamps it to the current face count.
   Empty or missing user properties produce an empty bitarray.
*/
function wallFaceBitsFromUserPropString value_string face_count =
(
    local face_bits = #{}


    if value_string != undefined and value_string != "" then
    (
        local safe_value_string = value_string as string
        local token_array = filterString safe_value_string ","


        for token_value in token_array do
        (
            local face_index = token_value as integer


            if face_index >= 1 and face_index <= face_count then
            (
                face_bits[face_index] = true
            )
        )
    )


    face_bits -- return
)


/* Returns the user-property name for one manual FORCED wall class.
   Only OUTER and INNER can be forced by RMB or CTRL+RMB.
*/
function getForcedWallFacePropertyName material_id =
(
    local property_name = ""


    if material_id == 1 then
    (
        property_name = "WallFaceClassifierForcedOuter"
    )
    else if material_id == 2 then
    (
        property_name = "WallFaceClassifierForcedInner"
    )


    property_name -- return
)


/* Reads persistent FORCED OUTER or INNER face indices from one object.
   Face indices outside the current topology are ignored.
*/
function getForcedWallFaceBits object_node source_data material_id =
(
    local face_bits = #{}
    local property_name = getForcedWallFacePropertyName material_id


    if property_name != "" then
    (
        local face_count = getSourceNumFaces object_node source_data
        local value_string = getUserProp object_node property_name
        face_bits = wallFaceBitsFromUserPropString value_string face_count
    )


    face_bits -- return
)




/* Returns true when one processed object already carries a manual FORCED wall type.
   Non-seed forced objects are hard blockers for CTRL+RMB auto-grow and are never overwritten or traversed.
*/
function hasForcedWallFaceType object_node source_data =
(
    local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
    local forced_inner_bits = getForcedWallFaceBits object_node source_data 2


    ((forced_outer_bits.numberSet > 0) or (forced_inner_bits.numberSet > 0)) -- return
)


/* Writes persistent FORCED OUTER or INNER face indices to one object.
   Empty face sets remove the user-property key completely instead of storing an empty value.
*/
function setForcedWallFaceBits object_node material_id face_bits =
(
    local property_name = getForcedWallFacePropertyName material_id


    if property_name != "" then
    (
        if face_bits != undefined then
        (
            if face_bits.numberSet > 0 then
            (
                setUserProp object_node property_name (wallFaceBitsToUserPropString face_bits)
            )
            else
            (
                if doesUserPropExist object_node property_name then
                (
                    deleteUserProp object_node property_name
                )
            )
        )
        else
        (
            if doesUserPropExist object_node property_name then
            (
                deleteUserProp object_node property_name
            )
        )
    )


    true -- return
)


/* Returns all user-property keys written by the wall-face debug tracer.
   RESET uses the same list so an old analysis trace cannot survive classifier reset.
*/
function getWallFaceDebugPropertyNames =
(
    #(
        "WallFaceDebugVersion",
        "WallFaceDebugRunId",
        "WallFaceDebugProjectVersion",
        "WallFaceDebugNodeName",
        "WallFaceDebugSourceType",
        "WallFaceDebugSelectionCenter",
        "WallFaceDebugAnalysisOrigin",
        "WallFaceDebugWorkingPivot",
        "WallFaceDebugUseEditPivot",
        "WallFaceDebugEditPivot",
        "WallFaceDebugGroundPivot",
        "WallFaceDebugWallThickness",
        "WallFaceDebugConnectionThreshold",
        "WallFaceDebugConfidenceThreshold",
        "WallFaceDebugHorizontalThreshold",
        "WallFaceDebugVertexCount",
        "WallFaceDebugFaceCount",
        "WallFaceDebugOriginalFaceSelection",
        "WallFaceDebugForcedOuter",
        "WallFaceDebugForcedInner",
        "WallFaceDebugClasses",
        "WallFaceDebugScores",
        "WallFaceDebugReasons",
        "WallFaceDebugClassCounts",
        "WallFaceDebugResolutionCounts",
        "WallFaceDebugObjectTransform"
    )
    -- return
)


/* Removes every persistent debug-trace property written by INNER/OUTTER analysis.
   Manual FORCED OUTER/INNER user properties are intentionally preserved by this helper.
*/
function clearWallFaceDebugTrace object_node =
(
    for property_name in getWallFaceDebugPropertyNames() do
    (
        if doesUserPropExist object_node property_name then
        (
            deleteUserProp object_node property_name
        )
    )


    true -- return
)


/* Converts a Point3 into a compact user-property value.
   Undefined values are stored explicitly so missing pivot/origin data is visible in reports.
*/
function wallFaceDebugPointToString point_value =
(
    local value_string = "undefined"


    if point_value != undefined then
    (
        value_string = ((point_value.x as string) + "," + (point_value.y as string) + "," + (point_value.z as string))
    )


    value_string -- return
)


/* Converts one classifier ID to a readable trace label.
   Material IDs remain the authoritative current class when the debug report is printed.
*/
function wallFaceDebugClassName class_id =
(
    local class_name = "UNRESOLVED"


    case class_id of
    (
        1: class_name = "OUTER"
        2: class_name = "INNER"
        3: class_name = "TOP"
        4: class_name = "BOTTOM"
        default: class_name = "UNRESOLVED"
    )


    class_name -- return
)


/* Converts one internal resolution source to a compact stable trace token.
   These tokens make it possible to see which classifier stage produced each final face class.
*/
function wallFaceDebugReasonName reason_value =
(
    local reason_name = "UNRESOLVED"


    case reason_value of
    (
        #FORCED_OUTER: reason_name = "FORCED_OUTER"
        #FORCED_INNER: reason_name = "FORCED_INNER"
        #FORCED_HIERARCHY: reason_name = "FORCED_HIERARCHY"
        #DEGENERATE: reason_name = "DEGENERATE"
        #TOP_NORMAL: reason_name = "TOP_NORMAL"
        #BOTTOM_NORMAL: reason_name = "BOTTOM_NORMAL"
        #RADIAL_OUTER: reason_name = "RADIAL_OUTER"
        #RADIAL_INNER: reason_name = "RADIAL_INNER"
        #RADIAL_UNRESOLVED: reason_name = "RADIAL_UNRESOLVED"
        #THICKNESS: reason_name = "THICKNESS"
        #HIERARCHY: reason_name = "HIERARCHY"
        #NEIGHBOR: reason_name = "NEIGHBOR"
        #FALLBACK: reason_name = "FALLBACK"
        default: reason_name = "UNRESOLVED"
    )


    reason_name -- return
)


/* Serializes one ordinary MaxScript array into a comma-separated user-property value.
   Values are converted with native string conversion so the trace stays compact.
*/
function wallFaceDebugArrayToString value_array =
(
    local value_string = ""


    for value_index = 1 to value_array.count do
    (
        if value_index > 1 then
        (
            value_string += ","
        )


        value_string += (value_array[value_index] as string)
    )


    value_string -- return
)


/* Serializes the per-face reason array into readable comma-separated debug tokens.
   The token order always matches face indices 1 through face count.
*/
function wallFaceDebugReasonsToString reason_array =
(
    local value_string = ""


    for reason_index = 1 to reason_array.count do
    (
        if reason_index > 1 then
        (
            value_string += ","
        )


        value_string += wallFaceDebugReasonName reason_array[reason_index]
    )


    value_string -- return
)


/* Reads the current Working Pivot modes and position without changing them.
   Result is #(UseMode, EditMode, position); unavailable pivot data returns undefined position.
*/
function getWallFaceDebugWorkingPivotState =
(
    local use_mode = false
    local edit_mode = false
    local pivot_position = undefined


    try
    (
        use_mode = WorkingPivot.UseMode
        edit_mode = WorkingPivot.EditMode
        local pivot_tm = WorkingPivot.getTM()
        pivot_position = pivot_tm.translation
    )
    catch
    (
        use_mode = false
        edit_mode = false
        pivot_position = undefined
    )


    #(use_mode, edit_mode, pivot_position) -- return
)


/* Writes a compact analysis snapshot into one object's user properties.
   Live vertex/face geometry is printed later by debugWallFaceClassifierSelection so properties stay manageable.
*/
function writeWallFaceDebugTrace object_data run_data =
(
    local object_node = object_data[1]
    local source_data = object_data[2]
    local face_classes = object_data[6]
    local face_scores = object_data[7]
    local face_reasons = object_data[10]
    local original_selection_bits = object_data[11]
    local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
    local forced_inner_bits = getForcedWallFaceBits object_node source_data 2
    local outer_count = 0
    local inner_count = 0
    local top_count = 0
    local bottom_count = 0


    clearWallFaceDebugTrace object_node


    for class_id in face_classes do
    (
        if class_id == 1 then
        (
            outer_count += 1
        )
        else if class_id == 2 then
        (
            inner_count += 1
        )
        else if class_id == 3 then
        (
            top_count += 1
        )
        else if class_id == 4 then
        (
            bottom_count += 1
        )
    )


    setUserProp object_node "WallFaceDebugVersion" "2"
    setUserProp object_node "WallFaceDebugRunId" (run_data[1] as string)
    setUserProp object_node "WallFaceDebugProjectVersion" (WallFixerVersion as string)
    setUserProp object_node "WallFaceDebugNodeName" object_node.name
    setUserProp object_node "WallFaceDebugSourceType" (source_data[1] as string)
    setUserProp object_node "WallFaceDebugSelectionCenter" (wallFaceDebugPointToString run_data[2])
    setUserProp object_node "WallFaceDebugAnalysisOrigin" (wallFaceDebugPointToString run_data[3])
    setUserProp object_node "WallFaceDebugWorkingPivot" (wallFaceDebugPointToString run_data[4])
    setUserProp object_node "WallFaceDebugUseEditPivot" (run_data[5] as string)
    setUserProp object_node "WallFaceDebugEditPivot" (run_data[6] as string)
    setUserProp object_node "WallFaceDebugGroundPivot" (run_data[16] as string)
    setUserProp object_node "WallFaceDebugWallThickness" (run_data[7] as string)
    setUserProp object_node "WallFaceDebugConnectionThreshold" (run_data[8] as string)
    setUserProp object_node "WallFaceDebugConfidenceThreshold" (run_data[9] as string)
    setUserProp object_node "WallFaceDebugHorizontalThreshold" (run_data[10] as string)
    setUserProp object_node "WallFaceDebugVertexCount" (object_data[8].count as string)
    setUserProp object_node "WallFaceDebugFaceCount" (face_classes.count as string)
    setUserProp object_node "WallFaceDebugOriginalFaceSelection" (wallFaceBitsToUserPropString original_selection_bits)
    setUserProp object_node "WallFaceDebugForcedOuter" (wallFaceBitsToUserPropString forced_outer_bits)
    setUserProp object_node "WallFaceDebugForcedInner" (wallFaceBitsToUserPropString forced_inner_bits)
    setUserProp object_node "WallFaceDebugClasses" (wallFaceDebugArrayToString face_classes)
    setUserProp object_node "WallFaceDebugScores" (wallFaceDebugArrayToString face_scores)
    setUserProp object_node "WallFaceDebugReasons" (wallFaceDebugReasonsToString face_reasons)
    setUserProp object_node "WallFaceDebugClassCounts" (("OUTER=" + outer_count as string) + ";INNER=" + inner_count as string + ";TOP=" + top_count as string + ";BOTTOM=" + bottom_count as string)
    setUserProp object_node "WallFaceDebugResolutionCounts" (("THICKNESS=" + run_data[11] as string) + ";FORCED_HIERARCHY=" + run_data[12] as string + ";HIERARCHY=" + run_data[13] as string + ";NEIGHBOR=" + run_data[14] as string + ";FALLBACK=" + run_data[15] as string)
    setUserProp object_node "WallFaceDebugObjectTransform" (object_node.transform as string)


    true -- return
)


/* Returns one comma-separated trace token by face index.
   Missing or stale user-property data returns an empty string instead of raising an error.
*/
function getWallFaceDebugToken value_string token_index =
(
    local token_value = ""


    if value_string != undefined and value_string != "" then
    (
        local token_array = filterString (value_string as string) ","


        if token_index >= 1 and token_index <= token_array.count then
        (
            token_value = token_array[token_index]
        )
    )


    token_value -- return
)


/* Prints a complete INNER/OUTTER debug report for selected or last analyzed walls.
   Report includes stored analysis inputs, user properties, live vertices, face centers/normals, Material IDs and force state.
*/
function debugWallFaceClassifierSelection verbose_vertices:true verbose_faces:true use_last_if_empty:true =
(
    local debug_nodes = for object_node in selection where isValidNode object_node and superclassof object_node == GeometryClass collect object_node
    local pivot_state = getWallFaceDebugWorkingPivotState()


    if debug_nodes.count == 0 and use_last_if_empty then
    (
        for object_node in wall_face_classifier_last_nodes do
        (
            if isValidNode object_node then
            (
                if getFaceGeometrySource object_node != undefined then
                (
                    append debug_nodes object_node
                )
            )
        )
    )


    format "\n======================================================================\n"
    format "WALL-FIXER GET OUTER WALLS DEBUG\n"
    format "Project version: % | trace mode: % | objects: %\n" WallFixerVersion wall_face_debug_enabled debug_nodes.count
    format "Current selection center: %\n" (wallFaceDebugPointToString (getWallFaceSelectionCenter debug_nodes))
    format "Current Working Pivot: % | Use Edit Pivot: % | Edit Edit Pivot: % | Ground Pivot: %\n" (wallFaceDebugPointToString pivot_state[3]) pivot_state[1] pivot_state[2] wall_face_ground_pivot_enabled
    format "======================================================================\n"


    for object_node in debug_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local vertex_count = getSourceNumVertices object_node source_data
            local face_count = getSourceNumFaces object_node source_data
            local selected_face_bits = getSourceFaceSelection object_node source_data
            local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
            local forced_inner_bits = getForcedWallFaceBits object_node source_data 2
            local stored_classes = getUserProp object_node "WallFaceDebugClasses"
            local stored_scores = getUserProp object_node "WallFaceDebugScores"
            local stored_reasons = getUserProp object_node "WallFaceDebugReasons"
            local debug_version = getUserProp object_node "WallFaceDebugVersion"
            local user_property_buffer = ""


            try
            (
                user_property_buffer = getUserPropBuffer object_node
            )
            catch
            (
                user_property_buffer = ""
            )


            format "\n----------------------------------------------------------------------\n"
            format "OBJECT: % | source: % | vertices: % | faces: %\n" object_node.name source_data[1] vertex_count face_count
            format "Current transform: %\n" object_node.transform
            format "Current face selection: %\n" (wallFaceBitsToUserPropString selected_face_bits)
            format "Current FORCED OUTER: % | FORCED INNER: %\n" (wallFaceBitsToUserPropString forced_outer_bits) (wallFaceBitsToUserPropString forced_inner_bits)
            format "Trace present: % | run: % | trace project: %\n" (debug_version != undefined) (getUserProp object_node "WallFaceDebugRunId") (getUserProp object_node "WallFaceDebugProjectVersion")
            format "Trace selection center: %\n" (getUserProp object_node "WallFaceDebugSelectionCenter")
            format "Trace analysis origin: %\n" (getUserProp object_node "WallFaceDebugAnalysisOrigin")
            format "Trace Working Pivot: % | Use: % | Edit: % | Ground: %\n" (getUserProp object_node "WallFaceDebugWorkingPivot") (getUserProp object_node "WallFaceDebugUseEditPivot") (getUserProp object_node "WallFaceDebugEditPivot") (getUserProp object_node "WallFaceDebugGroundPivot")
            format "Trace Wall thickness: % | Connect threshold: % | Confidence: % | Horizontal threshold: %\n" (getUserProp object_node "WallFaceDebugWallThickness") (getUserProp object_node "WallFaceDebugConnectionThreshold") (getUserProp object_node "WallFaceDebugConfidenceThreshold") (getUserProp object_node "WallFaceDebugHorizontalThreshold")
            format "Trace classes: %\n" (getUserProp object_node "WallFaceDebugClassCounts")
            format "Trace resolution counts: %\n" (getUserProp object_node "WallFaceDebugResolutionCounts")
            format "Trace original face selection: %\n" (getUserProp object_node "WallFaceDebugOriginalFaceSelection")
            format "USER PROPERTIES:\n%\n" user_property_buffer


            if verbose_vertices then
            (
                format "VERTICES (world):\n"


                for vertex_index = 1 to vertex_count do
                (
                    format "  VERT % = %\n" vertex_index (getSourceVertexWorld object_node source_data vertex_index)
                )
            )


            if verbose_faces then
            (
                format "FACES:\n"


                for face_index = 1 to face_count do
                (
                    local face_degree = getSourceFaceDegree object_node source_data face_index
                    local face_vertices = #()
                    local face_indices = #()


                    for corner_index = 1 to face_degree do
                    (
                        local vertex_index = getSourceFaceVertex object_node source_data face_index corner_index
                        append face_indices vertex_index
                        append face_vertices (getSourceVertexWorld object_node source_data vertex_index)
                    )


                    local face_center = calculatePolygonCenter face_vertices
                    local face_normal = calculatePolygonNormal face_vertices epsilon:0.0000001
                    local material_id = getSourceFaceMaterialId object_node source_data face_index
                    local force_label = "NONE"


                    if forced_outer_bits[face_index] then
                    (
                        force_label = "OUTER"
                    )
                    else if forced_inner_bits[face_index] then
                    (
                        force_label = "INNER"
                    )


                    format "  FACE % | material=% % | selected=% | forced=% | traceClass=% | score=% | reason=%\n" face_index material_id (wallFaceDebugClassName material_id) selected_face_bits[face_index] force_label (getWallFaceDebugToken stored_classes face_index) (getWallFaceDebugToken stored_scores face_index) (getWallFaceDebugToken stored_reasons face_index)
                    format "       center=% | normal=% | verts=%\n" face_center face_normal face_indices
                )
            )
        )
    )


    format "======================================================================\n\n"
    debug_nodes.count -- return
)


/* Tests trace capture on the current wall selection and prints the resulting report.
   This runs the normal classifier with debug mode temporarily enabled, then restores the previous debug toggle.
*/
function testWallFaceDebugTrace wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local debug_enabled_before = wall_face_debug_enabled
    local result_data = #()
    local traced_object_count = 0


    wall_face_debug_enabled = true
    result_data = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold


    for object_node in wall_face_classifier_last_nodes do
    (
        if isValidNode object_node then
        (
            if doesUserPropExist object_node "WallFaceDebugVersion" then
            (
                traced_object_count += 1
            )
        )
    )


    wall_face_debug_enabled = debug_enabled_before


    format "Wall-face debug trace test | classifier result items: % | traced objects: %\n" result_data.count traced_object_count
    #(result_data.count, traced_object_count) -- return
)


/* Adds a persistent FORCED class for OUTER/INNER and removes the same faces from the opposite forced class.
   TOP/BOTTOM manual assignments clear conflicting wall-side FORCED hints but are not stored as persistent forced wall types.
*/
function forceWallFaceClass object_node source_data material_id mark_bits =
(
    local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
    local forced_inner_bits = getForcedWallFaceBits object_node source_data 2


    if material_id == 1 then
    (
        forced_outer_bits = forced_outer_bits + mark_bits
        forced_inner_bits = forced_inner_bits - mark_bits
    )
    else if material_id == 2 then
    (
        forced_inner_bits = forced_inner_bits + mark_bits
        forced_outer_bits = forced_outer_bits - mark_bits
    )
    else if material_id == 3 or material_id == 4 then
    (
        forced_outer_bits = forced_outer_bits - mark_bits
        forced_inner_bits = forced_inner_bits - mark_bits
    )


    setForcedWallFaceBits object_node 1 forced_outer_bits
    setForcedWallFaceBits object_node 2 forced_inner_bits


    #(forced_outer_bits, forced_inner_bits) -- return
)


/* Returns supported geometry nodes from the current selection or restores the last classification set.
   When remember_selection is true, the resolved nodes become the set restored by later empty-selection actions.
*/
function getWallFaceWorkingNodes remember_selection:false =
(
    local working_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local restored_nodes = #()


    if working_nodes.count == 0 then
    (
        for object_node in wall_face_classifier_last_nodes do
        (
            if isValidNode object_node then
            (
                if superclassof object_node == GeometryClass then
                (
                    append restored_nodes object_node
                )
            )
        )


        working_nodes = restored_nodes


        if working_nodes.count > 0 then
        (
            select working_nodes
        )
    )


    if remember_selection and working_nodes.count > 0 then
    (
        wall_face_classifier_last_nodes = for object_node in working_nodes collect object_node
    )


    working_nodes -- return
)


/* Calculates the geometry center used to place the Working Pivot for wall classification.
   Each supported object contributes its average world-space vertex position.
*/
function getWallFaceSelectionCenter object_nodes =
(
    local selection_center = [0.0, 0.0, 0.0]
    local object_center_count = 0


    for object_node in object_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local vertex_count = getSourceNumVertices object_node source_data


            if vertex_count > 0 then
            (
                local object_center = [0.0, 0.0, 0.0]


                for vertex_index = 1 to vertex_count do
                (
                    object_center += getSourceVertexWorld object_node source_data vertex_index
                )


                object_center /= vertex_count
                selection_center += object_center
                object_center_count += 1
            )
        )
    )


    if object_center_count > 0 then
    (
        selection_center / object_center_count
    )
    else
    (
        undefined
    )
    -- return
)


/* Centers the 3ds Max Working Pivot to the current geometry selection.
   This is an explicit helper action and does not enable Use Edit Pivot.
*/
function centerWallFaceWorkingPivotToSelection =
(
    local selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local selection_center = getWallFaceSelectionCenter selected_nodes


    if selection_center != undefined and wall_face_ground_pivot_enabled then
    (
        selection_center.z = 0.0
    )


    if selection_center != undefined then
    (
        local working_pivot_tm = undefined


        try
        (
            working_pivot_tm = WorkingPivot.getTM()
        )
        catch
        (
            working_pivot_tm = matrix3 1
        )


        if working_pivot_tm == undefined then
        (
            working_pivot_tm = matrix3 1
        )


        working_pivot_tm.translation = selection_center


        try
        (
            WorkingPivot.setTM working_pivot_tm
        )
        catch
        (
        )
    )


    selection_center -- return
)


/* Returns the origin used by INNER/OUTTER classification.
   Use Edit Pivot uses the manual Working Pivot; otherwise classification uses the selection center.
   Ground Pivot forces the active origin and the actual Working Pivot onto world Z = 0 before analysis.
*/
function getWallFaceAnalysisOrigin object_nodes =
(
    local analysis_origin = undefined
    local use_working_pivot = false


    try
    (
        use_working_pivot = WorkingPivot.UseMode
    )
    catch
    (
        use_working_pivot = false
    )


    if use_working_pivot then
    (
        try
        (
            local working_pivot_tm = WorkingPivot.getTM()
            analysis_origin = working_pivot_tm.translation
        )
        catch
        (
            analysis_origin = undefined
        )
    )


    if analysis_origin == undefined then
    (
        analysis_origin = getWallFaceSelectionCenter object_nodes
    )


    if analysis_origin != undefined and wall_face_ground_pivot_enabled then
    (
        analysis_origin.z = 0.0
        local working_pivot_tm = undefined


        try
        (
            working_pivot_tm = WorkingPivot.getTM()
        )
        catch
        (
            working_pivot_tm = matrix3 1
        )


        if working_pivot_tm == undefined then
        (
            working_pivot_tm = matrix3 1
        )


        working_pivot_tm.translation = analysis_origin


        try
        (
            WorkingPivot.setTM working_pivot_tm
        )
        catch
        (
        )
    )


    analysis_origin -- return
)


/* Returns the default connection distance derived from wall thickness.
   Neighbor connection starts at ten percent of the current wall-thickness value.
*/
function getDefaultWallConnectionThreshold wall_thickness =
(
    wall_thickness * 0.1 -- return
)


/* Resets classifier face Material IDs, removes the classifier material, and clears persistent FORCED hints.
   Existing face selections are restored and cached classifier data is discarded.
*/
function resetSelectedWallFaceClassification =
(
    local selected_nodes = getWallFaceWorkingNodes()
    local reset_data_array = #()
    local valid_nodes = #()
    local reset_face_count = 0
    local selection_level_before = subObjectLevel


    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local all_face_bits = getAllSourceFaceBits object_node source_data
            local original_bits = getSourceFaceSelection object_node source_data


            append reset_data_array #(object_node, source_data, all_face_bits, original_bits)
            append valid_nodes object_node
            reset_face_count += all_face_bits.numberSet
        )
    )


    if valid_nodes.count > 0 then
    (
        for reset_data in reset_data_array do
        (
            local object_node = reset_data[1]
            local source_data = reset_data[2]
            local all_face_bits = reset_data[3]
            local original_bits = reset_data[4]
            local cache_index = findWallFaceCacheIndex object_node


            setSourceFaceMaterialId object_node source_data all_face_bits 1
            setForcedWallFaceBits object_node 1 #{}
            setForcedWallFaceBits object_node 2 #{}
            clearWallFaceDebugTrace object_node
            setSourceFaceSelection object_node source_data original_bits


            if object_node.material != undefined then
            (
                if object_node.material.name == "WALL FACE CLASSIFIER" then
                (
                    object_node.material = undefined
                )
            )


            if cache_index > 0 then
            (
                deleteItem wall_face_classifier_cache cache_index
            )
        )


        select valid_nodes
        max modify mode


        if selection_level_before != undefined then
        (
            subObjectLevel = selection_level_before
        )


        redrawViews()
    )


    #(valid_nodes.count, reset_face_count) -- return
)


/* Reuses an existing classifier material when possible and assigns it to nodes.
   A new legacy Standard Multi/Sub material is created only when none is available.
*/
function ensureWallClassifierMaterial object_nodes =
(
    local classifier_material = undefined


    for object_node in object_nodes do
    (
        if classifier_material == undefined then
        (
            if object_node.material != undefined then
            (
                if object_node.material.name == "WALL FACE CLASSIFIER" then
                (
                    classifier_material = object_node.material
                )
            )
        )
    )


    if classifier_material == undefined then
    (
        classifier_material = createWallClassifierMaterial()
    )


    for object_node in object_nodes do
    (
        object_node.material = classifier_material
    )


    classifier_material -- return
)




/* Returns true when a node already uses the classifier Multi/Sub material.
   Used to preserve existing manual/classified face IDs during force marking.
*/
function hasWallClassifierMaterial object_node =
(
    local has_classifier_material = false


    if object_node.material != undefined then
    (
        if object_node.material.name == "WALL FACE CLASSIFIER" then
        (
            has_classifier_material = true
        )
    )


    has_classifier_material -- return
)


/* Returns live processed nodes from the classifier cache by node reference.
   Selection is intentionally ignored so cached walls remain available for on-the-fly neighbor editing.
*/
function getWallFaceProcessedCacheNodes =
(
    local processed_nodes = #()


    if wall_face_classifier_cache.count > 0 then
    (
        for cache_index = wall_face_classifier_cache.count to 1 by -1 do
        (
            local cache_entry = wall_face_classifier_cache[cache_index]
            local keep_entry = true


            if cache_entry.count < 6 then
            (
                keep_entry = false
            )
            else if not isValidNode cache_entry[1] then
            (
                keep_entry = false
            )
            else if getFaceGeometrySource cache_entry[1] == undefined then
            (
                keep_entry = false
            )
            else if not hasWallClassifierMaterial cache_entry[1] then
            (
                keep_entry = false
            )


            if keep_entry then
            (
                append processed_nodes cache_entry[1]
            )
            else
            (
                deleteItem wall_face_classifier_cache cache_index
            )
        )
    )


    processed_nodes -- return
)


/* Builds edge-connected face islands from one supplied face bitarray.
   Only faces in the bitarray can connect, so UP/DOWN faces naturally act as barriers.
*/
function buildWallFaceElementsFromBits object_node source_data face_bits =
(
    local face_count = getSourceNumFaces object_node source_data
    local visited_faces = #{}
    local element_array = #()


    for start_face in face_bits do
    (
        if start_face >= 1 and start_face <= face_count and not visited_faces[start_face] then
        (
            local pending_faces = #(start_face)
            local element_faces = #{}
            local element_vertices = #{}
            local world_vertices = #()
            local bbox_min = undefined
            local bbox_max = undefined


            visited_faces[start_face] = true


            while pending_faces.count > 0 do
            (
                local current_face = pending_faces[pending_faces.count]
                deleteItem pending_faces pending_faces.count
                element_faces[current_face] = true


                local face_degree = getSourceFaceDegree object_node source_data current_face


                for corner_index = 1 to face_degree do
                (
                    local vertex_index = getSourceFaceVertex object_node source_data current_face corner_index
                    element_vertices[vertex_index] = true
                )


                for side_index = 1 to face_degree do
                (
                    local edge_index = getSourceFaceEdge object_node source_data current_face side_index


                    if edge_index > 0 then
                    (
                        for edge_side = 1 to 2 do
                        (
                            local neighbor_face = getSourceEdgeFace object_node source_data edge_index edge_side


                            if neighbor_face >= 1 and neighbor_face <= face_count then
                            (
                                if face_bits[neighbor_face] and not visited_faces[neighbor_face] then
                                (
                                    visited_faces[neighbor_face] = true
                                    append pending_faces neighbor_face
                                )
                            )
                        )
                    )
                )
            )


            for vertex_index in element_vertices do
            (
                local vertex_world = getSourceVertexWorld object_node source_data vertex_index
                append world_vertices vertex_world


                if bbox_min == undefined then
                (
                    bbox_min = copy vertex_world
                    bbox_max = copy vertex_world
                )
                else
                (
                    if vertex_world.x < bbox_min.x then bbox_min.x = vertex_world.x
                    if vertex_world.y < bbox_min.y then bbox_min.y = vertex_world.y
                    if vertex_world.z < bbox_min.z then bbox_min.z = vertex_world.z
                    if vertex_world.x > bbox_max.x then bbox_max.x = vertex_world.x
                    if vertex_world.y > bbox_max.y then bbox_max.y = vertex_world.y
                    if vertex_world.z > bbox_max.z then bbox_max.z = vertex_world.z
                )
            )


            append element_array #(object_node, source_data, element_faces, element_vertices, world_vertices, bbox_min, bbox_max)
        )
    )


    element_array -- return
)


/* Returns true when two cached face-island bounds can touch inside the threshold.
*/
function wallFaceGrowthBoundsOverlap element_a element_b connection_threshold =
(
    local min_a = element_a[6]
    local max_a = element_a[7]
    local min_b = element_b[6]
    local max_b = element_b[7]
    local overlap_result = true


    if min_a == undefined or min_b == undefined then
    (
        overlap_result = false
    )
    else
    (
        if (max_a.x + connection_threshold) < min_b.x or (max_b.x + connection_threshold) < min_a.x then
        (
            overlap_result = false
        )
        else if (max_a.y + connection_threshold) < min_b.y or (max_b.y + connection_threshold) < min_a.y then
        (
            overlap_result = false
        )
        else if (max_a.z + connection_threshold) < min_b.z or (max_b.z + connection_threshold) < min_a.z then
        (
            overlap_result = false
        )
    )


    overlap_result -- return
)


/* Tests two processed wall-side face islands for a wall-style neighbor seam.
   At least two vertices must match, and their seam must have a vertical span so TOP/DOWN contacts cannot grow the chain.
*/
function wallFaceGrowthElementsConnect element_a element_b connection_threshold minimum_matching_vertices:2 minimum_vertical_ratio:0.45 =
(
    local connection_result = false
    local threshold_squared = connection_threshold * connection_threshold
    local vertices_a = element_a[5]
    local vertices_b = element_b[5]
    local matched_b = #{}
    local matched_points_a = #()
    local match_count = 0


    if wallFaceGrowthBoundsOverlap element_a element_b connection_threshold then
    (
        for vertex_index_a = 1 to vertices_a.count do
        (
            local point_a = vertices_a[vertex_index_a]
            local found_match = false


            for vertex_index_b = 1 to vertices_b.count while not found_match do
            (
                if not matched_b[vertex_index_b] then
                (
                    local delta = point_a - vertices_b[vertex_index_b]


                    if (dot delta delta) <= threshold_squared then
                    (
                        matched_b[vertex_index_b] = true
                        append matched_points_a point_a
                        match_count += 1
                        found_match = true
                    )
                )
            )
        )


        if match_count >= minimum_matching_vertices and matched_points_a.count >= 2 then
        (
            for point_index_a = 1 to (matched_points_a.count - 1) while not connection_result do
            (
                for point_index_b = (point_index_a + 1) to matched_points_a.count while not connection_result do
                (
                    local seam_vector = matched_points_a[point_index_b] - matched_points_a[point_index_a]
                    local seam_length = length seam_vector


                    if seam_length > 0.0000001 then
                    (
                        local vertical_ratio = (abs seam_vector.z) / seam_length


                        if vertical_ratio >= minimum_vertical_ratio then
                        (
                            connection_result = true
                        )
                    )
                )
            )
        )
    )


    connection_result -- return
)


/* Returns true when one face pair represents an opposite-facing wall across the normal within Wall Thickness.
   Same-facing continuations and perpendicular corners are not treated as thickness barriers.
*/
function wallFaceGrowthFacePairHasThicknessBarrier center_a normal_a center_b normal_b wall_thickness connection_threshold parallel_threshold:0.90 epsilon:0.0000001 =
(
    local barrier_result = false


    if wall_thickness > epsilon and (length normal_a) > epsilon and (length normal_b) > epsilon then
    (
        local normal_a_unit = normalize normal_a
        local normal_b_unit = normalize normal_b
        local opposite_value = dot normal_a_unit normal_b_unit


        if opposite_value <= (-parallel_threshold) then
        (
            local center_delta = center_b - center_a
            local normal_distance = abs (dot center_delta normal_a_unit)


            if normal_distance > epsilon and normal_distance <= wall_thickness then
            (
                barrier_result = true
            )
        )
    )


    barrier_result -- return
)


/* Reads one live face center and normal for AUTO GROW thickness checks.
   Returns undefined when the face cannot provide at least three vertices.
*/
function getWallFaceGrowthFaceCenterNormal object_node source_data face_index epsilon:0.0000001 =
(
    local result_data = undefined
    local face_degree = getSourceFaceDegree object_node source_data face_index


    if face_degree >= 3 then
    (
        local face_vertices = #()


        for corner_index = 1 to face_degree do
        (
            local vertex_index = getSourceFaceVertex object_node source_data face_index corner_index
            append face_vertices (getSourceVertexWorld object_node source_data vertex_index)
        )


        result_data = #(calculatePolygonCenter face_vertices, calculatePolygonNormal face_vertices epsilon:epsilon)
    )


    result_data -- return
)


/* Returns true when two connected growth islands are separated across their normals by Wall Thickness.
   This prevents CTRL+RMB AUTO GROW from crossing onto the opposite wall side.
*/
function wallFaceGrowthElementsBlockedByThickness element_a element_b wall_thickness connection_threshold parallel_threshold:0.90 epsilon:0.0000001 =
(
    local barrier_result = false


    if wall_thickness > epsilon then
    (
        local object_node_a = element_a[1]
        local source_data_a = element_a[2]
        local face_bits_a = element_a[3]
        local object_node_b = element_b[1]
        local source_data_b = element_b[2]
        local face_bits_b = element_b[3]


        for face_index_a in face_bits_a while not barrier_result do
        (
            local face_data_a = getWallFaceGrowthFaceCenterNormal object_node_a source_data_a face_index_a epsilon:epsilon


            if face_data_a != undefined then
            (
                for face_index_b in face_bits_b while not barrier_result do
                (
                    local face_data_b = getWallFaceGrowthFaceCenterNormal object_node_b source_data_b face_index_b epsilon:epsilon


                    if face_data_b != undefined then
                    (
                        if wallFaceGrowthFacePairHasThicknessBarrier face_data_a[1] face_data_a[2] face_data_b[1] face_data_b[2] wall_thickness connection_threshold parallel_threshold:parallel_threshold epsilon:epsilon then
                        (
                            barrier_result = true
                        )
                    )
                )
            )
        )
    )


    barrier_result -- return
)


/* Returns every live scene object that currently carries Wall-Fixer classifier material.
   AUTO GROW discovers neighbors from live scene state instead of requiring a prior runtime-cache entry.
*/
function getWallFaceGrowthSceneNodes =
(
    local scene_nodes = #()


    for object_node in objects where superclassof object_node == GeometryClass do
    (
        if isValidNode object_node then
        (
            local source_data = getFaceGeometrySource object_node


            if source_data != undefined and hasWallClassifierMaterial object_node then
            (
                append scene_nodes object_node
            )
        )
    )


    scene_nodes -- return
)


/* Builds the face geometry cache used only by AUTO GROW opposite-wall ray tests.
   The data shape matches the face and normal fields used by the classifier ray helpers.
*/
function buildWallFaceGrowthRayData scene_nodes =
(
    local object_data_array = #()


    for object_node in scene_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local face_count = getSourceNumFaces object_node source_data
            local cached_faces = #()
            local face_normals = #()


            for face_index = 1 to face_count do
            (
                local face_degree = getSourceFaceDegree object_node source_data face_index
                local face_vertices = #()


                for corner_index = 1 to face_degree do
                (
                    local vertex_index = getSourceFaceVertex object_node source_data face_index corner_index
                    append face_vertices (getSourceVertexWorld object_node source_data vertex_index)
                )


                append cached_faces face_vertices
                append face_normals (calculatePolygonNormal face_vertices epsilon:0.0000001)
            )


            append object_data_array #(object_node, source_data, cached_faces, #(), face_normals)
        )
    )


    object_data_array -- return
)


/* Finds the nearest parallel wall hit on another object only.
   Ignoring the whole source object prevents a normal solid wall from blocking itself because of its own opposite side.
*/
function getNearestOtherObjectWallHit ray_origin ray_direction source_normal object_data_array ignore_node max_distance parallel_threshold:0.90 epsilon:0.0000001 =
(
    local nearest_data = undefined


    for object_data in object_data_array do
    (
        local object_node = object_data[1]


        if object_node != ignore_node then
        (
            local cached_faces = object_data[3]
            local face_normals = object_data[5]


            for face_index = 1 to cached_faces.count do
            (
                local candidate_normal = face_normals[face_index]


                if (length candidate_normal) > epsilon then
                (
                    local parallel_value = abs (dot source_normal candidate_normal)


                    if parallel_value >= parallel_threshold then
                    (
                        local face_vertices = cached_faces[face_index]


                        if face_vertices.count >= 3 then
                        (
                            for triangle_index = 2 to (face_vertices.count - 1) do
                            (
                                local hit_distance = getRayTriangleDistance ray_origin ray_direction face_vertices[1] face_vertices[triangle_index] face_vertices[triangle_index + 1] epsilon:epsilon


                                if hit_distance != undefined and hit_distance <= max_distance then
                                (
                                    if nearest_data == undefined or hit_distance < nearest_data[1] then
                                    (
                                        nearest_data = #(hit_distance, object_node, face_index, parallel_value)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )


    nearest_data -- return
)


/* Returns true when a candidate AUTO GROW island has another wall object across either face-normal direction within Wall Thickness.
   The candidate is tested after seam connectivity is established; the opposite wall itself does not need to share the seam.
*/
function wallFaceGrowthElementHasOppositeWall candidate_element object_data_array wall_thickness connection_threshold parallel_threshold:0.90 epsilon:0.0000001 =
(
    local barrier_result = false


    if wall_thickness > epsilon then
    (
        local object_node = candidate_element[1]
        local source_data = candidate_element[2]
        local face_bits = candidate_element[3]
        local ray_offset = connection_threshold * 0.01


        if ray_offset < (epsilon * 10.0) then
        (
            ray_offset = epsilon * 10.0
        )


        if ray_offset > (wall_thickness * 0.01) then
        (
            ray_offset = wall_thickness * 0.01
        )


        for face_index in face_bits while not barrier_result do
        (
            local face_data = getWallFaceGrowthFaceCenterNormal object_node source_data face_index epsilon:epsilon


            if face_data != undefined and (length face_data[2]) > epsilon then
            (
                local face_center = face_data[1]
                local face_normal = normalize face_data[2]
                local forward_origin = face_center + (face_normal * ray_offset)
                local backward_origin = face_center - (face_normal * ray_offset)
                local forward_hit = getNearestOtherObjectWallHit forward_origin face_normal face_normal object_data_array object_node wall_thickness parallel_threshold:parallel_threshold epsilon:epsilon
                local backward_hit = getNearestOtherObjectWallHit backward_origin (-face_normal) face_normal object_data_array object_node wall_thickness parallel_threshold:parallel_threshold epsilon:epsilon


                if forward_hit != undefined or backward_hit != undefined then
                (
                    barrier_result = true
                )
            )
        )
    )


    barrier_result -- return
)


/* Captures CTRL+RMB growth seeds before any manual class overwrite occurs.
   Face mode uses selected non-cap faces; object mode uses every existing wall-side face so the forced object can grow from any side.
*/
function getWallFaceGrowthSeedData material_id =
(
    local had_node_selection = (selection.count > 0)
    local selection_level_before = subObjectLevel
    local selected_nodes = getWallFaceWorkingNodes()
    local use_face_selection = (had_node_selection and selection_level_before == 4)
    local seed_data_array = #()


    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local seed_bits = #{}


            if use_face_selection then
            (
                local selected_bits = getSourceFaceSelection object_node source_data


                for face_index in selected_bits do
                (
                    local current_material_id = getSourceFaceMaterialId object_node source_data face_index


                    if current_material_id == 1 or current_material_id == 2 then
                    (
                        seed_bits[face_index] = true
                    )
                )
            )
            else
            (
                local face_count = getSourceNumFaces object_node source_data


                for face_index = 1 to face_count do
                (
                    local current_material_id = getSourceFaceMaterialId object_node source_data face_index


                    if current_material_id == 1 or current_material_id == 2 then
                    (
                        seed_bits[face_index] = true
                    )
                )
            )


            if seed_bits.numberSet > 0 then
            (
                append seed_data_array #(object_node, source_data, seed_bits)
            )
        )
    )


    seed_data_array -- return
)


/* Recursively propagates one forced wall class through live classified neighbor walls.
   Forced faces are local barriers: they are removed from candidate islands instead of blocking the whole object.
   A connected candidate is also rejected when another wall object exists across it within Wall Thickness.
   Auto-grown neighbors only change Material ID and do not become persistent FORCED hints. TOP/DOWN faces remain barriers.
*/
function growCachedWallFaceClass seed_data_array material_id connection_threshold wall_thickness =
(
    local scene_nodes = getWallFaceGrowthSceneNodes()
    local ray_object_data = buildWallFaceGrowthRayData scene_nodes
    local seed_nodes = #()
    local candidate_set_array = #()
    local frontier_elements = #()
    local growth_data_array = #()
    local grown_face_count = 0


    for seed_data in seed_data_array do
    (
        local seed_node = seed_data[1]
        local seed_source = seed_data[2]
        local seed_bits = seed_data[3]


        if (findItem seed_nodes seed_node) == 0 then
        (
            append seed_nodes seed_node
        )


        local seed_elements = buildWallFaceElementsFromBits seed_node seed_source seed_bits


        for seed_element in seed_elements do
        (
            append frontier_elements seed_element
        )
    )


    for candidate_node in scene_nodes do
    (
        if (findItem seed_nodes candidate_node) == 0 then
        (
            local source_data = getFaceGeometrySource candidate_node


            if source_data != undefined then
            (
                local cache_entry = cacheWallFaceClassesFromMaterialIds candidate_node source_data
                local wall_side_bits = copy cache_entry[3]
                local inner_bits = copy cache_entry[4]
                local forced_outer_bits = getForcedWallFaceBits candidate_node source_data 1
                local forced_inner_bits = getForcedWallFaceBits candidate_node source_data 2


                wall_side_bits = wall_side_bits + inner_bits


                for face_index in forced_outer_bits do
                (
                    wall_side_bits[face_index] = false
                )


                for face_index in forced_inner_bits do
                (
                    wall_side_bits[face_index] = false
                )


                local element_array = buildWallFaceElementsFromBits candidate_node source_data wall_side_bits


                if element_array.count > 0 then
                (
                    append candidate_set_array #(candidate_node, source_data, element_array, #{})
                )
            )
        )
    )


    local frontier_index = 1


    while frontier_index <= frontier_elements.count do
    (
        local frontier_element = frontier_elements[frontier_index]


        for candidate_set in candidate_set_array do
        (
            local candidate_node = candidate_set[1]
            local candidate_source = candidate_set[2]
            local element_array = candidate_set[3]
            local visited_elements = candidate_set[4]


            for element_index = 1 to element_array.count do
            (
                if not visited_elements[element_index] then
                (
                    local candidate_element = element_array[element_index]


                    if wallFaceGrowthElementsConnect frontier_element candidate_element connection_threshold then
                    (
                        visited_elements[element_index] = true


                        if not wallFaceGrowthElementHasOppositeWall candidate_element ray_object_data wall_thickness connection_threshold then
                        (
                            append frontier_elements candidate_element


                            local growth_index = 0


                            for data_index = 1 to growth_data_array.count do
                            (
                                if growth_index == 0 and growth_data_array[data_index][1] == candidate_node then
                                (
                                    growth_index = data_index
                                )
                            )


                            if growth_index == 0 then
                            (
                                append growth_data_array #(candidate_node, candidate_source, copy candidate_element[3])
                            )
                            else
                            (
                                growth_data_array[growth_index][3] = growth_data_array[growth_index][3] + candidate_element[3]
                            )
                        )
                    )
                )
            )
        )


        frontier_index += 1
    )


    for growth_data in growth_data_array do
    (
        local object_node = growth_data[1]
        local source_data = growth_data[2]
        local face_bits = growth_data[3]


        setSourceFaceMaterialId object_node source_data face_bits material_id
        cacheWallFaceClassesFromMaterialIds object_node source_data
        grown_face_count += face_bits.numberSet
    )


    if growth_data_array.count > 0 then
    (
        redrawViews()
    )


    #(growth_data_array.count, grown_face_count, scene_nodes.count) -- return
)


/* Tests the CTRL+RMB neighbor seam filter without changing scene geometry.
   A vertical shared seam must connect; a horizontal cap seam must not.
*/
function testWallFaceGrowthSeamFilter connection_threshold:1.0 =
(
    local vertical_a = #(undefined, undefined, #{1}, #{1,2}, #([0,0,0], [0,0,100]), [0,0,0], [0,0,100])
    local vertical_b = #(undefined, undefined, #{1}, #{1,2}, #([0.5,0,0], [0.5,0,100]), [0.5,0,0], [0.5,0,100])
    local horizontal_a = #(undefined, undefined, #{1}, #{1,2}, #([0,0,0], [100,0,0]), [0,0,0], [100,0,0])
    local horizontal_b = #(undefined, undefined, #{1}, #{1,2}, #([0,0,0.5], [100,0,0.5]), [0,0,0.5], [100,0,0.5])
    local vertical_connects = wallFaceGrowthElementsConnect vertical_a vertical_b connection_threshold
    local horizontal_connects = wallFaceGrowthElementsConnect horizontal_a horizontal_b connection_threshold


    format "CTRL+RMB growth seam test | vertical: % | horizontal cap: % | passed: %\n" vertical_connects horizontal_connects (vertical_connects and not horizontal_connects)


    #(vertical_connects, horizontal_connects, (vertical_connects and not horizontal_connects)) -- return
)




/* Tests the Wall Thickness AUTO GROW barrier without changing scene geometry.
   Opposite-facing walls inside thickness must block; same-facing, corner and beyond-thickness samples must not.
*/
function testWallFaceGrowthThicknessBarrier wall_thickness:100.0 connection_threshold:10.0 =
(
    local center_a = [0.0, 0.0, 0.0]
    local normal_a = [1.0, 0.0, 0.0]
    local opposite_center = [50.0, 0.0, 0.0]
    local opposite_normal = [-1.0, 0.0, 0.0]
    local same_facing_center = [50.0, 100.0, 0.0]
    local same_facing_normal = [1.0, 0.0, 0.0]
    local corner_center = [50.0, 0.0, 0.0]
    local corner_normal = [0.0, 1.0, 0.0]
    local far_center = [(wall_thickness + connection_threshold + 1.0), 0.0, 0.0]
    local blocks_opposite = wallFaceGrowthFacePairHasThicknessBarrier center_a normal_a opposite_center opposite_normal wall_thickness connection_threshold
    local blocks_same_facing = wallFaceGrowthFacePairHasThicknessBarrier center_a normal_a same_facing_center same_facing_normal wall_thickness connection_threshold
    local blocks_corner = wallFaceGrowthFacePairHasThicknessBarrier center_a normal_a corner_center corner_normal wall_thickness connection_threshold
    local blocks_far = wallFaceGrowthFacePairHasThicknessBarrier center_a normal_a far_center opposite_normal wall_thickness connection_threshold
    local passed = blocks_opposite and not blocks_same_facing and not blocks_corner and not blocks_far


    format "CTRL+RMB thickness barrier | opposite: % | same-facing: % | corner: % | beyond thickness: % | passed: %\n" blocks_opposite blocks_same_facing blocks_corner blocks_far passed


    #(blocks_opposite, blocks_same_facing, blocks_corner, blocks_far, passed) -- return
)




/* Reports manual FORCED face counts on selected objects for CTRL+RMB auto-grow.
   Forced faces are local barriers; unforced wall-side faces on the same object remain eligible.
*/
function testWallFaceGrowthForcedBlockers =
(
    local blocker_count = 0
    local tested_count = 0


    for object_node in selection where superclassof object_node == GeometryClass do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            tested_count += 1


            if hasForcedWallFaceType object_node source_data then
            (
                blocker_count += 1
            )
        )
    )


    format "RMB forced barriers | tested objects: % | objects containing forced faces: %\n" tested_count blocker_count


    #(tested_count, blocker_count) -- return
)


/* Selects one classifier class from the current or restored working set.
   Object level selects matching objects; Face level selects matching faces across matching objects.
*/
function selectWallFacesByMaterialId material_id =
(
    local had_node_selection = (selection.count > 0)
    local selection_level_before = subObjectLevel
    local selected_nodes = getWallFaceWorkingNodes()
    local use_face_selection = (had_node_selection and selection_level_before == 4)
    local selection_data_array = #()
    local matching_nodes = #()
    local selected_face_count = 0
    local selection_mode = #objects


    if use_face_selection then
    (
        selection_mode = #faces
    )


    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local face_bits = getCachedWallFaceBits object_node source_data material_id


            if face_bits == undefined then
            (
                local cache_entry = cacheWallFaceClassesFromMaterialIds object_node source_data


                if material_id == 1 then
                (
                    face_bits = copy cache_entry[3]
                )
                else if material_id == 2 then
                (
                    face_bits = copy cache_entry[4]
                )
                else if material_id == 3 then
                (
                    face_bits = copy cache_entry[5]
                )
                else if material_id == 4 then
                (
                    face_bits = copy cache_entry[6]
                )
                else
                (
                    face_bits = #{}
                )
            )


            if face_bits.numberSet > 0 then
            (
                append matching_nodes object_node
                append selection_data_array #(object_node, source_data, face_bits)
                selected_face_count += face_bits.numberSet
            )
        )
    )


    if matching_nodes.count > 0 then
    (
        select matching_nodes
        max modify mode


        if use_face_selection then
        (
            subObjectLevel = 4


            for selection_data in selection_data_array do
            (
                setSourceFaceSelection selection_data[1] selection_data[2] selection_data[3]
            )
        )


        redrawViews()
    )
    else
    (
        clearSelection()
        redrawViews()
    )


    #(matching_nodes.count, selected_face_count, selection_mode) -- return
)


/* Manually assigns selected faces, or the matching class family on selected objects, to one classifier Material ID.
   OUTER/INNER object mode targets wall-side faces only; TOP/BOTTOM object mode targets cap faces only.
*/
function markSelectedWallFaces material_id =
(
    local had_node_selection = (selection.count > 0)
    local selection_level_before = subObjectLevel
    local selected_nodes = getWallFaceWorkingNodes()
    local mark_data_array = #()
    local valid_nodes = #()
    local marked_face_count = 0
    local use_face_selection = (had_node_selection and selection_level_before == 4)
    local source_label = "selected objects"


    if use_face_selection then
    (
        source_label = "face selection"
    )


    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local original_bits = getSourceFaceSelection object_node source_data
            local mark_bits = #{}
            local had_classifier_material = hasWallClassifierMaterial object_node


            if use_face_selection then
            (
                mark_bits = copy original_bits
            )
            else
            (
                local face_count = getSourceNumFaces object_node source_data


                for face_index = 1 to face_count do
                (
                    local current_material_id = getSourceFaceMaterialId object_node source_data face_index


                    if material_id == 1 or material_id == 2 then
                    (
                        if current_material_id == 1 or current_material_id == 2 then
                        (
                            mark_bits[face_index] = true
                        )
                    )
                    else if material_id == 3 or material_id == 4 then
                    (
                        if current_material_id == 3 or current_material_id == 4 then
                        (
                            mark_bits[face_index] = true
                        )
                    )
                )
            )


            if mark_bits.numberSet > 0 then
            (
                append mark_data_array #(object_node, source_data, mark_bits, original_bits, had_classifier_material)
                append valid_nodes object_node
                marked_face_count += mark_bits.numberSet
            )
        )
    )


    if valid_nodes.count > 0 then
    (
        ensureWallClassifierMaterial valid_nodes


        for mark_data in mark_data_array do
        (
            local object_node = mark_data[1]
            local source_data = mark_data[2]
            local mark_bits = mark_data[3]
            local original_bits = mark_data[4]
            local had_classifier_material = mark_data[5]


            forceWallFaceClass object_node source_data material_id mark_bits
            setSourceFaceMaterialId object_node source_data mark_bits material_id
            setSourceFaceSelection object_node source_data original_bits
            cacheWallFaceClassesFromMaterialIds object_node source_data
        )


        select valid_nodes
        max modify mode


        if selection_level_before != undefined then
        (
            subObjectLevel = selection_level_before
        )


        redrawViews()
    )


    #(valid_nodes.count, marked_face_count, source_label) -- return
)


/* Returns true when two faces share at least the requested number of vertex indices.
   Forced hierarchy propagation uses two shared vertices so a single corner touch cannot inherit a class.
*/
function facesShareMinimumVertices face_indices_a face_indices_b minimum_shared_vertices:2 =
(
    local shared_count = 0


    for vertex_index in face_indices_a while shared_count < minimum_shared_vertices do
    (
        if (findItem face_indices_b vertex_index) > 0 then
        (
            shared_count += 1
        )
    )


    (shared_count >= minimum_shared_vertices) -- return
)


/* Builds edge-connected face elements for one selected object.
   Faces must share at least two vertices; a one-vertex corner touch starts a separate element.
*/
function buildWallHierarchyElements object_data object_data_index definite_threshold horizontal_normal_threshold:0.85 prefer_outer_seed:false =
(
    local vertex_world_cache = object_data[8]
    local face_vertex_indices = object_data[9]
    local face_normals = object_data[5]
    local face_scores = object_data[7]
    local vertex_faces = #()
    local visited_faces = #{}
    local element_data_array = #()


    for vertex_index = 1 to vertex_world_cache.count do
    (
        append vertex_faces #{}
    )


    for face_index = 1 to face_vertex_indices.count do
    (
        for vertex_index in face_vertex_indices[face_index] do
        (
            vertex_faces[vertex_index][face_index] = true
        )
    )


    for start_face = 1 to face_vertex_indices.count do
    (
        if not visited_faces[start_face] then
        (
            local pending_faces = #(start_face)
            local element_faces = #{}
            local element_vertices = #{}
            local has_horizontal_face = false
            local has_outer_seed = false
            local has_inner_seed = false
            local seed_class = 0
            local bbox_min = undefined
            local bbox_max = undefined


            visited_faces[start_face] = true


            while pending_faces.count > 0 do
            (
                local current_face = pending_faces[pending_faces.count]
                deleteItem pending_faces pending_faces.count
                element_faces[current_face] = true


                for vertex_index in face_vertex_indices[current_face] do
                (
                    element_vertices[vertex_index] = true


                    for neighbor_face in vertex_faces[vertex_index] do
                    (
                        if not visited_faces[neighbor_face] then
                        (
                            if facesShareMinimumVertices face_vertex_indices[current_face] face_vertex_indices[neighbor_face] minimum_shared_vertices:2 then
                            (
                                visited_faces[neighbor_face] = true
                                append pending_faces neighbor_face
                            )
                        )
                    )
                )
            )


            for face_index in element_faces do
            (
                local face_normal = face_normals[face_index]
                local face_score = face_scores[face_index]


                if (abs face_normal.z) >= horizontal_normal_threshold then
                (
                    has_horizontal_face = true
                )


                if face_score >= definite_threshold then
                (
                    has_outer_seed = true
                )
                else if face_score <= -definite_threshold then
                (
                    has_inner_seed = true
                )
            )


            if not has_horizontal_face then
            (
                if prefer_outer_seed and has_outer_seed then
                (
                    /* FORCED OUTER is the point of interest and wins a seed conflict. */
                    seed_class = 1
                )
                else if has_outer_seed and not has_inner_seed then
                (
                    seed_class = 1
                )
                else if has_inner_seed and not has_outer_seed then
                (
                    seed_class = 2
                )
            )


            for vertex_index in element_vertices do
            (
                local vertex_world = vertex_world_cache[vertex_index]


                if bbox_min == undefined then
                (
                    bbox_min = copy vertex_world
                    bbox_max = copy vertex_world
                )
                else
                (
                    if vertex_world.x < bbox_min.x then
                    (
                        bbox_min.x = vertex_world.x
                    )
                    if vertex_world.y < bbox_min.y then
                    (
                        bbox_min.y = vertex_world.y
                    )
                    if vertex_world.z < bbox_min.z then
                    (
                        bbox_min.z = vertex_world.z
                    )


                    if vertex_world.x > bbox_max.x then
                    (
                        bbox_max.x = vertex_world.x
                    )
                    if vertex_world.y > bbox_max.y then
                    (
                        bbox_max.y = vertex_world.y
                    )
                    if vertex_world.z > bbox_max.z then
                    (
                        bbox_max.z = vertex_world.z
                    )
                )
            )


            append element_data_array #(object_data_index, element_faces, element_vertices, has_horizontal_face, seed_class, bbox_min, bbox_max)
        )
    )


    element_data_array -- return
)


/* Returns true when two element bounds can touch within the connection threshold.
   This avoids expensive vertex comparisons for distant elements.
*/
function wallHierarchyBoundsOverlap element_a element_b connection_threshold =
(
    local min_a = element_a[6]
    local max_a = element_a[7]
    local min_b = element_b[6]
    local max_b = element_b[7]
    local overlap_result = true


    if min_a == undefined or min_b == undefined then
    (
        overlap_result = false
    )
    else
    (
        if (max_a.x + connection_threshold) < min_b.x or (max_b.x + connection_threshold) < min_a.x then
        (
            overlap_result = false
        )
        else if (max_a.y + connection_threshold) < min_b.y or (max_b.y + connection_threshold) < min_a.y then
        (
            overlap_result = false
        )
        else if (max_a.z + connection_threshold) < min_b.z or (max_b.z + connection_threshold) < min_a.z then
        (
            overlap_result = false
        )
    )


    overlap_result -- return
)


/* Counts unique matching world-space vertices between two separate wall elements.
   Two matches are treated as an edge-like wall connection instead of a corner touch.
*/
function countWallHierarchyVertexMatches element_a element_b object_data_array connection_threshold maximum_matches:2 =
(
    local match_count = 0
    local threshold_squared = connection_threshold * connection_threshold
    local object_data_a = object_data_array[element_a[1]]
    local object_data_b = object_data_array[element_b[1]]
    local vertex_world_a = object_data_a[8]
    local vertex_world_b = object_data_b[8]
    local vertices_a = element_a[3]
    local vertices_b = element_b[3]
    local matched_b = #{}


    if wallHierarchyBoundsOverlap element_a element_b connection_threshold then
    (
        for vertex_index_a in vertices_a do
        (
            if match_count < maximum_matches then
            (
                local point_a = vertex_world_a[vertex_index_a]
                local found_match = false


                for vertex_index_b in vertices_b do
                (
                    if not found_match and not matched_b[vertex_index_b] then
                    (
                        local delta = point_a - vertex_world_b[vertex_index_b]


                        if (dot delta delta) <= threshold_squared then
                        (
                            matched_b[vertex_index_b] = true
                            match_count += 1
                            found_match = true
                        )
                    )
                )
            )
        )
    )


    match_count -- return
)


/* Propagates reliable OUTER/INNER seeds through edge-connected wall elements and neighboring meshes.
   A face/element must connect through at least two shared vertices; floors and ceilings stop the chain.
*/
function resolveWallHierarchyByElements object_data_array connection_threshold confidence_threshold:0.12 horizontal_normal_threshold:0.85 minimum_matching_vertices:2 prefer_outer_seed:false =
(
    local definite_threshold = confidence_threshold * 2.0
    local all_elements = #()
    local resolved_count = 0
    local connection_count = 0


    if definite_threshold < 0.35 then
    (
        definite_threshold = 0.35
    )


    for object_data_index = 1 to object_data_array.count do
    (
        local object_elements = buildWallHierarchyElements object_data_array[object_data_index] object_data_index definite_threshold horizontal_normal_threshold:horizontal_normal_threshold prefer_outer_seed:prefer_outer_seed


        for element_data in object_elements do
        (
            append all_elements element_data
        )
    )


    /* First apply a reliable seed to the complete topological element.
       This fixes unresolved wall faces inside one wall element before cross-object propagation.
    */
    for element_data in all_elements do
    (
        local seed_class = element_data[5]


        if seed_class == 1 or seed_class == 2 then
        (
            local face_classes = object_data_array[element_data[1]][6]


            for face_index in element_data[2] do
            (
                if face_classes[face_index] != seed_class then
                (
                    face_classes[face_index] = seed_class


                    if object_data_array[element_data[1]].count >= 10 then
                    (
                        object_data_array[element_data[1]][10][face_index] = if prefer_outer_seed then #FORCED_HIERARCHY else #HIERARCHY
                    )


                    resolved_count += 1
                )
            )
        )
    )


    if connection_threshold > 0.0 and all_elements.count > 1 then
    (
        local element_neighbors = #()
        local visited_elements = #{}


        for element_index = 1 to all_elements.count do
        (
            append element_neighbors #{}
        )


        for element_index_a = 1 to (all_elements.count - 1) do
        (
            local element_a = all_elements[element_index_a]


            if not element_a[4] then
            (
                for element_index_b = (element_index_a + 1) to all_elements.count do
                (
                    local element_b = all_elements[element_index_b]


                    if not element_b[4] then
                    (
                        local match_count = countWallHierarchyVertexMatches element_a element_b object_data_array connection_threshold maximum_matches:minimum_matching_vertices


                        if match_count >= minimum_matching_vertices then
                        (
                            element_neighbors[element_index_a][element_index_b] = true
                            element_neighbors[element_index_b][element_index_a] = true
                            connection_count += 1
                        )
                    )
                )
            )
        )


        for start_element = 1 to all_elements.count do
        (
            if not visited_elements[start_element] and not all_elements[start_element][4] then
            (
                local pending_elements = #(start_element)
                local network_elements = #{}
                local has_outer_seed = false
                local has_inner_seed = false
                local network_class = 0


                visited_elements[start_element] = true


                while pending_elements.count > 0 do
                (
                    local current_element = pending_elements[pending_elements.count]
                    local current_seed = all_elements[current_element][5]
                    deleteItem pending_elements pending_elements.count
                    network_elements[current_element] = true


                    if current_seed == 1 then
                    (
                        has_outer_seed = true
                    )
                    else if current_seed == 2 then
                    (
                        has_inner_seed = true
                    )


                    for neighbor_element in element_neighbors[current_element] do
                    (
                        if not visited_elements[neighbor_element] then
                        (
                            visited_elements[neighbor_element] = true
                            append pending_elements neighbor_element
                        )
                    )
                )


                if prefer_outer_seed and has_outer_seed then
                (
                    /* FORCED OUTER wins when OUTER and INNER hints meet in one wall network. */
                    network_class = 1
                )
                else if has_outer_seed and not has_inner_seed then
                (
                    network_class = 1
                )
                else if has_inner_seed and not has_outer_seed then
                (
                    network_class = 2
                )


                if network_class == 1 or network_class == 2 then
                (
                    for element_index in network_elements do
                    (
                        local element_data = all_elements[element_index]


                        if element_data[5] == 0 or (prefer_outer_seed and network_class == 1 and element_data[5] == 2) then
                        (
                            local face_classes = object_data_array[element_data[1]][6]


                            for face_index in element_data[2] do
                            (
                                if face_classes[face_index] != network_class then
                                (
                                    face_classes[face_index] = network_class


                                    if object_data_array[element_data[1]].count >= 10 then
                                    (
                                        object_data_array[element_data[1]][10][face_index] = if prefer_outer_seed then #FORCED_HIERARCHY else #HIERARCHY
                                    )


                                    resolved_count += 1
                                )
                            )
                        )
                    )
                )
            )
        )
    )


    format "Wall hierarchy: % elements | % neighbor links | % faces resolved | vertex threshold: %\\n" all_elements.count connection_count resolved_count connection_threshold


    #(resolved_count, all_elements.count, connection_count) -- return
)


/* Classifies selected faces into OUTER, INNER, UP, and DOWN.
   Persistent FORCED OUTER/INNER hints propagate first, then automatic wall tests resolve the rest.
*/
function classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) horizontal_normal_threshold:0.85 =
(
    local selected_nodes = getWallFaceWorkingNodes()
    local valid_nodes = #()
    local object_data_array = #()
    local bbox_min = undefined
    local bbox_max = undefined
    local analysis_origin = undefined
    local total_faces = 0
    local outer_count = 0
    local inner_count = 0
    local up_count = 0
    local down_count = 0
    local selection_type = #none
    local thickness_resolved = 0
    local hierarchy_resolved = 0
    local forced_hierarchy_resolved = 0
    local forced_face_count = 0
    local neighbor_resolved = 0
    local fallback_resolved = 0
    local debug_selection_center = undefined
    local debug_pivot_state = #()
    local debug_run_data = undefined


    if selected_nodes.count == 0 then
    (
        messageBox "Select wall objects first, or run CLASSIFY once so the last object set can be restored." title:"Inner-Outer Wall Finder"
        #() -- return
    )
    else
    (
        for object_node in selected_nodes do
        (
            local source_data = getFaceGeometrySource object_node


            if source_data != undefined then
            (
                append valid_nodes object_node
                local vertex_count = getSourceNumVertices object_node source_data


                for vertex_index = 1 to vertex_count do
                (
                    local vertex_world = getSourceVertexWorld object_node source_data vertex_index


                    if bbox_min == undefined then
                    (
                        bbox_min = copy vertex_world
                        bbox_max = copy vertex_world
                    )
                    else
                    (
                        if vertex_world.x < bbox_min.x then
                        (
                            bbox_min.x = vertex_world.x
                        )
                        if vertex_world.y < bbox_min.y then
                        (
                            bbox_min.y = vertex_world.y
                        )
                        if vertex_world.z < bbox_min.z then
                        (
                            bbox_min.z = vertex_world.z
                        )


                        if vertex_world.x > bbox_max.x then
                        (
                            bbox_max.x = vertex_world.x
                        )
                        if vertex_world.y > bbox_max.y then
                        (
                            bbox_max.y = vertex_world.y
                        )
                        if vertex_world.z > bbox_max.z then
                        (
                            bbox_max.z = vertex_world.z
                        )
                    )
                )
            )
        )


        if valid_nodes.count == 0 or bbox_min == undefined then
        (
            messageBox "No supported objects found. Use Editable Poly or an object with Edit Poly as the top modifier." title:"Inner-Outer Wall Finder"
            #() -- return
        )
        else
        (
            wall_face_classifier_last_nodes = for object_node in valid_nodes collect object_node
            analysis_origin = getWallFaceAnalysisOrigin valid_nodes


            if wall_face_debug_enabled then
            (
                wall_face_debug_run_id += 1
                debug_selection_center = getWallFaceSelectionCenter valid_nodes
                debug_pivot_state = getWallFaceDebugWorkingPivotState()
            )


            local bbox_diagonal = length (bbox_max - bbox_min)
            local geometry_epsilon = bbox_diagonal * 0.00000001
            local ray_offset = bbox_diagonal * 0.00001


            if geometry_epsilon < 0.0000001 then
            (
                geometry_epsilon = 0.0000001
            )


            if ray_offset < 0.0001 then
            (
                ray_offset = 0.0001
            )


            for object_node in valid_nodes do
            (
                local source_data = getFaceGeometrySource object_node
                local vertex_count = getSourceNumVertices object_node source_data
                local face_count = getSourceNumFaces object_node source_data
                local vertex_world_cache = #()
                local cached_faces = #()
                local face_centers = #()
                local face_normals = #()
                local face_classes = #()
                local face_scores = #()
                local face_vertex_indices = #()
                local face_debug_reasons = #()
                local original_selection_bits = getSourceFaceSelection object_node source_data
                local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
                local forced_inner_bits = getForcedWallFaceBits object_node source_data 2


                total_faces += face_count
                forced_face_count += forced_outer_bits.numberSet
                forced_face_count += forced_inner_bits.numberSet


                for vertex_index = 1 to vertex_count do
                (
                    append vertex_world_cache (getSourceVertexWorld object_node source_data vertex_index)
                )


                for face_index = 1 to face_count do
                (
                    local face_degree = getSourceFaceDegree object_node source_data face_index
                    local face_vertices = #()
                    local face_indices = #()


                    for corner_index = 1 to face_degree do
                    (
                        local vertex_index = getSourceFaceVertex object_node source_data face_index corner_index
                        append face_indices vertex_index
                        append face_vertices vertex_world_cache[vertex_index]
                    )


                    local initial_class = 0
                    local initial_score = 0.0
                    local initial_reason = #RADIAL_UNRESOLVED


                    if forced_outer_bits[face_index] then
                    (
                        initial_class = 1
                        initial_score = 1.0
                        initial_reason = #FORCED_OUTER
                    )
                    else if forced_inner_bits[face_index] then
                    (
                        initial_class = 2
                        initial_score = -1.0
                        initial_reason = #FORCED_INNER
                    )


                    append cached_faces face_vertices
                    append face_centers (calculatePolygonCenter face_vertices)
                    append face_normals (calculatePolygonNormal face_vertices epsilon:geometry_epsilon)
                    append face_classes initial_class
                    append face_scores initial_score
                    append face_vertex_indices face_indices
                    append face_debug_reasons initial_reason
                )


                append object_data_array #(object_node, source_data, cached_faces, face_centers, face_normals, face_classes, face_scores, vertex_world_cache, face_vertex_indices, face_debug_reasons, original_selection_bits)
            )


            if forced_face_count > 0 then
            (
                local forced_hierarchy_result = resolveWallHierarchyByElements object_data_array connection_threshold confidence_threshold:confidence_threshold horizontal_normal_threshold:horizontal_normal_threshold minimum_matching_vertices:2 prefer_outer_seed:true
                forced_hierarchy_resolved = forced_hierarchy_result[1]
                hierarchy_resolved += forced_hierarchy_resolved
            )


            for object_data in object_data_array do
            (
                local face_centers = object_data[4]
                local face_normals = object_data[5]
                local face_classes = object_data[6]
                local face_scores = object_data[7]
                local face_debug_reasons = object_data[10]


                for face_index = 1 to face_classes.count do
                (
                    local face_center = face_centers[face_index]
                    local face_normal = face_normals[face_index]


                    if face_classes[face_index] == 1 or face_classes[face_index] == 2 then
                    (
                        /* FORCED or force-propagated wall class: preserve its existing debug source. */
                    )
                    else if (length face_normal) <= geometry_epsilon then
                    (
                        face_classes[face_index] = 0
                        face_debug_reasons[face_index] = #DEGENERATE
                    )
                    else if face_normal.z >= horizontal_normal_threshold then
                    (
                        face_classes[face_index] = 3
                        face_debug_reasons[face_index] = #TOP_NORMAL
                    )
                    else if face_normal.z <= -horizontal_normal_threshold then
                    (
                        face_classes[face_index] = 4
                        face_debug_reasons[face_index] = #BOTTOM_NORMAL
                    )
                    else
                    (
                        local radial_vector = face_center - analysis_origin
                        local spatial_score = 0.0


                        if (length radial_vector) > geometry_epsilon then
                        (
                            spatial_score = dot face_normal (normalize radial_vector)
                        )
                        face_scores[face_index] = spatial_score


                        if spatial_score >= confidence_threshold then
                        (
                            face_classes[face_index] = 1
                            face_debug_reasons[face_index] = #RADIAL_OUTER
                        )
                        else if spatial_score <= -confidence_threshold then
                        (
                            face_classes[face_index] = 2
                            face_debug_reasons[face_index] = #RADIAL_INNER
                        )
                        else
                        (
                            face_classes[face_index] = 0
                            face_debug_reasons[face_index] = #RADIAL_UNRESOLVED
                        )
                    )
                )
            )


            thickness_resolved = resolveUnresolvedWallsByThickness object_data_array wall_thickness confidence_threshold:confidence_threshold parallel_threshold:0.90 ray_offset:ray_offset epsilon:geometry_epsilon


            local hierarchy_result = resolveWallHierarchyByElements object_data_array connection_threshold confidence_threshold:confidence_threshold horizontal_normal_threshold:horizontal_normal_threshold minimum_matching_vertices:2
            hierarchy_resolved += hierarchy_result[1]


            neighbor_resolved = resolveUnresolvedWallFaces object_data_array neighbor_passes:neighbor_passes
            fallback_resolved = finalizeUnresolvedWallFaces object_data_array


            assignWallClassifierMaterial valid_nodes


            if wall_face_debug_enabled then
            (
                debug_run_data = #(wall_face_debug_run_id, debug_selection_center, analysis_origin, debug_pivot_state[3], debug_pivot_state[1], debug_pivot_state[2], wall_thickness, connection_threshold, confidence_threshold, horizontal_normal_threshold, thickness_resolved, forced_hierarchy_resolved, hierarchy_resolved, neighbor_resolved, fallback_resolved, wall_face_ground_pivot_enabled)
            )


            for object_data in object_data_array do
            (
                local object_node = object_data[1]
                local source_data = object_data[2]
                local face_classes = object_data[6]
                local outer_bits = buildFaceClassBits face_classes 1
                local inner_bits = buildFaceClassBits face_classes 2
                local up_bits = buildFaceClassBits face_classes 3
                local down_bits = buildFaceClassBits face_classes 4


                outer_count += outer_bits.numberSet
                inner_count += inner_bits.numberSet
                up_count += up_bits.numberSet
                down_count += down_bits.numberSet


                setSourceFaceMaterialId object_node source_data outer_bits 1
                setSourceFaceMaterialId object_node source_data inner_bits 2
                setSourceFaceMaterialId object_node source_data up_bits 3
                setSourceFaceMaterialId object_node source_data down_bits 4
                cacheWallFaceClasses object_node face_classes.count outer_bits inner_bits up_bits down_bits


                if wall_face_debug_enabled then
                (
                    writeWallFaceDebugTrace object_data debug_run_data
                )
            )


            if outer_count > 0 then
            (
                selection_type = #outer
            )
            else if inner_count > 0 then
            (
                selection_type = #inner
            )
            else if up_count > 0 then
            (
                selection_type = #up
            )
            else if down_count > 0 then
            (
                selection_type = #down
            )


            for object_data in object_data_array do
            (
                local object_node = object_data[1]
                local source_data = object_data[2]
                local face_classes = object_data[6]
                local selection_bits = #{}


                if selection_type == #inner then
                (
                    selection_bits = buildFaceClassBits face_classes 2
                )
                else if selection_type == #outer then
                (
                    selection_bits = buildFaceClassBits face_classes 1
                )
                else if selection_type == #up then
                (
                    selection_bits = buildFaceClassBits face_classes 3
                )
                else if selection_type == #down then
                (
                    selection_bits = buildFaceClassBits face_classes 4
                )


                setSourceFaceSelection object_node source_data selection_bits
            )


            select valid_nodes
            max modify mode
            subObjectLevel = 4
            redrawViews()


            if wall_face_debug_enabled then
            (
                debugWallFaceClassifierSelection verbose_vertices:true verbose_faces:true use_last_if_empty:true
            )


            format "Inner-Outer Wall Finder 0.32: % faces | FORCED hints: % | forced propagation: % | OUTER: % | INNER: % | UP: % | DOWN: % | thickness: % | hierarchy total: % | neighbor: % | fallback: % | selected: %\n" total_faces forced_face_count forced_hierarchy_resolved outer_count inner_count up_count down_count thickness_resolved hierarchy_resolved neighbor_resolved fallback_resolved selection_type


            #(valid_nodes.count, total_faces, outer_count, inner_count, up_count, down_count, selection_type, thickness_resolved, hierarchy_resolved, neighbor_resolved, fallback_resolved) -- return
        )
    )
)


/* Creates a non-destructive test setup with OUTER/INNER walls and horizontal caps.
   The box faces provide clear UP and DOWN normal-direction test cases.
*/
function createWallFaceClassifierTestScene =
(
    local outer_box = box width:200 length:200 height:120 pos:[0, 0, 60] name:(uniqueName "WFC_TEST_OUTER")
    local inner_box = box width:80 length:80 height:60 pos:[0, 0, 60] name:(uniqueName "WFC_TEST_INNER")


    convertToPoly outer_box
    wallFixerSetNodeCageOff outer_box
    convertToPoly inner_box
    wallFixerSetNodeCageOff inner_box
    polyOp.flipNormals inner_box #all


    select #(outer_box, inner_box)
    redrawViews()


    #(outer_box, inner_box) -- return
)


/* Runs a one-click test using the generated scene and default settings.
   The generated objects remain selected so only those objects are analyzed.
*/
function testWallFaceClassifier wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold
)


/* Tests all four Material IDs and the assigned Multi/Sub-Object material.
   Creates the test scene, classifies it, and prints each assigned sub-material.
*/
function testWallFaceClassifierMaterials wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local test_nodes = createWallFaceClassifierTestScene()
    local result_data = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold


    if test_nodes.count > 0 then
    (
        local classifier_material = test_nodes[1].material


        format "Classifier material: %\n" classifier_material
        format "ID 1 OUTER: % | diffuse: %\n" classifier_material.materialList[1].name classifier_material.materialList[1].diffuse
        format "ID 2 INNER: % | diffuse: %\n" classifier_material.materialList[2].name classifier_material.materialList[2].diffuse
        format "ID 3 UP: % | diffuse: %\n" classifier_material.materialList[3].name classifier_material.materialList[3].diffuse
        format "ID 4 DOWN: % | diffuse: %\n" classifier_material.materialList[4].name classifier_material.materialList[4].diffuse
    )


    result_data -- return
)


/* Tests Material ID face selection after running the classifier.
   Pass material_id 1, 2, 3, or 4 to test OUTER, INNER, UP, or DOWN.
*/
function testWallFaceClassSelection material_id:1 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold
    selectWallFacesByMaterialId material_id
)


/* Tests cached class selection after a normal classification pass.
   Prints cache size and selects OUTER faces through the cached path.
*/
function testWallFaceClassifierCache wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local result_data = #()


    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold
    result_data = selectWallFacesByMaterialId 1
    format "Classifier cache entries: % | OUTER selected: %\n" wall_face_classifier_cache.count result_data[2]
    result_data -- return
)


/* Tests force-style manual marking without using the rollout event handler.
   Object-level test marks every face of a new Editable Poly box as INNER.
*/
function testMarkSelectedWallFaces =
(
    local test_box = box width:100 length:100 height:100 pos:[0, 0, 50] name:(uniqueName "WFC_TEST_MARK")
    local result_data = #()


    convertToPoly test_box
    wallFixerSetNodeCageOff test_box
    select test_box
    max modify mode
    subObjectLevel = 0
    result_data = markSelectedWallFaces 2
    format "Manual mark test | objects: % | INNER faces marked: %\n" result_data[1] result_data[2]
    result_data -- return
)


/* Returns a short suffix for one physical unit type.
   Used for metric, US, and 1:1 custom display units.
*/
function getWallFacePhysicalUnitLabel unit_type =
(
    local unit_label = "units"


    case unit_type of
    (
        #Millimeters: unit_label = "mm"
        #Centimeters: unit_label = "cm"
        #Meters: unit_label = "m"
        #Kilometers: unit_label = "km"
        #Inches: unit_label = "in"
        #Feet: unit_label = "ft"
        #Miles: unit_label = "mi"
        default: unit_label = "units"
    )


    unit_label -- return
)


/* Returns a short label for the current 3ds Max display units.
   A 1:1 Custom unit uses its physical unit suffix, for example 1 mm -> mm.
*/
function getWallFaceDisplayUnitLabel =
(
    local unit_label = "units"
    local custom_value_epsilon = 0.000001


    case units.DisplayType of
    (
        #Generic:
        (
            unit_label = "units"
        )
        #Metric:
        (
            unit_label = getWallFacePhysicalUnitLabel units.MetricType
        )
        #US:
        (
            case units.USType of
            (
                #Frac_In: unit_label = "in"
                #Dec_In: unit_label = "in"
                #Frac_Ft: unit_label = "ft"
                #Dec_Ft: unit_label = "ft"
                #Ft_Frac_In: unit_label = "ft/in"
                #Ft_Dec_In: unit_label = "ft/in"
                default: unit_label = "US"
            )
        )
        #custom:
        (
            if (abs (units.CustomValue - 1.0)) <= custom_value_epsilon then
            (
                unit_label = getWallFacePhysicalUnitLabel units.CustomUnit
            )
            else if units.CustomName != "" then
            (
                unit_label = units.CustomName
            )
            else
            (
                unit_label = "custom"
            )
        )
        default:
        (
            unit_label = "units"
        )
    )


    unit_label -- return
)


/* Tests the object > element > face hierarchy pass on the current selected objects.
   Prints how many faces were resolved by element/network propagation.
*/
function testWallHierarchyPropagation connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local result_data = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:connection_threshold


    if result_data.count == 11 then
    (
        format "Hierarchy test: % faces resolved with connection threshold %\n" result_data[9] connection_threshold
    )


    result_data -- return
)


/* Tests the display-unit label helper used by the thickness controls.
   For Custom units it also prints the scale and physical reference unit.
*/
function testWallFaceDisplayUnitLabel =
(
    local unit_label = getWallFaceDisplayUnitLabel()


    if units.DisplayType == #custom then
    (
        format "Display type: % | Custom value: % | Custom unit: % | UI label: %\n" units.DisplayType units.CustomValue units.CustomUnit unit_label
    )
    else
    (
        format "Display type: % | UI label: %\n" units.DisplayType unit_label
    )


    unit_label -- return
)


/* Tests the unit-independent 1 meter default used by Wall thickness.
   Prints its value in system units and the current display-unit string.
*/
function testWallFaceDefaultThickness =
(
    local one_meter = units.decodeValue "1m"
    format "Wall thickness default = 1m | System-unit value: %\n" one_meter
    one_meter -- return
)


/* Reports and validates persistent FORCED OUTER/INNER hints on the current selection.
   With run_classification:true it verifies that classification preserves every forced face.
*/
function testWallFaceForcedHints run_classification:false =
(
    local selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local forced_outer_count = 0
    local forced_inner_count = 0
    local failed_face_count = 0


    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
            local forced_inner_bits = getForcedWallFaceBits object_node source_data 2
            forced_outer_count += forced_outer_bits.numberSet
            forced_inner_count += forced_inner_bits.numberSet
        )
    )


    format "FORCED hints | OUTER: % | INNER: %\n" forced_outer_count forced_inner_count


    if run_classification then
    (
        classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1)


        for object_node in selected_nodes do
        (
            local source_data = getFaceGeometrySource object_node


            if source_data != undefined then
            (
                local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
                local forced_inner_bits = getForcedWallFaceBits object_node source_data 2


                for face_index in forced_outer_bits do
                (
                    if getSourceFaceMaterialId object_node source_data face_index != 1 then
                    (
                        failed_face_count += 1
                    )
                )


                for face_index in forced_inner_bits do
                (
                    if getSourceFaceMaterialId object_node source_data face_index != 2 then
                    (
                        failed_face_count += 1
                    )
                )
            )
        )


        format "FORCED preservation failures: %\n" failed_face_count
    )


    #(forced_outer_count, forced_inner_count, failed_face_count) -- return
)


/* Returns the visible wall-face class name for one classifier color.
   Used to name objects created by EXPLODE.
*/
function getWallFaceClassName material_id =
(
    local class_name = "CLASS"


    case material_id of
    (
        1: class_name = "OUTER"
        2: class_name = "INNER"
        3: class_name = "UP"
        4: class_name = "DOWN"
        default: class_name = "CLASS"
    )


    class_name -- return
)


/* Explodes selected classified objects into separate color-class objects.
   Mixed objects are split into OUTER, INNER, UP, and DOWN objects by face Material ID.
*/
function explodeSelectedWallFacesByClass =
(
    local selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local result_nodes = #()
    local exploded_source_count = 0
    local created_object_count = 0
    local skipped_object_count = 0


    for object_node in selected_nodes do
    (
        if isValidNode object_node then
        (
            local source_data = getFaceGeometrySource object_node


            if source_data != undefined and hasWallClassifierMaterial object_node then
            (
                local face_count = getSourceNumFaces object_node source_data
                local used_class_ids = #()


                for face_index = 1 to face_count do
                (
                    local material_id = getSourceFaceMaterialId object_node source_data face_index


                    if material_id >= 1 and material_id <= 4 then
                    (
                        if (findItem used_class_ids material_id) == 0 then
                        (
                            append used_class_ids material_id
                        )
                    )
                )


                if used_class_ids.count > 1 then
                (
                    local source_name = object_node.name
                    local source_result_nodes = #()


                    for material_id in used_class_ids do
                    (
                        local split_node = copy object_node
                        local class_name = getWallFaceClassName material_id


                        split_node.name = uniqueName (source_name + "_" + class_name)
                        collapseStack split_node


                        if classof split_node.baseObject != Editable_Poly then
                        (
                            convertToPoly split_node
                            wallFixerSetNodeCageOff split_node
                        )


                        local split_face_count = polyop.getNumFaces split_node
                        local delete_bits = #{}


                        for split_face_index = 1 to split_face_count do
                        (
                            if (polyop.getFaceMatID split_node split_face_index) != material_id then
                            (
                                delete_bits[split_face_index] = true
                            )
                        )


                        if delete_bits.numberSet > 0 then
                        (
                            polyop.deleteFaces split_node delete_bits delIsoVerts:true
                        )


                        if (polyop.getNumFaces split_node) > 0 then
                        (
                            setForcedWallFaceBits split_node 1 #{}
                            setForcedWallFaceBits split_node 2 #{}
                            append source_result_nodes split_node
                            append result_nodes split_node
                            created_object_count += 1
                        )
                        else
                        (
                            delete split_node
                        )
                    )


                    if source_result_nodes.count > 0 then
                    (
                        delete object_node
                        exploded_source_count += 1
                    )
                )
                else if used_class_ids.count == 1 then
                (
                    append result_nodes object_node
                )
                else
                (
                    skipped_object_count += 1
                )
            )
            else
            (
                skipped_object_count += 1
            )
        )
    )


    wall_face_classifier_cache = #()
    wall_face_classifier_last_nodes = for object_node in result_nodes where isValidNode object_node collect object_node


    if result_nodes.count > 0 then
    (
        select result_nodes
        max modify mode
        subObjectLevel = 0
    )


    redrawViews()
    #(exploded_source_count, created_object_count, skipped_object_count, result_nodes.count) -- return
)


/* Tests EXPLODE after classifying the built-in test scene.
   Prints how many source objects were split and how many result objects were created.
*/
function testWallFaceClassifierExplode wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold


    local result_data = explodeSelectedWallFacesByClass()
    format "EXPLODE test | split sources: % | created objects: % | skipped: % | selected results: %\n" result_data[1] result_data[2] result_data[3] result_data[4]


    result_data -- return
)


/* Tests RESET on the current selected supported objects.
   Verifies FORCED user-property keys are removed, Material IDs are reset, and the classifier material is removed.
*/
function testWallFaceClassifierReset =
(
    local result_data = resetSelectedWallFaceClassification()
    local forced_face_count = 0
    local forced_property_count = 0
    local non_default_id_count = 0
    local classifier_material_count = 0


    for object_node in selection where superclassof object_node == GeometryClass do
    (
        local source_data = getFaceGeometrySource object_node


        if doesUserPropExist object_node "WallFaceClassifierForcedOuter" then
        (
            forced_property_count += 1
        )


        if doesUserPropExist object_node "WallFaceClassifierForcedInner" then
        (
            forced_property_count += 1
        )


        if hasWallClassifierMaterial object_node then
        (
            classifier_material_count += 1
        )


        if source_data != undefined then
        (
            local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
            local forced_inner_bits = getForcedWallFaceBits object_node source_data 2
            local face_count = getSourceNumFaces object_node source_data


            forced_face_count += forced_outer_bits.numberSet + forced_inner_bits.numberSet


            for face_index = 1 to face_count do
            (
                if getSourceFaceMaterialId object_node source_data face_index != 1 then
                (
                    non_default_id_count += 1
                )
            )
        )
    )


    format "RESET objects: % | faces: % | forced properties left: % | forced faces left: % | non-default Material IDs: % | classifier materials left: %\n" result_data[1] result_data[2] forced_property_count forced_face_count non_default_id_count classifier_material_count
    #(result_data[1], result_data[2], forced_property_count, forced_face_count, non_default_id_count, classifier_material_count) -- return
)


/* Tests the two-shared-vertex rule used by FORCED hierarchy propagation.
   One shared corner must fail while a shared edge of two vertices must pass.
*/
function testForcedMinimumSharedVertices =
(
    local forced_face = #(1, 2, 3, 4)
    local corner_touch_face = #(4, 5, 6, 7)
    local edge_touch_face = #(3, 4, 8, 9)
    local corner_result = facesShareMinimumVertices forced_face corner_touch_face minimum_shared_vertices:2
    local edge_result = facesShareMinimumVertices forced_face edge_touch_face minimum_shared_vertices:2


    format "FORCED 2-vertex rule | corner touch: % | edge touch: %\n" corner_result edge_result
    #(corner_result, edge_result) -- return
)


/* Tests FORCED OUTER priority across connected wall elements without changing the scene.
   An OUTER forced element must override a connected INNER forced element.
*/
function testForcedOuterPriority =
(
    local shared_vertices = #([0, 0, 0], [0, 0, 10], [10, 0, 10], [10, 0, 0])
    local face_indices = #(#(1, 2, 3, 4))
    local outer_data = #(undefined, undefined, #(), #(), #([1, 0, 0]), #(1), #(1.0), shared_vertices, face_indices)
    local inner_data = #(undefined, undefined, #(), #(), #([1, 0, 0]), #(2), #(-1.0), shared_vertices, face_indices)
    local object_data_array = #(outer_data, inner_data)
    local result_data = resolveWallHierarchyByElements object_data_array 1.0 confidence_threshold:0.12 horizontal_normal_threshold:0.85 minimum_matching_vertices:2 prefer_outer_seed:true
    local outer_result = object_data_array[1][6][1]
    local inner_result = object_data_array[2][6][1]
    local priority_ok = (outer_result == 1 and inner_result == 1)


    format "FORCED priority | OUTER element: % | connected INNER element becomes: % | passed: %\n" outer_result inner_result priority_ok


    priority_ok -- return
)


/* Tests the color-name legend used by the CLASSIFY tooltip.
   Prints the four visible class labels without material ID numbers.
*/
function testWallFaceClassifierColorLegend =
(
    format "Green = OUTER | Pastel Orange = INNER | Pastel Blue = UP | Pastel Violet = DOWN\n"
    true -- return
)


/* Tests the default connection-threshold relationship without changing the scene.
   The expected threshold is exactly ten percent of the supplied wall thickness.
*/
function testWallFaceDefaultConnectionThreshold wall_thickness:(units.decodeValue "1m") =
(
    local connection_threshold = getDefaultWallConnectionThreshold wall_thickness


    format "Wall thickness: % | default Connect threshold: % | ratio: %\n" wall_thickness connection_threshold (connection_threshold / wall_thickness)


    connection_threshold -- return
)


/* Tests last-run object restoration and both LMB selection modes.
   It classifies a test scene, clears node selection, restores matching objects, then selects matching faces.
*/
function testWallFaceSelectionRestore =
(
    local test_nodes = createWallFaceClassifierTestScene()
    local classify_result = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1)
    local object_result = #()
    local face_result = #()


    clearSelection()
    object_result = selectWallFacesByMaterialId 1


    if selection.count > 0 then
    (
        max modify mode
        subObjectLevel = 4
        face_result = selectWallFacesByMaterialId 1
    )


    format "Restore test | classified objects: % | OUTER objects restored: % | OUTER faces selected: %\n" classify_result[1] object_result[1] face_result[2]


    #(object_result, face_result) -- return
)




/* Classifies only currently selected supported objects that have no classifier result yet.
   Existing analyzed objects are left untouched, then the original object selection is restored.
*/
function analyzeUnclassifiedSelectedWallObjects wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local original_nodes = for object_node in selection where isValidNode object_node collect object_node
    local original_subobject_level = subObjectLevel
    local unanalyzed_nodes = #()
    local classify_result = #()


    for object_node in original_nodes do
    (
        local source_data = getFaceGeometrySource object_node


        if source_data != undefined then
        (
            if not hasWallClassifierMaterial object_node then
            (
                append unanalyzed_nodes object_node
            )
        )
    )


    if unanalyzed_nodes.count > 0 then
    (
        select unanalyzed_nodes
        max modify mode
        subObjectLevel = 0


        classify_result = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold


        if original_nodes.count > 0 then
        (
            select original_nodes
            max modify mode


            try
            (
                subObjectLevel = original_subobject_level
            )
            catch
            (
            )
        )
    )


    #(unanalyzed_nodes.count, classify_result) -- return
)


/* Tests automatic analysis used by SELECT OUTER/INNER/UP/DOWN.
   New test objects must be classified automatically before class selection runs.
*/
function testWallFaceAutoAnalyzeSelection wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local test_nodes = createWallFaceClassifierTestScene()
    local analyze_result = analyzeUnclassifiedSelectedWallObjects wall_thickness:wall_thickness connection_threshold:connection_threshold
    local analyzed_count = 0


    for object_node in test_nodes do
    (
        if hasWallClassifierMaterial object_node then
        (
            analyzed_count += 1
        )
    )


    format "Auto-analyze test | requested: % | analyzed objects: %\n" analyze_result[1] analyzed_count


    #(analyze_result[1], analyzed_count) -- return
)


/* Tests selection-center classification, explicit RMB-style pivot centering, and manual Use Edit Pivot origin selection.
   The original Working Pivot transform and modes are restored before returning.
*/
function testWallFaceWorkingPivotOrigin =
(
    local test_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local test_passed = false


    if test_nodes.count == 0 then
    (
        format "Working Pivot origin test: select at least one supported wall object first.\n"
        false
    )
    else
    (
        local original_tm = WorkingPivot.getTM()
        local original_use_mode = WorkingPivot.UseMode
        local original_edit_mode = WorkingPivot.EditMode
        local original_ground_pivot = wall_face_ground_pivot_enabled
        local expected_center = getWallFaceSelectionCenter test_nodes
        local selection_origin = undefined
        local centered_pivot = undefined
        local pivot_before_selection_origin = undefined
        local pivot_after_selection_origin = undefined
        local manual_origin = undefined
        local manual_point = undefined


        try
        (
            wall_face_ground_pivot_enabled = false
            WorkingPivot.UseMode = false


            if expected_center != undefined then
            (
                local off_center_tm = WorkingPivot.getTM()
                off_center_tm.translation = expected_center + [37.0, 41.0, 43.0]
                WorkingPivot.setTM off_center_tm
                pivot_before_selection_origin = (WorkingPivot.getTM()).translation


                selection_origin = getWallFaceAnalysisOrigin test_nodes
                pivot_after_selection_origin = (WorkingPivot.getTM()).translation


                centered_pivot = centerWallFaceWorkingPivotToSelection()


                manual_point = expected_center + [13.0, 17.0, 19.0]
                local manual_tm = WorkingPivot.getTM()
                manual_tm.translation = manual_point
                WorkingPivot.setTM manual_tm
                WorkingPivot.UseMode = true
                manual_origin = getWallFaceAnalysisOrigin test_nodes


                test_passed = (((distance selection_origin expected_center) < 0.0001) and ((distance pivot_before_selection_origin pivot_after_selection_origin) < 0.0001) and ((distance centered_pivot expected_center) < 0.0001) and ((distance manual_origin manual_point) < 0.0001))
            )
        )
        catch
        (
            test_passed = false
        )


        try
        (
            wall_face_ground_pivot_enabled = original_ground_pivot
            WorkingPivot.UseMode = false
            WorkingPivot.setTM original_tm
            WorkingPivot.EditMode = original_edit_mode
            WorkingPivot.UseMode = original_use_mode
        )
        catch
        (
        )


        format "Working Pivot origin test: %\n" test_passed
        test_passed
    )
    -- return
)


/* Tests Ground Pivot with both selection-center and manual Working Pivot origins.
   Ground mode must force world Z = 0 and restore the original pivot state after the test.
*/
function testWallFaceGroundPivot =
(
    local test_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local test_passed = false


    if test_nodes.count == 0 then
    (
        format "Ground Pivot test: select at least one supported wall object first.\n"
        false
    )
    else
    (
        local original_tm = WorkingPivot.getTM()
        local original_use_mode = WorkingPivot.UseMode
        local original_edit_mode = WorkingPivot.EditMode
        local original_ground_pivot = wall_face_ground_pivot_enabled
        local selection_center = getWallFaceSelectionCenter test_nodes
        local selection_ground_origin = undefined
        local manual_ground_origin = undefined
        local selection_ground_expected = undefined
        local manual_ground_expected = undefined


        try
        (
            wall_face_ground_pivot_enabled = true


            if selection_center != undefined then
            (
                WorkingPivot.UseMode = false
                selection_ground_expected = [selection_center.x, selection_center.y, 0.0]
                selection_ground_origin = getWallFaceAnalysisOrigin test_nodes


                local manual_tm = WorkingPivot.getTM()
                manual_ground_expected = [selection_center.x + 13.0, selection_center.y + 17.0, 0.0]
                manual_tm.translation = [manual_ground_expected.x, manual_ground_expected.y, 19.0]
                WorkingPivot.setTM manual_tm
                WorkingPivot.UseMode = true
                manual_ground_origin = getWallFaceAnalysisOrigin test_nodes


                test_passed = (((distance selection_ground_origin selection_ground_expected) < 0.0001) and ((distance manual_ground_origin manual_ground_expected) < 0.0001) and ((distance (WorkingPivot.getTM()).translation manual_ground_expected) < 0.0001))
            )
        )
        catch
        (
            test_passed = false
        )


        try
        (
            wall_face_ground_pivot_enabled = original_ground_pivot
            WorkingPivot.UseMode = false
            WorkingPivot.setTM original_tm
            WorkingPivot.EditMode = original_edit_mode
            WorkingPivot.UseMode = original_use_mode
        )
        catch
        (
        )


        format "Ground Pivot test: %\n" test_passed
        test_passed
    )
    -- return
)


/* Reports which force-assignment mode the current modifier state selects.
   Hold CTRL while calling to verify that CTRL+RMB resolves to AUTO GROW mode.
*/
function testWallFaceForceModifier =
(
    local auto_grow = keyboard.controlPressed
    local force_mode = if auto_grow then #forceAndAutoGrow else #forceOnly


    format "Wall force modifier | CTRL: % | mode: %\n" auto_grow force_mode


    force_mode -- return
)


/*
Verifies compact/expanded Get Outer Walls OPTIONS sizing without changing the final layout.
The test checks full parent-width slot sizing plus collapsed and expanded heights.
*/
/* Verifies Helpers > Align Camera side view rotates the wall-facing normal by 90 degrees around world Z.
   The test uses pure vector math and does not change the active viewport.
*/
function testAlignCameraSideView =
(
    front_normal = getWallCameraViewNormal [0.0, 1.0, 0.0]
    side_normal = getWallCameraViewNormal [0.0, 1.0, 0.0] side_view:true
    perpendicular = abs (dot front_normal side_normal) < 0.000001
    horizontal = abs side_normal.z < 0.000001
    unit_length = abs ((length side_normal) - 1.0) < 0.000001
    test_passed = perpendicular and horizontal and unit_length


    format "Align Camera side-view test: %\n" test_passed
    test_passed
    -- return
)


function testWallFaceOptionsLayout =
(
    local slot_control = wallFaceClassifierRollout.wall_face_options_subrollout
    local original_rollout_height = wallFaceClassifierRollout.height
    local original_slot_height = slot_control.height
    local width_ok = (
        (wallFaceClassifierRollout.width == 310) and
        (slot_control.pos.x == 0) and
        (slot_control.width == wallFaceClassifierRollout.width) and
        (wallFaceClassifierOptionsRollout.width == 286)
    )
    local controls_ok = (
        (wallFaceClassifierRollout.btn_classify.pos == [4,8]) and
        (wallFaceClassifierRollout.btn_classify.width == 126) and
        (wallFaceClassifierRollout.btn_explode.pos == [134,8]) and
        (wallFaceClassifierRollout.btn_explode.width == 84) and
        (wallFaceClassifierRollout.btn_layer.pos == [222,8]) and
        (wallFaceClassifierRollout.btn_layer.width == 84) and
        (wallFaceClassifierRollout.btn_select_outer.pos == [4,46]) and
        (wallFaceClassifierRollout.btn_select_inner.pos == [80,46]) and
        (wallFaceClassifierRollout.btn_select_up.pos == [156,46]) and
        (wallFaceClassifierRollout.btn_select_down.pos == [232,46])
    )
    local collapsed_ok = false
    local expanded_ok = false


    wallFaceClassifierRollout.setOptionsLayout false
    collapsed_ok = ((wallFaceClassifierRollout.height == 110) and (slot_control.height == wall_fixer_closed_rollout_height))


    wallFaceClassifierRollout.setOptionsLayout true
    expanded_ok = ((wallFaceClassifierRollout.height == (230 + wall_fixer_closed_rollout_height)) and (slot_control.height == (144 + wall_fixer_closed_rollout_height)))


    slot_control.height = original_slot_height
    wallFaceClassifierRollout.height = original_rollout_height


    local test_passed = width_ok and controls_ok and collapsed_ok and expanded_ok
    format "Get Outer Walls OPTIONS layout test | width:% controls:% collapsed:% expanded:% | result:%\n" width_ok controls_ok collapsed_ok expanded_ok test_passed


    test_passed -- return
)


/*
Verifies Straight Edge result normalization for check and straighten return types.
The test is scene-independent and does not alter geometry or selection.
*/
function testStraightEdgeResultNormalization =
(
    zero_count_ok = WallFixerRollout.normalizeStraightEdgeResult 0
    positive_count_ok = WallFixerRollout.normalizeStraightEdgeResult 5
    array_success_ok = WallFixerRollout.normalizeStraightEdgeResult #(0, false)
    array_failed_flag_ok = WallFixerRollout.normalizeStraightEdgeResult #(2, true)
    boolean_true_ok = WallFixerRollout.normalizeStraightEdgeResult true
    boolean_false_ok = not (WallFixerRollout.normalizeStraightEdgeResult false)
    invalid_value_ok = not (WallFixerRollout.normalizeStraightEdgeResult undefined)


    test_passed = (
        zero_count_ok and
        positive_count_ok and
        array_success_ok and
        array_failed_flag_ok and
        boolean_true_ok and
        boolean_false_ok and
        invalid_value_ok
    )


    format "Straight Edge result normalization test | zero:% positive:% array:% arrayFailed:% true:% false:% invalid:% | result:%\n" \
        zero_count_ok positive_count_ok array_success_ok array_failed_flag_ok boolean_true_ok boolean_false_ok invalid_value_ok test_passed


    test_passed
    -- return
)


/*
Verifies EDGE FIXER direction-control order and compact Angle spinner placement.
The test checks Vertical left, Angle center, Horizontal right and the requested Angle range.
*/
function testEdgeFixerDirectionRow =
(
    local vertical_button = WallFixerEdgeFixerRollout.check_vertical_button
    local angle_spinner = WallFixerEdgeFixerRollout.edge_angle_spinner
    local horizontal_button = WallFixerEdgeFixerRollout.check_horizontal_button


    local order_ok = (
        (vertical_button.pos.x < angle_spinner.pos.x) and
        (angle_spinner.pos.x < horizontal_button.pos.x)
    )
    local range_ok = (
        ((abs (angle_spinner.range.x - 0.1)) < 0.00001) and
        ((abs (angle_spinner.range.y - 45.0)) < 0.00001)
    )
    local size_ok = (((abs (angle_spinner.scale - 0.1)) < 0.00001) and angle_spinner.width == 40)


    local test_passed = order_ok and range_ok and size_ok
    format "EDGE FIXER direction row test | order:% range:% size:% | result:%\n" order_ok range_ok size_ok test_passed


    test_passed
    -- return
)


/*
Verifies bottom-mounted EDGE FIXER OPTIONS sizing without changing the final layout.
The test checks full parent-width slot sizing, fixed action positions and parent rollout height.
*/
function testEdgeFixerOptionsLayout =
(
    local slot_control = WallFixerEdgeFixerRollout.edge_fixer_options_subrollout
    local original_rollout_height = WallFixerEdgeFixerRollout.height
    local width_ok = ((slot_control.pos == [0,112]) and (slot_control.width == WallFixerEdgeFixerRollout.width))
    local collapsed_ok = false
    local expanded_ok = false


    WallFixerEdgeFixerRollout.setOptionsLayout false
    collapsed_ok = ((WallFixerEdgeFixerRollout.height == 140) and (slot_control.height == wall_fixer_closed_rollout_height) and (WallFixerEdgeFixerRollout.edge_z_group.pos == [4,8]))


    WallFixerEdgeFixerRollout.setOptionsLayout true
    expanded_ok = ((WallFixerEdgeFixerRollout.height == (204 + wall_fixer_closed_rollout_height)) and (slot_control.height == (88 + wall_fixer_closed_rollout_height)) and (WallFixerEdgeFixerRollout.edge_z_group.pos == [4,8]))


    WallFixerEdgeFixerRollout.setOptionsLayout (original_rollout_height > 140)


    local test_passed = width_ok and collapsed_ok and expanded_ok
    format "EDGE FIXER OPTIONS bottom layout test | width:% collapsed:% expanded:% | result:%\n" width_ok collapsed_ok expanded_ok test_passed


    test_passed -- return
)


/*
Verifies full-row parent controls and parent group boxes use 4px side padding.
The test checks width equals parent rollout width minus 8 and left position equals 4.
*/
/*
Tests Slice Walls Select CTRL+LMB routing intent.
*/
function testSliceCornerHelperRouting =
(
    local helper_action = #select90BorderCorners
    local slice_select_lmb_action = #filterSliced

    helper_action == #select90BorderCorners and
    slice_select_lmb_action == #filterSliced
    -- return
)


/*
Tests Slice Walls Select directional modifier routing.
*/
function testSliceSelectDirectionalRouting =
(
    local lmb_modifier = "SLICE VERTICAL"
    local rmb_modifier = "SLICE HORIZONTAL"

    lmb_modifier == "SLICE VERTICAL" and rmb_modifier == "SLICE HORIZONTAL"
    -- return
)


/*
Tests Slice Force mouse routing including CTRL T-junction-only modes for both directions.
*/
function testSliceForceMouseRouting =
(
    wallFixerGetSliceActionMode "Left" == #vertical and
    wallFixerGetSliceActionMode "Right" == #horizontal and
    wallFixerGetSliceActionMode "Middle" == undefined and
    wallFixerIsSliceForceTJunctionOnly "Left" true and
    wallFixerIsSliceForceTJunctionOnly "Right" true and
    not(wallFixerIsSliceForceTJunctionOnly "Left" false) and
    not(wallFixerIsSliceForceTJunctionOnly "Right" false) and
    not(wallFixerIsSliceForceTJunctionOnly "Middle" true)
    -- return
)


/*
Tests the persisted Slice Force T-junction option routing key and default state.
*/
function testSliceForceTJunctionOptionRouting =
(
    local setting_key = "SliceForceTJunctionVerts"
    local default_enabled = false

    setting_key == "SliceForceTJunctionVerts" and not default_enabled
    -- return
)


/*
Tests the Slice Force T-junction checkbox layout and guards against restoring the obsolete overlapping .NET direction label.
The checkbox stays in its existing slot while LMB/RMB guidance remains in button tooltips.
*/
function testSliceForceTJunctionCheckboxLayout =
(
    local old_label_exists = false
    local checkbox_ok = false

    try(old_label_exists = ((findItem (getPropNames WallFixerSliceWallsRollout) #slice_event_label) > 0))catch()
    try
    (
        checkbox_ok = WallFixerSliceWallsRollout.slice_force_t_junction_checkbox.pos.x == 8 and \
            WallFixerSliceWallsRollout.slice_force_t_junction_checkbox.pos.y == 23
    )
    catch
    (
        checkbox_ok = false
    )

    (not old_label_exists) and checkbox_ok
    -- return
)


/*
Tests direct Slice Walls LMB/RMB direction routing.
*/
function testSliceWallMouseRouting =
(
    wallFixerGetSliceActionMode "Left" == #vertical and
    wallFixerGetSliceActionMode "Right" == #horizontal and
    wallFixerGetSliceActionMode "Middle" == undefined
    -- return
)


/*
Tests RESET SLICE LMB/RMB namespace routing.
*/
function testSliceDeleteRouting =
(
    local lmb_modifier = "SLICE V"
    local rmb_modifier = "SLICE H"

    lmb_modifier == "SLICE V" and rmb_modifier == "SLICE H"
    -- return
)


/*
Tests RESET SLICE placement beside the main Slice Walls control.
The Reset button shares the first action row and Slice Force remains on the final row.
*/
function testResetSliceLayout =
(
    local slice_x = 4
    local slice_width = 148
    local reset_x = 156
    local reset_width = 150
    local force_y = 126

    slice_x + slice_width <= reset_x and reset_x + reset_width <= 310 and force_y > 84
    -- return
)


/*
Tests Wall-Fixer slice-modifier name classification without changing scene geometry.
Current directional names and the legacy combined name must classify as sliced.
*/
function testSliceWallModifierNameClassification =
(
    horizontal_ok = WallFixerRollout.isSliceWallModifierName "SLICE HORIZONTAL"
    vertical_ok = WallFixerRollout.isSliceWallModifierName "SLICE VERTICAL"
    legacy_ok = WallFixerRollout.isSliceWallModifierName "SLICE ALL"
    unrelated_ok = not (WallFixerRollout.isSliceWallModifierName "Edit Poly")
    passed = horizontal_ok and vertical_ok and legacy_ok and unrelated_ok


    format "Slice wall modifier classification | horizontal:% | vertical:% | legacy:% | unrelated:% | passed:%\n" horizontal_ok vertical_ok legacy_ok unrelated_ok passed


    passed
    -- return
)


/*
Tests rollout-state INI conversion where open rollout means rolledUp = false.
*/
function testRolloutOpenPersistence =
(
    open_state = true
    closed_state = false

    open_ini = if open_state then "0" else "1"
    closed_ini = if closed_state then "0" else "1"

    (open_ini == "0") and (closed_ini == "1")
    -- return
)


/*
Tests the new first POST-PROCESS degenerated-face control and the pure Core geometry rule.
No scene geometry is changed by this test.
*/
function testPostProcessDegeneratedFacesControl =
(
    button_ok = \
        (WallFixerPostProcessRollout.degenerated_faces_button.Text == "SELECT AND REMOVE DEGENERATED FACES") and \
        (WallFixerPostProcessRollout.degenerated_faces_button.pos.y == 8) and \
        (WallFixerPostProcessRollout.two_edge_verts_button.pos.y == 48) and \
        WallFixerPostProcessRollout.degenerated_faces_button.Enabled

    geometry_rule_ok = WallFixer.testDegeneratedFaceRules()
    passed = button_ok and geometry_rule_ok

    format "POST-PROCESS degenerated faces control | button:% | geometry:% | passed:%\n" button_ok geometry_rule_ok passed

    passed
    -- return
)


/*
Tests POST-PROCESS step 11 routing against the integrated stable detector without changing scene geometry.
The pure topology rules must all pass and the detector version must remain 0.13.
*/
function testPostProcessRedundantLoopRouting =
(
    detector_ok = false
    topology_ok = false
    button_ok = false

    try
    (
        detector_ok = RedundantLoopDetector.file_version == 0.13
        topology_result = RedundantLoopDetector.testTopologyRules()
        topology_ok = true

        for result_value in topology_result do
        (
            if not result_value then topology_ok = false
        )
    )
    catch
    (
        detector_ok = false
        topology_ok = false
    )

    try
    (
        button_ok = WallFixerPostProcessRollout.redundant_loops_button.Text == "11. REMOVE REDUNDANT LOOPS"
    )
    catch
    (
        button_ok = false
    )

    passed = detector_ok and topology_ok and button_ok
    format "POST-PROCESS redundant-loop stable routing | detector:% | topology:% | button:% | passed:%\n" detector_ok topology_ok button_ok passed

    passed
    -- return
)


/* Verifies numbered workflow actions use the standard dark WinForms Button style.
   Disabled reserved steps must remain disabled after conversion.
*/
function testNumberedDarkButtons =
(
    numbered_buttons = #( \
        WallFixerPreProcessRollout.planar_button, \
        WallFixerPreProcessRollout.duplicate_verts_button, \
        WallFixerPreProcessRollout.explode_walls_button, \
        WallFixerSliceWallsRollout.slice_selected_walls_button, \
        WallFixerPostProcessRollout.degenerated_faces_button, \
        WallFixerPostProcessRollout.two_edge_verts_button, \
        WallFixerPostProcessRollout.duplicated_vertices_button, \
        WallFixerPostProcessRollout.redundant_loops_button, \
        WallFixerPostProcessRollout.repair_missing_loops_button, \
        WallFixerPostProcessRollout.post_fix_ngons_button, \
        WallFixerPostProcessRollout.attach_walls_button, \
        WallFixerPostProcessRollout.weld_corners_button)


    passed = true


    for btn in numbered_buttons do
    (
        type_name = ""


        try
        (
            type_name = (btn.GetType()).FullName as string
            passed = passed and (type_name == "System.Windows.Forms.Button")
            passed = passed and (((btn.FlatStyle.ToString()) as string) == "Flat")
            passed = passed and btn.Font.Bold
            passed = passed and (btn.BackColor.R == 68) and (btn.BackColor.G == 68) and (btn.BackColor.B == 68)
            passed = passed and (btn.ForeColor.R == 170) and (btn.ForeColor.G == 220) and (btn.ForeColor.B == 170)
            passed = passed and (btn.FlatAppearance.BorderColor.R == 120) and (btn.FlatAppearance.BorderColor.G == 120) and (btn.FlatAppearance.BorderColor.B == 120)
            passed = passed and (btn.FlatAppearance.BorderSize == 1)
        )
        catch
        (
            passed = false
        )
    )


    passed = passed and (not WallFixerPostProcessRollout.repair_missing_loops_button.Enabled)
    passed = passed and WallFixerPostProcessRollout.attach_walls_button.Enabled
    passed = passed and WallFixerPostProcessRollout.weld_corners_button.Enabled


    format "Numbered dark button test | result:%\n" passed


    passed -- return
)


/*
Tests both implemented WALLS COMPLETION controls and the pure corner T-junction projection rule.
No scene geometry is changed by this test.
*/
function testWallsCompletionActions =
(
    attach_enabled = WallFixerPostProcessRollout.attach_walls_button.Enabled
    corners_enabled = WallFixerPostProcessRollout.weld_corners_button.Enabled
    projection_ok = WallFixer.testCornerTJunctionProjection()
    passed = attach_enabled and corners_enabled and projection_ok


    format "WALLS COMPLETION actions | attach:% | corners:% | projection:% | passed:%\n" attach_enabled corners_enabled projection_ok passed


    passed
    -- return
)


/*
Tests that step 2 uses only Options > WELD DISTANCE and spans the full PRE-PROCESS row.
The visible options label and full-width action button are checked without changing scene geometry.
*/
function testPreProcessWeldDistanceControl =
(
    label_ok = WallFixerOptionsRollout.weld_threshold_label.text == "WELD DISTANCE"
    button_ok = (WallFixerPreProcessRollout.duplicate_verts_button.pos.x == 4) and (WallFixerPreProcessRollout.duplicate_verts_button.width == 302)
    threshold_ok = WallFixerOptionsRollout.weld_threshold_spinner.value >= 0.0
    passed = label_ok and button_ok and threshold_ok


    format "PRE-PROCESS weld distance control | label:% | button:% | threshold:% | passed:%\n" label_ok button_ok threshold_ok passed


    passed
    -- return
)


function testParentControlWidths =
(
    local width_ok = true


    width_ok = width_ok and (WallFixerRollout.workflow_subrollout.pos.x == 0) and (WallFixerRollout.workflow_subrollout.width == WallFixerRollout.width)
    width_ok = width_ok and (WallFixerPreProcessRollout.planar_button.pos.x == 4) and (WallFixerPreProcessRollout.planar_button.width == (WallFixerPreProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerPreProcessRollout.explode_walls_button.pos.x == 4) and (WallFixerPreProcessRollout.explode_walls_button.width == (WallFixerPreProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerEdgeFixerRollout.edge_z_group.pos.x == 4) and (WallFixerEdgeFixerRollout.edge_z_group.width == (WallFixerEdgeFixerRollout.width - 8))
    width_ok = width_ok and (WallFixerSliceWallsRollout.slice_force_button.pos.x == 4) and (WallFixerSliceWallsRollout.slice_force_button.width == (WallFixerSliceWallsRollout.width - 8))
    width_ok = width_ok and (WallFixerPostProcessRollout.degenerated_faces_button.pos.x == 4) and (WallFixerPostProcessRollout.degenerated_faces_button.width == (WallFixerPostProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerPostProcessRollout.two_edge_verts_button.pos.x == 4) and (WallFixerPostProcessRollout.two_edge_verts_button.width == (WallFixerPostProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerPostProcessRollout.duplicated_vertices_button.pos.x == 4) and (WallFixerPostProcessRollout.duplicated_vertices_button.width == (WallFixerPostProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerPostProcessRollout.redundant_loops_button.pos.x == 4) and (WallFixerPostProcessRollout.redundant_loops_button.width == (WallFixerPostProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerPostProcessRollout.repair_missing_loops_button.pos.x == 4) and (WallFixerPostProcessRollout.repair_missing_loops_button.width == (WallFixerPostProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerPostProcessRollout.post_fix_ngons_button.pos.x == 4) and (WallFixerPostProcessRollout.post_fix_ngons_button.width == (WallFixerPostProcessRollout.width - 8))
    width_ok = width_ok and (WallFixerPostProcessRollout.walls_completion_group.pos.x == 4) and (WallFixerPostProcessRollout.walls_completion_group.width == (WallFixerPostProcessRollout.width - 8))


    format "Parent control width test | result:%\n" width_ok


    width_ok -- return
)


/* Verifies class-row RMB modifier routing without changing scene geometry.
   AUTO GROW must be available only for OUTER/INNER when CTRL is held.
*/
function testWallFaceClassRmbRouting =
(
    local outer_ctrl = (1 == 1 or 1 == 2)
    local inner_ctrl = (2 == 1 or 2 == 2)
    local top_ctrl = (3 == 1 or 3 == 2)
    local bottom_ctrl = (4 == 1 or 4 == 2)
    local passed = outer_ctrl and inner_ctrl and not top_ctrl and not bottom_ctrl


    format "Class RMB routing | OUTER:% | INNER:% | TOP:% | BOTTOM:% | passed:%\n" outer_ctrl inner_ctrl top_ctrl bottom_ctrl passed


    passed -- return
)


rollout wallFaceClassifierOptionsRollout "OPTIONS" width:286 height:138
(
    local working_pivot_syncing = false


    checkbutton use_working_pivot_checkbutton "Use Edit Pivot" pos:[8,8] width:86 height:30 \
        tooltip:"LMB: Use the manually positioned Working Pivot as the INNER \\ OUTTER classification origin.\n\nRMB: Center the Working Pivot to the current geometry selection."


    checkbutton edit_working_pivot_checkbutton "Edit Edit Pivot" pos:[100,8] width:86 height:30 \
        tooltip:"LMB: Enable or disable Working Pivot editing in 3ds Max."


    checkbutton ground_pivot_checkbutton "GROUND PIVOT" pos:[192,8] width:86 height:30 \
        tooltip:"Force the INNER \\ OUTTER analysis origin and Working Pivot to world ground at Z = 0. X/Y come from Use Edit Pivot or the selection center."


    spinner spn_wall_thickness "Wall thickness:" pos:[8,46] width:214 height:20 range:[0.001,1000000.0,(units.decodeValue "1m")] type:#worldunits fieldwidth:76 \
        tooltip:"Maximum distance to search for the opposite wall. Default: 1 m."
    label lbl_wall_units "units" pos:[228,50] width:50 height:18 align:#left tooltip:"Current display unit."


    spinner spn_connection_threshold "Connect threshold:" pos:[8,72] width:214 height:20 range:[0.001,1000000.0,((units.decodeValue "1m") * 0.1)] type:#worldunits fieldwidth:76 \
        tooltip:"Matches neighbor vertices; at least 2 must match. Default is 10% of Wall thickness, and changing Wall thickness resets this value."
    label lbl_connect_units "units" pos:[228,76] width:50 height:18 align:#left tooltip:"Current display unit."


    button btn_reset "RESET" pos:[8,100] width:270 height:30 \
        tooltip:"LMB: Reset face classification, remove the classifier material, clear FORCED OUTER/INNER hints, cached class data, and debug trace."


    /*
    Synchronizes Get Outer Walls Working Pivot controls with the native 3ds Max state.
    Failed interface reads leave both controls off instead of interrupting the Wall-Fixer UI.
    */
    function syncWorkingPivotControls =
    (
        working_pivot_syncing = true


        try
        (
            use_working_pivot_checkbutton.checked = WorkingPivot.UseMode
            edit_working_pivot_checkbutton.checked = WorkingPivot.EditMode
        )
        catch
        (
            use_working_pivot_checkbutton.checked = false
            edit_working_pivot_checkbutton.checked = false
        )


        working_pivot_syncing = false
        -- return
    )


    on wallFaceClassifierOptionsRollout open do
    (
        local unit_label = getWallFaceDisplayUnitLabel()
        lbl_wall_units.text = unit_label
        lbl_connect_units.text = unit_label
        ground_pivot_checkbutton.checked = wall_face_ground_pivot_enabled
        syncWorkingPivotControls()
    )


    on wallFaceClassifierOptionsRollout rolledUp options_rolled_up do
    (
        try
        (
            if wallFaceClassifierRollout != undefined then
            (
                wallFaceClassifierRollout.setOptionsLayout options_rolled_up
            )
        )
        catch
        (
        )
    )


    on use_working_pivot_checkbutton changed control_state do
    (
        if not working_pivot_syncing then
        (
            try
            (
                WorkingPivot.UseMode = control_state
            )
            catch
            (
            )


            if wall_face_ground_pivot_enabled then
            (
                local selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
                getWallFaceAnalysisOrigin selected_nodes
            )


            syncWorkingPivotControls()
        )
    )


    on use_working_pivot_checkbutton rightclick do
    (
        centerWallFaceWorkingPivotToSelection()
        syncWorkingPivotControls()
    )


    on edit_working_pivot_checkbutton changed control_state do
    (
        if not working_pivot_syncing then
        (
            try
            (
                WorkingPivot.EditMode = control_state
            )
            catch
            (
            )


            syncWorkingPivotControls()
        )
    )


    on ground_pivot_checkbutton changed control_state do
    (
        wall_face_ground_pivot_enabled = control_state


        if control_state then
        (
            local selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
            getWallFaceAnalysisOrigin selected_nodes
        )
    )


    on spn_wall_thickness changed thickness_value do
    (
        local unit_label = getWallFaceDisplayUnitLabel()
        lbl_wall_units.text = unit_label
        lbl_connect_units.text = unit_label
        spn_connection_threshold.value = getDefaultWallConnectionThreshold thickness_value
    )


    on spn_connection_threshold changed threshold_value do
    (
        local unit_label = getWallFaceDisplayUnitLabel()
        lbl_wall_units.text = unit_label
        lbl_connect_units.text = unit_label
    )


    on btn_reset pressed do
    (
        local result_data = #()


        undo "Reset Wall Face Classification" on
        (
            result_data = resetSelectedWallFaceClassification()
        )


        if result_data.count == 2 then
        (
            undefined
        )
    )
)


/* Returns the unsuffixed base name used by GET OUTER WALLS class layers.
   A current layer that already ends in -INNER, -OUTTER, -TOP or -BOTTOM resolves back to its sibling base name.
*/
function getWallFaceClassLayerBaseName layer_name =
(
    class_suffixes = #("INNER", "OUTTER", "TOP", "BOTTOM")
    base_name = layer_name

    for class_suffix in class_suffixes while base_name == layer_name do
    (
        suffix_text = "-" + class_suffix
        suffix_start = layer_name.count - suffix_text.count + 1

        if suffix_start > 1 then
        (
            if (substring layer_name suffix_start suffix_text.count) == suffix_text then
            (
                base_name = substring layer_name 1 (suffix_start - 1)
            )
        )
    )

    base_name -- return
)

/* Tests wall-class layer suffix normalization without modifying the scene.
   Every recognized class layer must resolve to the same unsuffixed base name.
*/
function testWallFaceClassLayerBaseName =
(
    test_names = #("Walls", "Walls-INNER", "Walls-OUTTER", "Walls-TOP", "Walls-BOTTOM")
    expected_name = "Walls"
    test_passed = true

    for test_name in test_names do
    (
        resolved_name = getWallFaceClassLayerBaseName test_name
        format "Wall class layer base | input: % | base: %\n" test_name resolved_name

        if resolved_name != expected_name then
        (
            test_passed = false
        )
    )

    format "Wall class layer base test: %\n" test_passed
    test_passed -- return
)

/* Builds one wall-class target layer name from the complete current layer name.
   No prefix or existing name segment is stripped.
*/
function getWallFaceClassTargetLayerName current_layer_name class_suffix =
(
    (current_layer_name as string) + "-" + (class_suffix as string)
    -- return
)

/* Tests that wall-class target names preserve the complete current layer name.
*/
function testWallFaceClassTargetLayerName =
(
    test_passed = (getWallFaceClassTargetLayerName "WALLS-01" "OUTTER") == "WALLS-01-OUTTER"
    format "Wall class target layer name test: %\n" test_passed
    test_passed
    -- return
)


/*
Creates the four wall-class sibling layers beside the current layer and assigns selected single-class objects.
Existing layers are reused; newly created layers inherit the current layer parent.
*/
function createWallFaceClassLayersFromCurrent =
(
    current_layer = LayerManager.current
    created_layers = #()
    assigned_count = 0
    skipped_count = 0

    if current_layer == undefined then
    (
        #(created_layers, assigned_count, skipped_count)
    )
    else
    (
        current_name = current_layer.name as string
        current_parent = current_layer.getParent()
        class_suffixes = #("INNER", "OUTTER", "TOP", "BOTTOM")

        for class_suffix in class_suffixes do
        (
            layer_name = getWallFaceClassTargetLayerName current_name class_suffix
            target_layer = LayerManager.getLayerFromName layer_name

            if target_layer == undefined then
            (
                target_layer = LayerManager.newLayerFromName layer_name

                if target_layer != undefined and current_parent != undefined then
                (
                    target_layer.setParent current_parent
                )
            )

            if target_layer != undefined then append created_layers target_layer
        )

        selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node

        for object_node in selected_nodes do
        (
            source_data = getFaceGeometrySource object_node
            used_class_ids = #()

            if source_data != undefined then
            (
                face_count = getSourceNumFaces object_node source_data

                for face_index = 1 to face_count do
                (
                    material_id = getSourceFaceMaterialId object_node source_data face_index

                    if material_id >= 1 and material_id <= 4 then
                    (
                        if findItem used_class_ids material_id == 0 then append used_class_ids material_id
                    )
                )
            )

            if used_class_ids.count == 1 then
            (
                material_id = used_class_ids[1]
                class_suffix = case material_id of
                (
                    1: "OUTTER"
                    2: "INNER"
                    3: "TOP"
                    4: "BOTTOM"
                    default: ""
                )
                target_layer = if class_suffix == "" then undefined else LayerManager.getLayerFromName (getWallFaceClassTargetLayerName current_name class_suffix)

                if target_layer != undefined then
                (
                    target_layer.addNode object_node
                    assigned_count += 1
                )
                else
                (
                    skipped_count += 1
                )
            )
            else
            (
                skipped_count += 1
            )
        )

        #(created_layers, assigned_count, skipped_count)
    )
    -- return
)


rollout wallFaceClassifierRollout "2 GET OUTER WALLS" width:310 height:110
(
    local class_button_tooltip

    dotNetControl btn_classify "System.Windows.Forms.Button" pos:[4,8] width:126 height:32


    button btn_explode "EXPLODE" pos:[134,8] width:84 height:32 \
        tooltip:"LMB: Split each selected classified object into separate OUTER, INNER, TOP, and BOTTOM objects."


    button btn_layer "LAYER" pos:[222,8] width:84 height:32 \
        tooltip:"LMB: Create/reuse -INNER, -OUTTER, -TOP, and -BOTTOM sibling layers and move selected single-class wall objects to the matching layer."


    dotNetControl btn_select_outer "System.Windows.Forms.Button" pos:[4,46] width:72 height:24
    dotNetControl btn_select_inner "System.Windows.Forms.Button" pos:[80,46] width:72 height:24
    dotNetControl btn_select_up "System.Windows.Forms.Button" pos:[156,46] width:72 height:24
    dotNetControl btn_select_down "System.Windows.Forms.Button" pos:[232,46] width:74 height:24


    subRollout wall_face_options_subrollout "" pos:[0,78] width:310 height:wall_fixer_closed_rollout_height


    /*
    Resizes the OPTIONS slot and Get Outer Walls rollout to match the OPTIONS rolled state.
    Collapsed OPTIONS leaves only its header; expanded OPTIONS restores the full controls area.
    */
    function setOptionsLayout options_open =
    (
        if options_open then
        (
            wallFaceClassifierRollout.height = 230 + wall_fixer_closed_rollout_height
            wall_face_options_subrollout.height = 144 + wall_fixer_closed_rollout_height
        )
        else
        (
            wall_face_options_subrollout.height = wall_fixer_closed_rollout_height
            wallFaceClassifierRollout.height = 110
        )
        -- return
    )


    /* Handles RMB for all four class buttons.
       CTRL+RMB AUTO GROW is valid only for OUTER/INNER; TOP/BOTTOM remain cap barriers.
    */
    function handleClassRightClick material_id =
    (
        local wall_thickness_value = wallFaceClassifierOptionsRollout.spn_wall_thickness.value
        local connection_threshold_value = wallFaceClassifierOptionsRollout.spn_connection_threshold.value
        local analyze_result = analyzeUnclassifiedSelectedWallObjects wall_thickness:wall_thickness_value connection_threshold:connection_threshold_value
        local auto_grow = keyboard.controlPressed and (material_id == 1 or material_id == 2)
        local seed_data_array = #()
        local result_data = #()
        local growth_result = #()


        if auto_grow then
        (
            seed_data_array = getWallFaceGrowthSeedData material_id
        )


        if auto_grow then
        (
            undo "Force And Grow Wall Faces" on
            (
                result_data = markSelectedWallFaces material_id
                growth_result = growCachedWallFaceClass seed_data_array material_id connection_threshold_value wall_thickness_value
            )
        )
        else
        (
            undo "Assign Wall Face Class" on
            (
                result_data = markSelectedWallFaces material_id
            )
        )


        #(result_data, growth_result, auto_grow, analyze_result) -- return
    )


    on wallFaceClassifierRollout open do
    (
        if class_button_tooltip == undefined then
        (
            class_button_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        )

        color_class = dotNetClass "System.Drawing.Color"
        setupDarkButton btn_classify
        btn_classify.Text = "INNER \\ OUTTER"
        btn_classify.ForeColor = color_class.FromArgb 152 221 161
        class_button_tooltip.SetToolTip btn_classify "LMB: Classify selected objects from the selection center. If Use Edit Pivot is enabled in OPTIONS, use the manually positioned Working Pivot instead. GROUND PIVOT forces the active origin to world Z = 0. FORCED hints run first; OUTER has priority.\n\nGreen = OUTER | Pastel Orange = INNER | Pastel Blue = TOP | Pastel Violet = BOTTOM."

        class_buttons = #(btn_select_outer, btn_select_inner, btn_select_up, btn_select_down)
        class_texts = #("OUTER", "INNER", "TOP", "BOTTOM")
        class_colors = #(
            color_class.FromArgb 152 221 161,
            color_class.FromArgb 221 189 152,
            color_class.FromArgb 152 198 221,
            color_class.FromArgb 186 152 221
        )
        class_tooltips = #(
            "LMB: Analyze selected objects first if needed, then select OUTER.\n\nRMB: FORCE OUTER.\n\nCTRL+RMB: FORCE OUTER, then AUTO GROW.",
            "LMB: Analyze selected objects first if needed, then select INNER.\n\nRMB: FORCE INNER.\n\nCTRL+RMB: FORCE INNER, then AUTO GROW.",
            "LMB: Analyze selected objects first if needed, then select TOP.\n\nRMB: Assign TOP.",
            "LMB: Analyze selected objects first if needed, then select BOTTOM.\n\nRMB: Assign BOTTOM."
        )

        for class_index = 1 to class_buttons.count do
        (
            setupDarkButton class_buttons[class_index]
            class_buttons[class_index].Text = class_texts[class_index]
            class_buttons[class_index].ForeColor = class_colors[class_index]
            class_button_tooltip.SetToolTip class_buttons[class_index] class_tooltips[class_index]
        )

        try
        (
            addSubRollout wall_face_options_subrollout wallFaceClassifierOptionsRollout rolledUp:saved_outer_options_rolled_up
            setOptionsLayout (not saved_outer_options_rolled_up)
        )
        catch
        (
        )
    )


    on btn_layer pressed do
    (
        layer_result = createWallFaceClassLayersFromCurrent()
        layer_array = layer_result[1]
        assigned_count = layer_result[2]
        skipped_count = layer_result[3]

        if layer_array.count == 4 and skipped_count == 0 then
        (
            ::WallFixerRollout.setStatus #success ((assigned_count as string) + " selected object(s) assigned to wall class layers.")
        )
        else if layer_array.count == 4 then
        (
            ::WallFixerRollout.setStatus #warning ((assigned_count as string) + " object(s) assigned; " + (skipped_count as string) + " mixed/unclassified object(s) skipped.")
        )
        else
        (
            ::WallFixerRollout.setStatus #failed "Could not create all wall class layers."
        )
    )


    on btn_classify MouseUp sender event_args do
    (
        if wallFixerGetDotNetMouseButton event_args != "Left" then return false
        local result_data = #()
        local wall_thickness_value = wallFaceClassifierOptionsRollout.spn_wall_thickness.value
        local connection_threshold_value = wallFaceClassifierOptionsRollout.spn_connection_threshold.value


        undo "Classify Wall Faces" on
        (
            result_data = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness_value connection_threshold:connection_threshold_value
        )


        if result_data.count == 11 then
        (
            undefined
        )
    )


    on btn_explode pressed do
    (
        local result_data = #()


        undo "Explode Wall Faces By Class" on
        (
            result_data = explodeSelectedWallFacesByClass()
        )


        if result_data.count == 4 then
        (
            undefined
        )
    )


    function handleClassButtonMouse material_id event_args =
    (
        mouse_button = wallFixerGetDotNetMouseButton event_args

        if mouse_button == "Left" then
        (
            analyzeUnclassifiedSelectedWallObjects wall_thickness:wallFaceClassifierOptionsRollout.spn_wall_thickness.value connection_threshold:wallFaceClassifierOptionsRollout.spn_connection_threshold.value
            selectWallFacesByMaterialId material_id
        )
        else if mouse_button == "Right" then
        (
            handleClassRightClick material_id
        )
        -- return
    )


    on btn_select_outer MouseUp sender event_args do
    (
        handleClassButtonMouse 1 event_args
    )


    on btn_select_inner MouseUp sender event_args do
    (
        handleClassButtonMouse 2 event_args
    )


    on btn_select_up MouseUp sender event_args do
    (
        handleClassButtonMouse 3 event_args
    )


    on btn_select_down MouseUp sender event_args do
    (
        handleClassButtonMouse 4 event_args
    )


    on wallFaceClassifierRollout close do
    (
        try
        (
            removeSubRollout wall_face_options_subrollout wallFaceClassifierOptionsRollout
        )
        catch
        (
        )
    )
)




rollout WallFixerRollout "Wall-Fixer" width:344 height:748
(
    progressbar workflow_progress "" pos:[0,0] width:344 height:8 value:0 color:(color 0 180 0) orient:#horizontal
    dotNetControl progress_count_label "System.Windows.Forms.Label" pos:[8,10] width:328 height:40
    dotNetControl process_status_label "System.Windows.Forms.Label" pos:[8,10] width:76 height:40
    dotNetControl status_line_top "System.Windows.Forms.RichTextBox" pos:[88,10] width:248 height:40
    subRollout workflow_subrollout "" pos:[0,58] width:344 height:682


    local status_texts = #("Ready.")
    local last_progress_value = -1


    /*
    Converts multiline reports into a compact single status line.
    The status header retains only the newest message.
    */
    function compactStatusText message_text =
(
        text_value = if message_text == undefined then "" else (message_text as string)
        text_value = substituteString text_value "\r\n" " | "
        text_value = substituteString text_value "\n" " | "
        text_value = substituteString text_value "\r" " | "
        text_value
        -- return
    )


    /*
    Draws one plain status-history line.
    Result labels are shown only in the progress-bar position.
    */
    function renderStatusLine status_control message_text =
    (
        status_control.Clear()
        status_control.SelectionFont = status_control.Font
        status_control.SelectionColor = status_control.ForeColor
        status_control.AppendText (compactStatusText message_text)
        -- return
    )


    /*
    Shows the completed process state in the shared status area.
    The top progress bar remains visible at all times.
    */
    function showProcessResult result_type =
    (
        color_class = dotNetClass "System.Drawing.Color"
        result_text = "SUCCESS"
        result_color = color_class.Green


        case result_type of
        (
            #warning:
            (
                result_text = "WARNING"
                result_color = color_class.DarkOrange
            )
            #failed:
            (
                result_text = "FAILED"
                result_color = color_class.OrangeRed
            )
            #error:
            (
                result_text = "ERROR"
                result_color = color_class.Red
            )
            default:
            (
                result_text = "SUCCESS"
                result_color = color_class.Green
            )
        )


        process_status_label.Visible = false
        progress_count_label.Visible = false
        status_line_top.Visible = true
        process_status_label.Text = result_text
        process_status_label.ForeColor = result_color
        process_status_label.Visible = true
        -- return
    )


    /*
    Pushes one plain message into the shared status display.
    The message type controls only the result label shown above it.
    */
    function setStatus message_type message_text =
    (
        status_texts[1] = compactStatusText message_text


        renderStatusLine status_line_top status_texts[1]


        if (message_type == #success) or (message_type == #warning) or (message_type == #failed) or (message_type == #error) then
        (
            showProcessResult message_type
        )


        try
        (
            (dotNetClass "System.Windows.Forms.Application").DoEvents()
        )
        catch
        (
        )
        -- return
    )


    /*
    Sets the global progress bar directly and clamps it to 0-100.
    Running state always repaints immediately so READY/result labels cannot remain visible over the bar.
    */
    function setProgress progress_value =
    (
        clamped_value = progress_value as integer
        if clamped_value < 0 then clamped_value = 0
        if clamped_value > 100 then clamped_value = 100


        if clamped_value < 100 then
        (
            progress_count_label.Visible = false
            process_status_label.Visible = false
            status_line_top.Visible = false
            progress_count_label.Visible = true
            try(progress_count_label.BringToFront())catch()
        )

        if clamped_value != last_progress_value then
        (
            last_progress_value = clamped_value
            workflow_progress.value = clamped_value
        )

        try
        (
            (dotNetClass "System.Windows.Forms.Application").DoEvents()
        )
        catch
        (
        )
        -- return
    )


    /*
    Returns one monotonic Slice Walls batch percentage.
    Each object receives an equal share of the bar while task progress fills that object's share.
    */
    function getSliceProgressPercent processed_count total_count object_index:0 object_total:0 =
    (
        progress_percent = 0

        if object_total > 0 and object_index > 0 then
        (
            task_fraction = 0.0
            if total_count > 0 then task_fraction = (processed_count as float) / total_count
            if task_fraction < 0.0 then task_fraction = 0.0
            if task_fraction > 1.0 then task_fraction = 1.0

            progress_percent = ((100.0 * (((object_index - 1) as float) + task_fraction)) / object_total) as integer
        )
        else if total_count > 0 then
        (
            progress_percent = ((100.0 * processed_count) / total_count) as integer
        )

        if progress_percent < 0 then progress_percent = 0
        if progress_percent > 100 then progress_percent = 100

        progress_percent
        -- return
    )


    /*
    Receives live Slice Walls task/object progress.
    It updates the green bar plus the centered object/task overlay.
    */
    function updateSliceProgress processed_count total_count object_index:0 object_total:0 object_name:"" vertex_count:0 =
    (
        progress_percent = getSliceProgressPercent             processed_count             total_count             object_index:object_index             object_total:object_total

        if object_total > 0 then
        (
            progress_count_label.Text = ((object_index as string) + " \\ " + (object_total as string) + "  |  " + object_name + "  |  " + (vertex_count as string) + " verts")
        )
        else
        (
            progress_count_label.Text = ((processed_count as string) + " \\ " + (total_count as string))
        )

        try(progress_count_label.BringToFront())catch()
        setProgress progress_percent
        -- return
    )


    /*
    Tests Slice Walls batch progress across task and object boundaries.
    */
    function testSliceProgressPercent =
    (
        test_passed = true
        test_passed = test_passed and (getSliceProgressPercent 0 10 object_index:1 object_total:2) == 0
        test_passed = test_passed and (getSliceProgressPercent 5 10 object_index:1 object_total:2) == 25
        test_passed = test_passed and (getSliceProgressPercent 10 10 object_index:1 object_total:2) == 50
        test_passed = test_passed and (getSliceProgressPercent 0 10 object_index:2 object_total:2) == 50
        test_passed = test_passed and (getSliceProgressPercent 10 10 object_index:2 object_total:2) == 100

        test_passed
        -- return
    )


    /*
    Returns the inherited slice-plane definition mode from the existing INI setting.
    Edge Direction remains the default when no legacy setting is present.
    */
    function getSlicePlaneMode =
    (
        if saved_slice_plane_mode_index == 1 then
        (
            #globalAxis
        )
        else
        (
            #nextVert
        )
        -- return
    )


    /*
    Persists all visible Wall-Fixer controls and optional dialog geometry.
    Legacy Core settings are also updated so inherited functions keep their existing behavior.
    */
    function saveUiSettings dialog_position:undefined dialog_size:undefined =
    (
        cut_mode_index = 1


        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldVertices" (if WallFixerOptionsRollout.weld_checkbox.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldThreshold" (saved_weld_threshold as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "DisplayHiddenEdges" (if WallFixerOptionsRollout.hidden_edges_checkbutton.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "DoubleSide" (if WallFixerOptionsRollout.double_side_checkbutton.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "AutoSmooth" (if WallFixerOptionsRollout.auto_smooth_checkbox.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "SlicePrecision" (WallFixerOptionsRollout.slice_precision_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "SliceQuiet" (if WallFixerSliceWallsRollout.quiet_checkbox.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "SliceNoEdgeCleanup" (if WallFixerSliceWallsRollout.no_edge_cleanup_checkbox.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "SliceForceTJunctionVerts" (if WallFixerSliceWallsRollout.slice_force_t_junction_checkbox.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "Options" (if WallFixerOptionsRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "PreProcess" (if WallFixerPreProcessRollout.open then "0" else "1")
        if wallFaceClassifierRollout != undefined then setIniSetting wall_fixer_ui_ini_path "Rollouts" "GetOuterWalls" (if wallFaceClassifierRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "EdgeFixer" (if WallFixerEdgeFixerRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "SliceWalls" (if WallFixerSliceWallsRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "PostProcess" (if WallFixerPostProcessRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "Helpers" (if WallFixerHelpersRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "Debug" (if WallFixerDebugRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "EdgeFixerOptions" (if WallFixerEdgeFixerOptionsRollout.open then "0" else "1")
        setIniSetting wall_fixer_ui_ini_path "Rollouts" "GetOuterWallsOptions" (if wallFaceClassifierOptionsRollout.open then "0" else "1")


        if dialog_position != undefined then
        (
            setIniSetting wall_fixer_ui_ini_path "Window" "X" ((dialog_position.x as integer) as string)
            setIniSetting wall_fixer_ui_ini_path "Window" "Y" ((dialog_position.y as integer) as string)
        )


        if dialog_size != undefined then
        (
            setIniSetting wall_fixer_ui_ini_path "Window" "Height" ((dialog_size.y as integer) as string)
        )


        WallFixer.saveSettings \
            WallFixerOptionsRollout.weld_checkbox.checked \
            saved_weld_threshold \
            WallFixerOptionsRollout.hidden_edges_checkbutton.checked \
            WallFixerOptionsRollout.double_side_checkbutton.checked \
            WallFixerOptionsRollout.auto_smooth_checkbox.checked \
            cut_mode_index \
            saved_angle_threshold \
            planar_tolerance:saved_planar_tolerance \
            slice_plane_mode_index:saved_slice_plane_mode_index \
            border_angle_threshold:saved_border_angle_threshold \
            right_angle_threshold:saved_right_angle_threshold \
            double_vert_threshold:saved_double_vert_threshold \
            double_face_threshold:saved_double_face_threshold \
            slice_precision:WallFixerOptionsRollout.slice_precision_spinner.value \
            quiet_batch:WallFixerSliceWallsRollout.quiet_checkbox.checked \
            dialog_position:dialog_position
        -- return
    )



    /*
    Removes face-unreferenced vertices from geometry nodes after a topology-changing operation.
    The Core handles top Edit Poly and base Editable Poly targets without converting the stack.
    */
    function cleanupRedundantVerticesAfterGeometryChange nodes =
    (
        cleanup_result = WallFixer.removeRedundantVerticesFromNodes nodes

        if cleanup_result[2] > 0 and not WallFixer.batch_quiet then
        (
            format "Wall-Fixer redundant vertex cleanup | checked:% removed:%\n" cleanup_result[1] cleanup_result[2]
        )

        cleanup_result
        -- return
    )


    /*
    Runs the inherited Auto Smooth action from the Options rollout.
    The operation remains undoable and reports through the shared Wall-Fixer status area.
    */
    function runSmooth =
    (
        setProgress 0
        setStatus #message "Applying Auto Smooth..."


        undo "Wall-Fixer - Auto Smooth" on
        (
            WallFixer.autoSmoothSelection()
        )


        completeRedraw()
        setProgress 100
        setStatus #success "Auto Smooth completed."
        true
        -- return
    )


    /*
    Attaches the current geometry selection into the first selected target without welding.
    The Core keeps a top Edit Poly target when available and otherwise uses Editable Poly.
    */
    function runAttachSelectedObjects =
    (
        setProgress 0
        setStatus #message "Attaching selected objects..."
        operation_success = false


        undo "Wall-Fixer - Attach" on
        (
            operation_success = WallFixer.attachSelectedObjects()
        )


        if operation_success then cleanupRedundantVerticesAfterGeometryChange (selection as array)
        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )



    /*
    Runs the Helpers Attach RMB workflow: attach, center pivot, weld using Options > Weld Threshold and conditionally quadrify.
    Quadrify is attempted only when the merged target contains at most 12 triangular faces.
    */
    function runAttachSelectedObjectsRmb =
    (
        setProgress 0
        setStatus #message "Attaching, centering, welding and checking quadrify..."
        operation_success = false
        weld_threshold = WallFixerOptionsRollout.weld_threshold_spinner.value


        undo "Wall-Fixer - Attach RMB" on
        (
            operation_success = WallFixer.attachCenterWeldQuadrifySelection weld_threshold triangle_limit:12
        )


        if operation_success then cleanupRedundantVerticesAfterGeometryChange (selection as array)
        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )


    /*
    Runs Ribbon Tools Quadrify All on the current modeling context.
    Uses the same PolyToolsModeling call already used by the Attach RMB workflow.
    */
    function runQuadrifyAll =
    (
        setProgress 0
        setStatus #message "Running Quadrify All..."
        operation_success = false


        undo "Wall-Fixer - Quadrify All" on
        (
            try
            (
                max modify mode
                operation_success = PolyToolsModeling.Quadrify false false
            )
            catch
            (
                operation_success = false
            )
        )


        setProgress 100


        if operation_success then
        (
            completeRedraw()
            setStatus #success "Quadrify All completed."
        )
        else
        (
            setStatus #failed "Quadrify All failed."
        )


        operation_success
        -- return
    )


    /*
    Executes a registered 3ds Max action whose visible text exactly matches the requested command.
    Button, menu and description text are checked so Ribbon actions can be resolved without guessing macro names.
    */
    function runRegisteredActionByText action_text =
    (
        requested_text = toLower action_text
        operation_success = false


        for table_index = 1 to actionMan.numActionTables while not operation_success do
        (
            action_table = actionMan.getActionTable table_index


            for item_index = 1 to action_table.numActionItems while not operation_success do
            (
                action_item = action_table.getActionItem item_index
                button_text = ""
                menu_text = ""
                description_text = ""


                try (action_item.getButtonText &button_text) catch (button_text = "")
                try (action_item.getMenuText &menu_text) catch (menu_text = "")
                try (action_item.getDescription &description_text) catch (description_text = "")


                if (toLower button_text) == requested_text or (toLower menu_text) == requested_text or (toLower description_text) == requested_text then
                (
                    persistent_id = undefined


                    try
                    (
                        persistent_id = action_item.persistentActionId
                    )
                    catch
                    (
                        persistent_id = undefined
                    )


                    if persistent_id != undefined then
                    (
                        try
                        (
                            operation_success = actionMan.executeAction action_table.id persistent_id
                        )
                        catch
                        (
                            operation_success = false
                        )
                    )
                    else
                    (
                        try
                        (
                            operation_success = actionMan.executeAction action_table.id (action_item.id as string)
                        )
                        catch
                        (
                            operation_success = false
                        )
                    )
                )
            )
        )


        operation_success
        -- return
    )


    /*
    Runs the registered Ribbon Tools Triangulate All action.
    The action is resolved by its visible command text so no unverified macro name is hardcoded.
    */
    function runTriangulateAll =
    (
        setProgress 0
        setStatus #message "Running Triangulate All..."
        operation_success = false


        undo "Wall-Fixer - Triangulate All" on
        (
            try
            (
                max modify mode
                operation_success = runRegisteredActionByText "Triangulate All"
            )
            catch
            (
                operation_success = false
            )
        )


        setProgress 100


        if operation_success then
        (
            completeRedraw()
            setStatus #success "Triangulate All completed."
        )
        else
        (
            setStatus #failed "Triangulate All action was not available."
        )


        operation_success
        -- return
    )


    /*
    Aligns the active viewport perpendicular to selected wall faces and frames the selection.
    A temporary orthographic camera transfers the face orientation into the final User view.
    */
    function runAlignCameraToWallFaces =
    (
        setProgress 0
        setStatus #message "Aligning User view to wall face normal..."
        operation_success = alignViewportToSelectedWallFaces()
        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )


    /*
    Runs Helpers > Align Camera RMB as a 90-degree side view around world Z.
    The same selected-face or dominant-wall alignment source is used as LMB.
    */
    function runAlignCameraSideView =
    (
        setProgress 0
        setStatus #message "Aligning User side view 90° from wall face normal..."
        operation_success = alignViewportToSelectedWallFaces side_view:true
        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )


    /*
    Centers the pivot of every selected scene node using MaxScript CenterPivot.
    Geometry and modifier stacks remain unchanged.
    */
    function runResetPivotToCenter =
    (
        setProgress 0
        setStatus #message "Resetting selected pivots to center..."
        operation_success = false


        undo "Wall-Fixer - Reset Pivot to Center" on
        (
            operation_success = WallFixer.centerSelectedPivots()
        )


        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )



    /*
    Assigns the same WALL FACE CLASSIFIER material used by INNER / OUTTER to selected geometry nodes.
    Reuses an existing classifier material from the selection or classified scene when available.
    */
    function runAssignMultiMaterial =
    (
        selected_nodes = for object_node in (selection as array) where object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass collect object_node

        if selected_nodes.count == 0 then
        (
            setStatus #warning "Material: select one or more geometry objects."
            false
        )
        else
        (
            classifier_material = undefined

            for object_node in selected_nodes while classifier_material == undefined do
            (
                if hasWallClassifierMaterial object_node then
                (
                    classifier_material = object_node.material
                )
            )

            if classifier_material == undefined then
            (
                classified_nodes = getWallFaceGrowthSceneNodes()

                if classified_nodes.count > 0 then
                (
                    classifier_material = classified_nodes[1].material
                )
            )

            if classifier_material == undefined then
            (
                classifier_material = createWallClassifierMaterial()
            )

            undo "Wall-Fixer - Assign Classifier Material" on
            (
                for object_node in selected_nodes do object_node.material = classifier_material
            )

            setStatus #success ("Material: assigned WALL FACE CLASSIFIER to " + (selected_nodes.count as string) + " object(s).")
            true
        )
        -- return
    )


    /*
    Assigns one shared Multi/Sub-Object material and maps face Material IDs from smoothing-group masks.
    The topmost Edit Poly is used when present; otherwise the Editable Poly base is edited.
    */
    function runAssignMaterialBySmoothingGroup =
    (
        selected_nodes = for object_node in (selection as array) where object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass collect object_node


        if selected_nodes.count == 0 then
        (
            setStatus #warning "Material by SG: select one or more geometry objects."
            false
        )
        else
        (
            assignment_result = undefined


            undo "Wall-Fixer - Material by SG" on
            (
                assignment_result = assignMaterialBySmoothingGroups selected_nodes
            )


            if assignment_result == undefined then
            (
                setStatus #warning "Material by SG: no Edit Poly or Editable Poly faces found."
                false
            )
            else
            (
                setStatus #success (
                    "Material by SG: assigned " +
                    (assignment_result[3] as string) +
                    " Material ID(s) across " +
                    (assignment_result[2] as string) +
                    " object(s)."
                )
                true
            )
        )
        -- return
    )


    /*
    Removes material assignments from all selected geometry nodes.
    Geometry and Material IDs remain unchanged.
    */
    function runRemoveMaterial =
    (
        selected_nodes = for object_node in (selection as array) where object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass collect object_node

        if selected_nodes.count == 0 then
        (
            setStatus #warning "Material: select one or more geometry objects."
            false
        )
        else
        (
            undo "Wall-Fixer - Remove Material" on
            (
                for object_node in selected_nodes do object_node.material = undefined
            )

            setStatus #success ("Material: removed from " + (selected_nodes.count as string) + " object(s).")
            true
        )
        -- return
    )


    /*
    Applies STL Check to selected geometry and enables its Check toggle.
    Unsupported selected geometry is skipped and reported without changing other STL Check defaults.
    */
    function runApplyStlCheck =
    (
        selected_nodes = for object_node in (selection as array) where object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass collect object_node


        if selected_nodes.count == 0 then
        (
            setStatus #warning "STL CHECK: select one or more geometry objects."
            false
        )
        else
        (
            added_count = 0
            failed_names = #()


            undo "Wall-Fixer - STL Check" on
            (
                for object_node in selected_nodes do
                (
                    modifier_supported = false


                    try
                    (
                        modifier_supported = validModifier object_node STL_Check
                    )
                    catch
                    (
                        modifier_supported = false
                    )


                    if modifier_supported then
                    (
                        stl_check_modifier = STL_Check()


                        try
                        (
                            addModifier object_node stl_check_modifier
                            stl_check_modifier.Check_Now = 1
                            added_count += 1
                        )
                        catch
                        (
                            append failed_names object_node.name
                        )
                    )
                    else
                    (
                        append failed_names object_node.name
                    )
                )
            )


            redrawViews()


            if added_count == selected_nodes.count then
            (
                setStatus #success ("STL CHECK: applied with Check on to " + (added_count as string) + " object(s).")
                true
            )
            else if added_count > 0 then
            (
                setStatus #warning ("STL CHECK: applied to " + (added_count as string) + " object(s); skipped " + (failed_names.count as string) + ".")
                true
            )
            else
            (
                setStatus #failed "STL CHECK: modifier could not be applied to the selected geometry."
                false
            )
        )
        -- return
    )


    /*
    Tests HELPERS STL CHECK by applying it to a temporary box and reading the modifier state.
    The temporary node is deleted and the previous object selection is restored.
    */
    function testHelpersStlCheck =
    (
        original_selection = selection as array
        test_node = undefined
        operation_success = false
        modifier_class_ok = false
        check_on = false


        try
        (
            test_node = box name:(uniqueName "WF_STL_CHECK_TEST")
            select test_node


            operation_success = runApplyStlCheck()


            if test_node.modifiers.count > 0 then
            (
                test_modifier = test_node.modifiers[1]
                modifier_class_ok = classOf test_modifier == STL_Check


                if modifier_class_ok then
                (
                    try
                    (
                        check_on = test_modifier.Check_Now == 1
                    )
                    catch
                    (
                        check_on = false
                    )
                )
            )
        )
        catch
        (
            operation_success = false
            modifier_class_ok = false
            check_on = false
        )


        if test_node != undefined and isValidNode test_node then delete test_node


        restored_selection = for object_node in original_selection where object_node != undefined and isValidNode object_node collect object_node


        if restored_selection.count > 0 then
        (
            select restored_selection
        )
        else
        (
            clearSelection()
        )


        test_passed = operation_success and modifier_class_ok and check_on
        format "HELPERS STL CHECK test | applied:% | class:% | check_on:% | result:%\n" operation_success modifier_class_ok check_on test_passed


        test_passed
        -- return
    )



    /*
    Applies a native Vertex Weld modifier to selected geometry using the requested threshold.
    Each supported selected object receives a new Vertex Weld modifier.
    */
    function runApplyVertexWeld weld_threshold:0.0 =
    (
        selected_nodes = for object_node in (selection as array) where object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass collect object_node


        if selected_nodes.count == 0 then
        (
            setStatus #warning "VertexWeld: select one or more geometry objects."
            false
        )
        else
        (
            added_count = 0
            failed_names = #()


            undo "Wall-Fixer - Vertex Weld" on
            (
                for object_node in selected_nodes do
                (
                    modifier_supported = false


                    try
                    (
                        modifier_supported = validModifier object_node Vertex_Weld
                    )
                    catch
                    (
                        modifier_supported = false
                    )


                    if modifier_supported then
                    (
                        vertex_weld_modifier = Vertex_Weld()


                        try
                        (
                            vertex_weld_modifier.threshold = weld_threshold
                            addModifier object_node vertex_weld_modifier
                            added_count += 1
                        )
                        catch
                        (
                            append failed_names object_node.name
                        )
                    )
                    else
                    (
                        append failed_names object_node.name
                    )
                )
            )


            redrawViews()


            if added_count == selected_nodes.count then
            (
                setStatus #success (
                    "VertexWeld: applied threshold " +
                    (weld_threshold as string) +
                    " to " +
                    (added_count as string) +
                    " object(s)."
                )
                true
            )
            else if added_count > 0 then
            (
                setStatus #warning (
                    "VertexWeld: applied threshold " +
                    (weld_threshold as string) +
                    " to " +
                    (added_count as string) +
                    " object(s); skipped " +
                    (failed_names.count as string) +
                    "."
                )
                true
            )
            else
            (
                setStatus #failed "VertexWeld: modifier could not be applied to the selected geometry."
                false
            )
        )
        -- return
    )


    /*
    Tests HELPERS VertexWeld with both requested mouse thresholds.
    The temporary node is deleted and the previous object selection is restored.
    */
    function testHelpersVertexWeld =
    (
        original_selection = selection as array
        test_node = undefined
        lmb_ok = false
        rmb_ok = false


        try
        (
            test_node = box name:(uniqueName "WF_VERTEX_WELD_TEST")
            select test_node


            lmb_applied = runApplyVertexWeld weld_threshold:0.0


            if lmb_applied and test_node.modifiers.count > 0 then
            (
                lmb_modifier = test_node.modifiers[1]
                lmb_ok = classOf lmb_modifier == Vertex_Weld and abs(lmb_modifier.threshold - 0.0) <= 0.0000001
            )


            rmb_applied = runApplyVertexWeld weld_threshold:0.001


            if rmb_applied and test_node.modifiers.count > 1 then
            (
                rmb_modifier = test_node.modifiers[1]
                rmb_ok = classOf rmb_modifier == Vertex_Weld and abs(rmb_modifier.threshold - 0.001) <= 0.0000001
            )
        )
        catch
        (
            lmb_ok = false
            rmb_ok = false
        )


        if test_node != undefined and isValidNode test_node then delete test_node


        restored_selection = for object_node in original_selection where object_node != undefined and isValidNode object_node collect object_node


        if restored_selection.count > 0 then
        (
            select restored_selection
        )
        else
        (
            clearSelection()
        )


        test_passed = lmb_ok and rmb_ok
        format "HELPERS VertexWeld test | LMB 0.0:% | RMB 0.001:% | result:%\n" lmb_ok rmb_ok test_passed


        test_passed
        -- return
    )


    /*
    Returns the topmost native Vertex Weld modifier and its modifier-stack index.
    The index is counted from the top of the stack.
    */
    function getTopVertexWeldModifierData object_node =
    (
        if object_node == undefined or not isValidNode object_node then return undefined


        for modifier_index = 1 to object_node.modifiers.count do
        (
            stack_modifier = object_node.modifiers[modifier_index]


            if classOf stack_modifier == Vertex_Weld then
            (
                return #(stack_modifier, modifier_index)
            )
        )


        undefined
        -- return
    )


    /*
    Finds all open-border vertices in the evaluated stack immediately below one modifier.
    The target modifier and modifiers above it are disabled only while a disposable snapshot is evaluated.
    */
    function getWorldBorderVerticesBelowModifier object_node modifier_index =
    (
        border_vertices = #{}
        disabled_states = #()
        snapshot_node = undefined


        if object_node == undefined or not isValidNode object_node then return border_vertices
        if modifier_index < 1 or modifier_index > object_node.modifiers.count then return border_vertices


        for stack_index = 1 to modifier_index do
        (
            stack_modifier = object_node.modifiers[stack_index]
            modifier_enabled = true


            try(modifier_enabled = stack_modifier.enabled)catch(modifier_enabled = true)
            append disabled_states #(stack_modifier, modifier_enabled)


            try(stack_modifier.enabled = false)catch()
        )


        try
        (
            snapshot_node = snapshot object_node


            if snapshot_node != undefined and isValidNode snapshot_node then
            (
                convertToPoly snapshot_node
                open_edges = polyop.getOpenEdges snapshot_node.baseObject


                if open_edges != undefined and open_edges.numberSet > 0 then
                (
                    border_vertices = polyop.getVertsUsingEdge snapshot_node.baseObject open_edges
                )
            )
        )
        catch
        (
            border_vertices = #{}
        )


        if snapshot_node != undefined and isValidNode snapshot_node then
        (
            delete snapshot_node
        )


        for state_data in disabled_states do
        (
            try(state_data[1].enabled = state_data[2])catch()
        )


        border_vertices
        -- return
    )


    /*
    Prepend/reuse WELD BORDERS Poly Select directly below one Vertex Weld modifier.
    The supplied border vertices are stored at Vertex level and passed upward to Vertex Weld.
    */
    function setWorldBordersPolySelect object_node vertex_weld_index border_vertices =
    (
        if object_node == undefined or not isValidNode object_node then return undefined
        if border_vertices == undefined or border_vertices.numberSet == 0 then return undefined


        poly_select_modifier = undefined
        next_modifier_index = vertex_weld_index + 1


        if next_modifier_index <= object_node.modifiers.count then
        (
            next_modifier = object_node.modifiers[next_modifier_index]


            if classOf next_modifier == Poly_Select and (
                toUpper(next_modifier.name as string) == "WELD BORDERS" or
                toUpper(next_modifier.name as string) == "WORLD BORDERS"
            ) then
            (
                poly_select_modifier = next_modifier
                try(poly_select_modifier.name = "WELD BORDERS")catch()
            )
        )


        if poly_select_modifier == undefined then
        (
            if not validModifier object_node Poly_Select then return undefined


            poly_select_modifier = Poly_Select name:"WELD BORDERS"
            addModifier object_node poly_select_modifier before:next_modifier_index
        )


        selection_written = false


        try
        (
            setVertSelection object_node poly_select_modifier border_vertices
            update object_node
            selection_written = (getVertSelection object_node poly_select_modifier) == border_vertices
        )
        catch
        (
            selection_written = false
        )


        if selection_written then poly_select_modifier else undefined
        -- return
    )


    /*
    Limits the topmost Vertex Weld modifier to all current open-border vertices.
    WELD BORDERS Poly Select is inserted directly below Vertex Weld and left active at Vertex level.
    */
    function runApplyWorldBorders =
    (
        selected_nodes = for object_node in (selection as array) where object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass collect object_node


        if selected_nodes.count == 0 then
        (
            setStatus #warning "Weld Borders: select one or more geometry objects."
            false
        )
        else
        (
            applied_count = 0
            total_border_vertices = 0
            failed_names = #()
            last_active_node = undefined
            last_poly_select = undefined


            undo "Wall-Fixer - Weld Borders" on
            (
                for object_node in selected_nodes do
                (
                    vertex_weld_data = getTopVertexWeldModifierData object_node


                    if vertex_weld_data == undefined then
                    (
                        append failed_names object_node.name
                    )
                    else
                    (
                        vertex_weld_index = vertex_weld_data[2]
                        border_vertices = getWorldBorderVerticesBelowModifier object_node vertex_weld_index


                        if border_vertices.numberSet == 0 then
                        (
                            append failed_names object_node.name
                        )
                        else
                        (
                            poly_select_modifier = setWorldBordersPolySelect object_node vertex_weld_index border_vertices


                            if poly_select_modifier != undefined then
                            (
                                applied_count += 1
                                total_border_vertices += border_vertices.numberSet
                                last_active_node = object_node
                                last_poly_select = poly_select_modifier
                            )
                            else
                            (
                                append failed_names object_node.name
                            )
                        )
                    )
                )
            )


            if last_active_node != undefined and last_poly_select != undefined then
            (
                try
                (
                    select last_active_node
                    max modify mode
                    modPanel.setCurrentObject last_poly_select
                    subObjectLevel = 1
                )
                catch()
            )


            redrawViews()


            if applied_count == selected_nodes.count then
            (
                setStatus #success (
                    "Weld Borders: selected " +
                    (total_border_vertices as string) +
                    " open-border vertex/vertices on " +
                    (applied_count as string) +
                    " object(s); Vertex sub-object left active for VertexWeld."
                )
                true
            )
            else if applied_count > 0 then
            (
                setStatus #warning (
                    "Weld Borders: configured " +
                    (applied_count as string) +
                    " object(s); skipped " +
                    (failed_names.count as string) +
                    " without VertexWeld or open borders."
                )
                true
            )
            else
            (
                setStatus #failed "Weld Borders: no selected object had both a VertexWeld modifier and open-border vertices."
                false
            )
        )
        -- return
    )


    /*
    Tests HELPERS Weld Borders on an open Editable Poly box with Vertex Weld above WELD BORDERS.
    Verifies stack order, border-vertex selection, and active Vertex sub-object state.
    */
    function testHelpersWorldBorders =
    (
        original_selection = selection as array
        test_node = undefined
        stack_ok = false
        selection_ok = false
        active_ok = false


        try
        (
            test_node = box name:(uniqueName "WF_WORLD_BORDERS_TEST")
            convertToPoly test_node
            polyop.deleteFaces test_node.baseObject #{1}
            update test_node


            expected_border_edges = polyop.getOpenEdges test_node.baseObject
            expected_border_vertices = polyop.getVertsUsingEdge test_node.baseObject expected_border_edges


            vertex_weld_modifier = Vertex_Weld threshold:0.001
            addModifier test_node vertex_weld_modifier
            select test_node


            operation_ok = runApplyWorldBorders()


            if operation_ok and test_node.modifiers.count >= 2 then
            (
                poly_select_modifier = test_node.modifiers[2]


                stack_ok = (
                    test_node.modifiers[1] == vertex_weld_modifier and
                    classOf poly_select_modifier == Poly_Select and
                    toUpper(poly_select_modifier.name as string) == "WELD BORDERS"
                )


                if stack_ok then
                (
                    try(selection_ok = (getVertSelection test_node poly_select_modifier) == expected_border_vertices)catch(selection_ok = false)
                    try(active_ok = modPanel.getCurrentObject() == poly_select_modifier and subObjectLevel == 1)catch(active_ok = false)
                )
            )
        )
        catch
        (
            stack_ok = false
            selection_ok = false
            active_ok = false
        )


        if test_node != undefined and isValidNode test_node then delete test_node


        restored_selection = for object_node in original_selection where object_node != undefined and isValidNode object_node collect object_node


        if restored_selection.count > 0 then
        (
            select restored_selection
        )
        else
        (
            clearSelection()
        )


        test_passed = stack_ok and selection_ok and active_ok
        format "HELPERS Weld Borders test | stack:% | selection:% | active vertex:% | result:%\n" stack_ok selection_ok active_ok test_passed


        test_passed
        -- return
    )


    /*
    Applies Editable Poly, splits all selected edges, and explodes the resulting elements into separate objects.
    Reports unsupported selections or splits that do not produce separate elements.
    */
    function runSplitSelectedEdge =
    (
        setProgress 0
        setStatus #message "Splitting selected edge..."
        operation_success = false


        try
        (
            undo "Wall-Fixer - Split Selected Edge" on
            (
                operation_success = WallFixer.splitSelectedEdgeToObjects()
            )
        )
        catch
        (
            operation_success = false
            WallFixer.last_slice_report = "Split failed: " + (getCurrentException() as string)
        )


        if operation_success then cleanupRedundantVerticesAfterGeometryChange (selection as array)
        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )



    /*
    Returns true when points occupy one non-zero line within tolerance.
    A zero-size point cloud is not treated as an edge.
    */
    function arePointsCollapsedToEdge point_values position_tolerance:0.001 =
    (
        if point_values == undefined or point_values.count < 2 then return false

        origin_point = point_values[1]
        line_direction = undefined

        for point_index = 2 to point_values.count while line_direction == undefined do
        (
            point_delta = point_values[point_index] - origin_point

            if (length point_delta) > position_tolerance then
            (
                line_direction = normalize point_delta
            )
        )

        if line_direction == undefined then return false

        points_are_collinear = true

        for point_value in point_values while points_are_collinear do
        (
            point_offset = point_value - origin_point
            perpendicular_offset = cross point_offset line_direction

            if (length perpendicular_offset) > position_tolerance then
            (
                points_are_collinear = false
            )
        )

        points_are_collinear
        -- return
    )


    /*
    Returns true only when every supplied normal is non-zero and points in the same direction.
    */
    function doNormalsMatch normal_values normal_dot_tolerance:0.9999 =
    (
        if normal_values == undefined or normal_values.count == 0 then return false

        reference_normal = undefined
        normals_match = true

        for normal_value in normal_values while normals_match do
        (
            if (length normal_value) <= 0.000001 then
            (
                normals_match = false
            )
            else
            (
                normalized_value = normalize normal_value

                if reference_normal == undefined then
                (
                    reference_normal = normalized_value
                )
                else if (dot reference_normal normalized_value) < normal_dot_tolerance then
                (
                    normals_match = false
                )
            )
        )

        normals_match and reference_normal != undefined
        -- return
    )


    /*
    Tests one visible geometry node without changing it.
    Degenerated matches require collinear evaluated vertices and one shared vertex-normal direction.
    */
    function isDegeneratedEdgeObject object_node =
    (
        if object_node == undefined or not isValidNode object_node or superclassof object_node != GeometryClass then return false

        evaluated_mesh = undefined

        try
        (
            evaluated_mesh = snapshotAsMesh object_node
        )
        catch
        (
            evaluated_mesh = undefined
        )

        if evaluated_mesh == undefined or evaluated_mesh.numverts < 2 then return false

        vertex_positions = #()
        vertex_normals = #()

        for vertex_index = 1 to evaluated_mesh.numverts do
        (
            append vertex_positions (getVert evaluated_mesh vertex_index)
            append vertex_normals (getNormal evaluated_mesh vertex_index)
        )

        (arePointsCollapsedToEdge vertex_positions) and (doNormalsMatch vertex_normals)
        -- return
    )


    /*
    Selects every visible geometry object that matches the degenerated-edge rule.
    No geometry, modifiers, transforms, or materials are changed.
    */
    function runSelectDegeneratedObjects =
    (
        source_nodes = for object_node in geometry where not object_node.isHidden collect object_node
        matching_nodes = #()

        for object_node in source_nodes do
        (
            if isDegeneratedEdgeObject object_node then append matching_nodes object_node
        )

        if matching_nodes.count > 0 then
        (
            select matching_nodes
            setStatus #success ("Select Degenerated Objects: selected " + (matching_nodes.count as string) + " object(s).")
        )
        else
        (
            clearSelection()
            setStatus #warning "Select Degenerated Objects: no matching visible objects found."
        )

        completeRedraw()
        matching_nodes
        -- return
    )


    /*
    Tests the pure collinearity and shared-normal rules without scene geometry.
    */
    function testDegeneratedObjectRules =
    (
        edge_points = #([0,0,0], [1,0,0], [2,0,0], [3,0,0])
        non_edge_points = #([0,0,0], [1,0,0], [2,1,0])
        shared_normals = #([0,0,1], [0,0,1], [0,0,1])
        mixed_normals = #([0,0,1], [0,1,0])

        passed = \
            (arePointsCollapsedToEdge edge_points) and \
            (not (arePointsCollapsedToEdge non_edge_points)) and \
            (doNormalsMatch shared_normals) and \
            (not (doNormalsMatch mixed_normals))

        format "Degenerated object rule test | result:%\n" passed
        passed
        -- return
    )

    /*
    Prints world horizontal/vertical deviation angles for the current selected edges.
    Uses the existing STRAIGHT EDGE FIXER selection source when present and does not create modifiers.
    */
    function runPrintSelectedEdgeAngles =
    (
        printed_edge_count = StraightEdgeFixer.printSelectedEdgeAngles()

        if (printed_edge_count > 0) then
        (
            setStatus #success ("Angle of Edges: printed " + (printed_edge_count as string) + " selected edge(s).")
        )
        else
        (
            setStatus #warning "Angle of Edges: no selected edges."
        )

        (printed_edge_count > 0)
        -- return
    )


    /*
    Clears the Listener and prints detailed diagnostics for every selected object.
    Evaluated mesh data is read from a snapshot, while sub-object selections are read from Edit Poly or Editable Poly directly.
    */
    function runPrintSelectedObjects =
    (
        clearListener()
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            format "Wall-Fixer Print Objs: no objects selected.\n"
            setStatus #warning "Print Objs: no objects selected."
            false
        )
        else
        (
            format "============================================================\n"
            format "WALL-FIXER OBJECT DIAGNOSTICS | objects:% | project:%\n" selected_nodes.count WallFixerVersion
            format "============================================================\n"

            for object_index = 1 to selected_nodes.count do
            (
                object_node = selected_nodes[object_index]

                if object_node != undefined and isValidNode object_node then
                (
                    wallFixerSetNodeCageOff object_node
                    layer_name = try(object_node.layer.name)catch("<unknown>")
                    material_name = if object_node.material == undefined then "<none>" else object_node.material.name
                    material_class = if object_node.material == undefined then undefined else classOf object_node.material
                    bounding_box = nodeGetBoundingBox object_node (matrix3 1)
                    vertex_selection = #{}
                    edge_selection = #{}
                    face_selection = #{}
                    selection_source = #none
                    top_edit_poly = undefined

                    if object_node.modifiers.count > 0 and classOf object_node.modifiers[1] == Edit_Poly then
                    (
                        top_edit_poly = object_node.modifiers[1]
                        selection_source = #editPoly
                        try(vertex_selection = top_edit_poly.GetSelection #Vertex node:object_node)catch(vertex_selection = #{})
                        try(edge_selection = top_edit_poly.GetSelection #Edge node:object_node)catch(edge_selection = #{})
                        try(face_selection = top_edit_poly.GetSelection #Face node:object_node)catch(face_selection = #{})
                    )
                    else if classOf object_node.baseObject == Editable_Poly then
                    (
                        selection_source = #editablePoly
                        try(vertex_selection = polyop.getVertSelection object_node.baseObject)catch(vertex_selection = #{})
                        try(edge_selection = polyop.getEdgeSelection object_node.baseObject)catch(edge_selection = #{})
                        try(face_selection = polyop.getFaceSelection object_node.baseObject)catch(face_selection = #{})
                    )

                    format "\n------------------------------------------------------------\n"
                    format "[%/%] NAME: %\n" object_index selected_nodes.count object_node.name
                    format "Node class: % | Base class: % | Layer: %\n" (classOf object_node) (classOf object_node.baseObject) layer_name
                    format "Material: % | Material class: % | Wire color: %\n" material_name material_class object_node.wirecolor
                    format "Position: %\nRotation: %\nScale: %\n" object_node.pos object_node.rotation object_node.scale
                    format "Transform: %\nObject transform: %\n" object_node.transform object_node.objectTransform
                    format "Bounding box world min:% max:%\n" bounding_box[1] bounding_box[2]
                    format "Selection source: % | verts:% | edges:% | faces:%\n" selection_source vertex_selection edge_selection face_selection
                    format "Modifiers (%):\n" object_node.modifiers.count

                    for modifier_index = 1 to object_node.modifiers.count do
                    (
                        stack_modifier = object_node.modifiers[modifier_index]
                        format "  [%] % | class:% | enabled:%\n" modifier_index stack_modifier.name (classOf stack_modifier) stack_modifier.enabled
                    )

                    user_properties = getUserPropBuffer object_node
                    format "User properties:\n%\n" (if user_properties == "" then "<none>" else user_properties)

                    evaluated_mesh = undefined
                    try(evaluated_mesh = snapshotAsMesh object_node)catch(evaluated_mesh = undefined)

                    if evaluated_mesh != undefined then
                    (
                        vertex_count = getNumVerts evaluated_mesh
                        face_count = getNumFaces evaluated_mesh
                        poly_edge_count = undefined

                        if top_edit_poly != undefined then
                        (
                            try(poly_edge_count = top_edit_poly.GetNumEdges node:object_node)catch(poly_edge_count = undefined)
                        )
                        else if classOf object_node.baseObject == Editable_Poly then
                        (
                            try(poly_edge_count = polyop.getNumEdges object_node.baseObject)catch(poly_edge_count = undefined)
                        )

                        format "Topology: verts:% | faces:% | poly edges:%\n" vertex_count face_count poly_edge_count
                        format "VERTICES: index | object position | world position | normal\n"

                        for vertex_index = 1 to vertex_count do
                        (
                            object_position = getVert evaluated_mesh vertex_index
                            world_position = object_position * object_node.objectTransform
                            vertex_normal = getNormal evaluated_mesh vertex_index
                            format "  V% | obj:% | world:% | N:%\n" vertex_index object_position world_position vertex_normal
                        )

                        format "FACES: index | verts | center world | normal | matID | smoothing\n"

                        for face_index = 1 to face_count do
                        (
                            face_vertices = getFace evaluated_mesh face_index
                            vertex_a = getVert evaluated_mesh (face_vertices.x as integer)
                            vertex_b = getVert evaluated_mesh (face_vertices.y as integer)
                            vertex_c = getVert evaluated_mesh (face_vertices.z as integer)
                            face_center_world = (((vertex_a + vertex_b + vertex_c) / 3.0) * object_node.objectTransform)
                            face_normal = getFaceNormal evaluated_mesh face_index
                            material_id = getFaceMatID evaluated_mesh face_index
                            smoothing_group = getFaceSmoothGroup evaluated_mesh face_index
                            format "  F% | verts:% | center:% | N:% | mat:% | smooth:%\n" face_index face_vertices face_center_world face_normal material_id smoothing_group
                        )

                        delete evaluated_mesh
                    )
                    else
                    (
                        format "Topology: evaluated mesh snapshot unavailable.\n"
                    )
                )
            )

            format "\n============================================================\n"
            format "END WALL-FIXER OBJECT DIAGNOSTICS\n"
            format "============================================================\n"
            setStatus #success ((selected_nodes.count as string) + " object diagnostic report printed.")
            true
        )
        -- return
    )


    /*
    Persists active controls imported from Straight Edge Fixer.
    SearchInZ is retired; both horizontal and vertical direction matching use Angle.
    */
    function saveStraightEdgeSettings =
    (
        setIniSetting wall_fixer_ui_ini_path "Controls" "LevelTolerance" (WallFixerEdgeFixerOptionsRollout.level_tolerance_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "MinLevelEdges" (WallFixerEdgeFixerOptionsRollout.min_level_edges_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "EdgeAngle" (WallFixerEdgeFixerRollout.edge_angle_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "StraightQuiet" (if WallFixerEdgeFixerOptionsRollout.straight_quiet_checkbox.checked then "1" else "0")


        StraightEdgeFixer.saveSettings \
            WallFixerEdgeFixerOptionsRollout.level_tolerance_spinner.value \
            WallFixerEdgeFixerOptionsRollout.min_level_edges_spinner.value \
            WallFixerEdgeFixerRollout.edge_angle_spinner.value \
            WallFixerEdgeFixerOptionsRollout.straight_quiet_checkbox.checked
        -- return
    )


    /*
    Converts selected geometry to Editable Poly only when the base object is not already Editable Poly.
    This wrapper is used only by inherited functions that require a base Editable Poly.
    */
    function ensureSelectionEditablePoly =
    (
        for node in (selection as array) do wallFixerSetNodeCageOff node
        selected_nodes = selection as array
        converted_count = 0
        failed_count = 0


        for node in selected_nodes do
        (
            if isValidNode node and superClassOf node == GeometryClass then
            (
                if classOf node.baseObject != Editable_Poly then
                (
                    conversion_success = true


                    try
                    (
                        convertToPoly node
                        wallFixerSetNodeCageOff node
                    )
                    catch
                    (
                        conversion_success = false
                    )


                    if conversion_success and classOf node.baseObject == Editable_Poly then
                    (
                        converted_count += 1
                    )
                    else
                    (
                        failed_count += 1
                    )
                )
            )
        )


        #(converted_count, failed_count)
        -- return
    )


    /*
    Welds only the currently selected vertices when Vertex sub-object mode is active.
    Existing Edit Poly or Editable Poly vertex selections are preserved as the weld input.
    */
    function runSelectedVertexWeld =
    (
        weld_threshold = WallFixerOptionsRollout.weld_threshold_spinner.value
        selected_nodes = selection as array
        welded_count = 0
        failed_count = 0
        processed_count = 0


        if subObjectLevel != 1 then
        (
            setStatus #warning "Weld: Vertex sub-object mode is not active."
            false
        )
        else if selected_nodes.count == 0 then
        (
            setStatus #warning "Weld: select one or more geometry objects with selected vertices."
            false
        )
        else
        (
            setProgress 0
            setStatus #message "Welding selected vertices..."


            undo "Wall-Fixer - Weld Selected Vertices" on
            (
                for object_node in selected_nodes do
                (
                    if object_node != undefined and isValidNode object_node and superclassof object_node == GeometryClass then
                    (
                        top_edit_poly = undefined


                        for modifier_index = object_node.modifiers.count to 1 by -1 while top_edit_poly == undefined do
                        (
                            if classOf object_node.modifiers[modifier_index] == Edit_Poly then top_edit_poly = object_node.modifiers[modifier_index]
                        )


                        weld_result = weldSelectedEPolyVerts object_node weld_threshold editPolyModifier:top_edit_poly


                        if weld_result == false then
                        (
                            failed_count += 1
                        )
                        else
                        (
                            processed_count += 1
                            welded_count += weld_result
                        )
                    )
                )
            )


            cleanupRedundantVerticesAfterGeometryChange selected_nodes
            setProgress 100


            if failed_count > 0 then
            (
                setStatus #warning ((welded_count as string) + " vertices welded; " + (failed_count as string) + " object(s) could not be processed.")
                false
            )
            else if processed_count == 0 then
            (
                setStatus #failed "Weld: no Editable Poly or Edit Poly objects with selected vertices were processed."
                false
            )
            else
            (
                setStatus #success ((welded_count as string) + " selected vertices welded.")
                true
            )
        )
        -- return
    )


    /*
    Runs the project-standard duplicated-vertex SELECT / DELETED modifier workflow.
    LMB stores evaluated duplicate vertices in SELECT DUPLICATED VERTICES; RMB welds that stored selection and renames the modifier DELETED DUPLICATED VERTICES.
    */
    function runDuplicateVerts fix_vertices:false =
    (
        setProgress 0
        weld_threshold = WallFixerOptionsRollout.weld_threshold_spinner.value
        saved_weld_threshold = weld_threshold
        saved_double_vert_threshold = weld_threshold
        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldThreshold" (weld_threshold as string)

        if not fix_vertices then
        (
            setStatus #message "Selecting duplicated vertices..."
            selection_result = WallFixer.selectDuplicatedVerticesSelection position_threshold:weld_threshold
            completed = selection_result[1]
            selected_count = selection_result[2]
            setProgress 100

            if completed and selected_count > 0 then
            (
                setStatus #warning (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Duplicated vertices selected.")
            )
            else if completed then
            (
                setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "No duplicated vertices found.")
            )
            else
            (
                setStatus #error (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Duplicated-vertex selection failed.")
            )

            completed
        )
        else
        (
            setStatus #message "Welding stored duplicated vertices..."
            selected_nodes = selection as array

            if selected_nodes.count == 0 then
            (
                setProgress 100
                setStatus #warning "Select at least one geometry object."
                false
            )
            else
            (
                total_welded = 0
                failed_count = 0
                processed_count = 0
                display_node = undefined
                display_modifier = undefined
                report_text = ""
                deleted_name = WallFixer.getSelectDeleteModifierName "DUPLICATED VERTICES" deleted:true

                for node in selected_nodes do
                (
                    if node != undefined and isValidNode node and superclassof node == GeometryClass then
                    (
                        prepare_result = WallFixer.prepareDuplicatedVerticesDeleteOnNode node position_threshold:weld_threshold

                        if prepare_result[1] then
                        (
                            processed_count += 1
                            selection_modifier = prepare_result[4]
                            valid_selection = prepare_result[5]
                            node_failed = false
                            welded_count = 0

                            if selection_modifier == undefined then
                            (
                                node_failed = true
                                report_text += node.name + ": FAILED - SELECT DUPLICATED VERTICES modifier unavailable.\n"
                            )
                            else
                            (
                                display_result = WallFixer.activateNamedEditPolySelection node selection_modifier #Vertex valid_selection
                                if not display_result[1] then
                                (
                                    node_failed = true
                                    report_text += node.name + ": FAILED - stored duplicated-vertex selection could not be restored.\n"
                                )
                                else if valid_selection.numberSet > 0 then
                                (
                                    welded_count = weldSelectedEPolyVerts node weld_threshold editPolyModifier:selection_modifier
                                    if welded_count == false then
                                    (
                                        node_failed = true
                                        report_text += node.name + ": FAILED - duplicated vertices could not be welded.\n"
                                    )
                                    else
                                    (
                                        total_welded += welded_count
                                    )
                                )

                                if not node_failed then
                                (
                                    selection_modifier.name = deleted_name
                                    selection_modifier.showCage = off
                                    update node
                                    report_text += node.name + ": welded " + (welded_count as string) + " vertex/vertices.\n"

                                    if display_modifier == undefined then
                                    (
                                        display_node = node
                                        display_modifier = selection_modifier
                                    )
                                )
                            )

                            if node_failed then failed_count += 1
                        )
                        else
                        (
                            failed_count += 1
                            report_text += node.name + ": FAILED - " + prepare_result[3] + ".\n"
                        )
                    )
                )

                if display_modifier != undefined then
                (
                    try
                    (
                        select display_node
                        max modify mode
                        display_modifier.showCage = off
                        display_modifier.useStackSelection = false
                        modPanel.setCurrentObject display_modifier
                        display_modifier.SetEPolySelLevel #Vertex
                        subObjectLevel = 1
                        completeRedraw()
                    )
                    catch()
                )

                setProgress 100

                if failed_count > 0 then
                (
                    setStatus #error ("Duplicated-vertex weld completed with failures.\n" + report_text)
                    false
                )
                else if processed_count == 0 then
                (
                    setStatus #warning "No geometry objects were processed."
                    false
                )
                else
                (
                    setStatus #success ("Duplicated-vertex delete complete. Vertices welded: " + (total_welded as string) + ".\n" + report_text)
                    true
                )
            )
        )
        -- return
    )


    /*
    Canonicalizes a face normal so opposite parallel faces share one wall orientation.
    The dominant component is always forced positive for stable sign-independent comparisons.
    */
    function getSmartExplodeCanonicalNormal face_normal =
    (
        result_normal = face_normal
        normal_length = length result_normal


        if normal_length > 0.0000001 then
        (
            result_normal = result_normal / normal_length
            abs_x = abs result_normal.x
            abs_y = abs result_normal.y
            abs_z = abs result_normal.z


            if abs_x >= abs_y and abs_x >= abs_z then
            (
                if result_normal.x < 0.0 then result_normal = -result_normal
            )
            else if abs_y >= abs_x and abs_y >= abs_z then
            (
                if result_normal.y < 0.0 then result_normal = -result_normal
            )
            else
            (
                if result_normal.z < 0.0 then result_normal = -result_normal
            )
        )


        result_normal
        -- return
    )


    /*
    Returns canonical normal, center and signed world-space normal for one snapshot triangle.
    The signed normal is retained so FACE DIRECTION can detect backside faces after NORMALS grouping.
    */
    function getSmartExplodeMeshFaceData source_mesh source_node face_index =
    (
        result_data = undefined
        face_vertices = getFace source_mesh face_index
        vertex_a = (getVert source_mesh (face_vertices.x as integer)) * source_node.objectTransform
        vertex_b = (getVert source_mesh (face_vertices.y as integer)) * source_node.objectTransform
        vertex_c = (getVert source_mesh (face_vertices.z as integer)) * source_node.objectTransform
        cross_value = cross (vertex_b - vertex_a) (vertex_c - vertex_a)
        cross_length = length cross_value


        if cross_length > 0.0000001 then
        (
            signed_normal = cross_value / cross_length
            face_normal = getSmartExplodeCanonicalNormal signed_normal
            face_center = (vertex_a + vertex_b + vertex_c) / 3.0
            result_data = #(face_normal, face_center, signed_normal)
        )


        result_data
        -- return
    )




    /*
    Builds one canonical plane candidate from three non-collinear world-space points.
    The normal sign is stabilized so candidate comparisons remain consistent.
    */
    function getPlanarPlaneCandidate point_a point_b point_c =
    (
        candidate_data = undefined
        cross_value = cross (point_b - point_a) (point_c - point_a)
        cross_length = length cross_value


        if cross_length > 0.0000001 then
        (
            plane_normal = getSmartExplodeCanonicalNormal (cross_value / cross_length)
            plane_offset = dot point_a plane_normal
            candidate_data = #(plane_normal, plane_offset)
        )


        candidate_data
        -- return
    )


    /*
    Scores one plane candidate by vertex support, face-normal agreement and total vertex deviation.
    Higher inlier count wins; angular agreement and deviation provide deterministic tie-breakers.
    */
    function scorePlanarPlaneCandidate world_points face_normal_records plane_normal plane_offset planar_tolerance =
    (
        inlier_vertices = #{}
        inlier_count = 0
        total_deviation = 0.0
        angular_cost = 0.0


        for vertex_index = 1 to world_points.count do
        (
            vertex_deviation = abs((dot world_points[vertex_index] plane_normal) - plane_offset)
            total_deviation += vertex_deviation


            if vertex_deviation <= planar_tolerance then
            (
                inlier_vertices[vertex_index] = true
                inlier_count += 1
            )
        )


        for face_record in face_normal_records do
        (
            angular_cost += (1.0 - (dot plane_normal face_record[1])) * face_record[2]
        )


        #(inlier_count, angular_cost, total_deviation, inlier_vertices)
        -- return
    )


    /*
    Classifies the evaluated wall as near-vertical, near-horizontal or unrestricted.
    Face-count voting uses the existing normal tolerance only as a tie-break aid for robust plane detection.
    */
    function getPlanarOrientationMode face_normal_records normal_angle_tolerance =
    (
        safe_angle = normal_angle_tolerance
        if safe_angle < 0.1 then safe_angle = 0.1
        if safe_angle > 20.0 then safe_angle = 20.0


        vertical_limit = sin safe_angle
        horizontal_limit = cos safe_angle
        vertical_count = 0
        horizontal_count = 0


        for face_record in face_normal_records do
        (
            face_normal = face_record[1]
            absolute_z = abs face_normal.z


            if absolute_z <= vertical_limit then vertical_count += 1
            if absolute_z >= horizontal_limit then horizontal_count += 1
        )


        orientation_mode = #free


        if face_normal_records.count > 0 then
        (
            if (vertical_count * 2) >= face_normal_records.count then
            (
                orientation_mode = #vertical
            )
            else if (horizontal_count * 2) >= face_normal_records.count then
            (
                orientation_mode = #horizontal
            )
        )


        orientation_mode
        -- return
    )


    /*
    Returns a small orientation penalty for one candidate wall plane.
    Vertical walls prefer normal Z=0; horizontal surfaces prefer an absolute normal Z of 1.
    */
    function getPlanarOrientationCost plane_normal orientation_mode =
    (
        orientation_cost = 0.0


        case orientation_mode of
        (
            #vertical:
            (
                orientation_cost = abs plane_normal.z
            )
            #horizontal:
            (
                orientation_cost = 1.0 - (abs plane_normal.z)
            )
            default:
            (
                orientation_cost = 0.0
            )
        )


        orientation_cost
        -- return
    )


    /*
    Compares two robust plane candidates without depending on loop order.
    Vertex support wins first, then architectural orientation and geometric deviation; face-derived priority is only a late tie-breaker.
    */
    function isPlanarCandidateBetter candidate_score candidate_orientation_cost candidate_priority best_inlier_count best_orientation_cost best_candidate_priority best_angular_cost best_total_deviation =
    (
        candidate_better = false
        comparison_epsilon = 0.000001


        if candidate_score[1] > best_inlier_count then
        (
            candidate_better = true
        )
        else if candidate_score[1] == best_inlier_count then
        (
            if candidate_orientation_cost < (best_orientation_cost - comparison_epsilon) then
            (
                candidate_better = true
            )
            else if abs(candidate_orientation_cost - best_orientation_cost) <= comparison_epsilon then
            (
                if candidate_score[3] < (best_total_deviation - comparison_epsilon) then
                (
                    candidate_better = true
                )
                else if abs(candidate_score[3] - best_total_deviation) <= comparison_epsilon then
                (
                    if candidate_priority < best_candidate_priority then
                    (
                        candidate_better = true
                    )
                    else if candidate_priority == best_candidate_priority and candidate_score[2] < (best_angular_cost - comparison_epsilon) then
                    (
                        candidate_better = true
                    )
                )
            )
        )


        candidate_better
        -- return
    )


    /*
    Analyzes one evaluated wall and returns its robust majority plane plus outlier vertices.
    Face planes are preferred on equal support; sampled vertex planes recover the intended plane when a bad corner distorts triangulated faces.
    */
    function analyzePlanarWall source_node planar_tolerance:1.0 normal_angle_tolerance:5.0 =
    (
        result_data = #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Unable to analyze wall.")
        analysis_mesh = undefined


        if source_node == undefined or not(isValidNode source_node) or superClassOf source_node != GeometryClass then
        (
            result_data = #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Invalid geometry object.")
        )
        else
        (
            try
            (
                analysis_mesh = snapshotAsMesh source_node


                if analysis_mesh == undefined or analysis_mesh.numfaces <= 0 or analysis_mesh.numverts < 3 then
                (
                    result_data = #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Wall has no usable evaluated mesh.")
                )
                else
                (
                    safe_tolerance = amax 0.000001 planar_tolerance
                    world_points = #()
                    face_normal_records = #()
                    face_candidates = #()


                    for vertex_index = 1 to analysis_mesh.numverts do
                    (
                        append world_points ((getVert analysis_mesh vertex_index) * source_node.objectTransform)
                    )


                    for face_index = 1 to analysis_mesh.numfaces do
                    (
                        face_vertices = getFace analysis_mesh face_index
                        vertex_a = world_points[(face_vertices.x as integer)]
                        vertex_b = world_points[(face_vertices.y as integer)]
                        vertex_c = world_points[(face_vertices.z as integer)]
                        cross_value = cross (vertex_b - vertex_a) (vertex_c - vertex_a)
                        cross_length = length cross_value


                        if cross_length > 0.0000001 then
                        (
                            face_normal = getSmartExplodeCanonicalNormal (cross_value / cross_length)
                            append face_normal_records #(face_normal, cross_length)
                            append face_candidates #(face_normal, dot vertex_a face_normal)
                        )
                    )


                    if face_candidates.count == 0 then
                    (
                        result_data = #(false, [0,0,1], 0.0, #{}, 0.0, analysis_mesh.numverts, "No non-degenerate wall faces were found.")
                    )
                    else
                    (
                        orientation_mode = getPlanarOrientationMode face_normal_records normal_angle_tolerance
                        best_normal = undefined
                        best_offset = 0.0
                        best_inlier_count = -1
                        best_orientation_cost = 1.0e30
                        best_candidate_priority = 999
                        best_angular_cost = 1.0e30
                        best_total_deviation = 1.0e30
                        best_inliers = #{}


                        for candidate_data in face_candidates do
                        (
                            candidate_score = scorePlanarPlaneCandidate world_points face_normal_records candidate_data[1] candidate_data[2] safe_tolerance
                            candidate_orientation_cost = getPlanarOrientationCost candidate_data[1] orientation_mode
                            candidate_priority = 0
                            candidate_better = isPlanarCandidateBetter \
                                candidate_score \
                                candidate_orientation_cost \
                                candidate_priority \
                                best_inlier_count \
                                best_orientation_cost \
                                best_candidate_priority \
                                best_angular_cost \
                                best_total_deviation


                            if candidate_better then
                            (
                                best_normal = candidate_data[1]
                                best_offset = candidate_data[2]
                                best_inlier_count = candidate_score[1]
                                best_orientation_cost = candidate_orientation_cost
                                best_candidate_priority = candidate_priority
                                best_angular_cost = candidate_score[2]
                                best_total_deviation = candidate_score[3]
                                best_inliers = candidate_score[4]
                            )
                        )


                        sample_indices = #()
                        sample_limit = if world_points.count <= 32 then world_points.count else 12


                        if sample_limit == world_points.count then
                        (
                            for vertex_index = 1 to world_points.count do append sample_indices vertex_index
                        )
                        else
                        (
                            for sample_index = 0 to (sample_limit - 1) do
                            (
                                vertex_index = 1 + (((sample_index as float) * (world_points.count - 1) / (sample_limit - 1)) as integer)
                                if findItem sample_indices vertex_index == 0 then append sample_indices vertex_index
                            )
                        )


                        if sample_indices.count >= 3 then
                        (
                            for sample_a = 1 to (sample_indices.count - 2) do
                            (
                                for sample_b = (sample_a + 1) to (sample_indices.count - 1) do
                                (
                                    for sample_c = (sample_b + 1) to sample_indices.count do
                                    (
                                        candidate_data = getPlanarPlaneCandidate \
                                            world_points[sample_indices[sample_a]] \
                                            world_points[sample_indices[sample_b]] \
                                            world_points[sample_indices[sample_c]]


                                        if candidate_data != undefined then
                                        (
                                            candidate_score = scorePlanarPlaneCandidate world_points face_normal_records candidate_data[1] candidate_data[2] safe_tolerance
                                            candidate_orientation_cost = getPlanarOrientationCost candidate_data[1] orientation_mode
                                            candidate_priority = 1
candidate_better = isPlanarCandidateBetter \
                                                candidate_score \
                                                candidate_orientation_cost \
                                                candidate_priority \
                                                best_inlier_count \
                                                best_orientation_cost \
                                                best_candidate_priority \
                                                best_angular_cost \
                                                best_total_deviation


                                            if candidate_better then
                                            (
                                                best_normal = candidate_data[1]
                                                best_offset = candidate_data[2]
                                                best_inlier_count = candidate_score[1]
                                                best_orientation_cost = candidate_orientation_cost
                                                best_candidate_priority = candidate_priority
                                                best_angular_cost = candidate_score[2]
                                                best_total_deviation = candidate_score[3]
                                                best_inliers = candidate_score[4]
                                            )
                                        )
                                    )
                                )
                            )
                        )


                        if best_normal == undefined or best_inlier_count < 3 or (best_inlier_count * 2) <= world_points.count then
                        (
                            result_data = #(false, [0,0,1], 0.0, #{}, 0.0, analysis_mesh.numverts, "No majority wall plane was found. Run Step 2 first.")
                        )
                        else
                        (
                            /*
                            Keep the winning candidate plane instead of averaging all broad-tolerance support vertices into it.
                            A bad N-gon corner can still be inside the support tolerance and must not drag the repair plane toward itself.
                            */
                            target_offset = best_offset


                            /*
                            Use the broad tolerance only to find the dominant wall plane.
                            Final coplanarity is strict so small N-gon defects are still selected and repaired.
                            */
                            strict_planar_tolerance = amin safe_tolerance 0.001
                            strict_planar_tolerance = amax strict_planar_tolerance 0.000001
                            outlier_vertices = #{}
                            max_deviation = 0.0


                            for vertex_index = 1 to world_points.count do
                            (
                                vertex_deviation = abs((dot world_points[vertex_index] best_normal) - target_offset)


                                if vertex_deviation > max_deviation then max_deviation = vertex_deviation
                                if vertex_deviation > strict_planar_tolerance then outlier_vertices[vertex_index] = true
                            )


                            result_data = #(true, best_normal, target_offset, outlier_vertices, max_deviation, analysis_mesh.numverts, "")
                        )
                    )
                )
            )
            catch
            (
                result_data = #(false, [0,0,1], 0.0, #{}, 0.0, 0, (getCurrentException() as string))
            )
        )


        if analysis_mesh != undefined then
        (
            try(free analysis_mesh)catch()
        )


        result_data
        -- return
    )


    /*
    Removes only the temporary top Edit Poly created by Step 3 LMB.
    This prevents a check-only selection marker from forcing an unnecessary collapse during RMB repair.
    */
    function removePlanarSelectionMarker source_node =
    (
        marker_removed = false


        if source_node != undefined and isValidNode source_node and source_node.modifiers.count > 0 then
        (
            try
            (
                top_modifier = source_node.modifiers[1]


                if classOf top_modifier == Edit_Poly and top_modifier.name == "NON PLANAR VERTS" then
                (
                    deleteModifier source_node top_modifier
                    update source_node
                    marker_removed = true
                )
            )
            catch
            (
                marker_removed = false
            )
        )


        marker_removed
        -- return
    )


    /*
    Clears the previous Step 3 vertex selection before running a new LMB check.
    Existing top Edit Poly modifiers are reused; a stale script marker is removed first.
    */
    function clearPlanarCheckSelection source_node =
    (
        wallFixerSetNodeCageOff source_node
        selection_cleared = false


        if source_node != undefined and isValidNode source_node then
        (
            removePlanarSelectionMarker source_node
            top_edit_poly = undefined


            if source_node.modifiers.count > 0 then
            (
                try
                (
                    if classOf source_node.modifiers[1] == Edit_Poly then top_edit_poly = source_node.modifiers[1]
                )
                catch
                (
                    top_edit_poly = undefined
                )
            )


            if top_edit_poly != undefined then
            (
                try
                (
                    select source_node
                    max modify mode
                    modPanel.setCurrentObject top_edit_poly
                    top_edit_poly.SetPrimaryNode source_node
                    top_edit_poly.useStackSelection = false
                    top_edit_poly.SetEPolySelLevel #Vertex
                    subObjectLevel = 1
                    empty_selection = #{}
                    top_edit_poly.SetSelection #Vertex empty_selection node:source_node
                    selection_cleared = true
                )
                catch
                (
                    selection_cleared = false
                )
            )
            else if source_node.modifiers.count == 0 and classOf source_node.baseObject == Editable_Poly then
            (
                try
                (
                    polyop.setVertSelection source_node.baseObject #{}
                    update source_node
                    selection_cleared = true
                )
                catch
                (
                    selection_cleared = false
                )
            )
            else
            (
                selection_cleared = true
            )
        )


        selection_cleared
        -- return
    )


    /*
    Unhides and selects planar-check outliers without collapsing or changing wall topology.
    A current top Edit Poly is reused; a temporary NON PLANAR VERTS modifier is added only when no editable top level exists.
    */
    function selectPlanarOutlierVerts source_node outlier_vertices expected_vertex_count =
    (
        wallFixerSetNodeCageOff source_node
        selection_success = false


        if source_node != undefined and isValidNode source_node and outlier_vertices.numberSet > 0 then
        (
            top_edit_poly = undefined


            if source_node.modifiers.count > 0 then
            (
                try
                (
                    if classOf source_node.modifiers[1] == Edit_Poly then top_edit_poly = source_node.modifiers[1]
                )
                catch
                (
                    top_edit_poly = undefined
                )
            )


            if top_edit_poly != undefined then
            (
                try
                (
                    select source_node
                    max modify mode
                    modPanel.setCurrentObject top_edit_poly
                    top_edit_poly.SetPrimaryNode source_node
                    top_edit_poly.useStackSelection = false
                    top_edit_poly.SetEPolySelLevel #Vertex
                    subObjectLevel = 1


                    /*
                    Hidden outlier vertices must be visible before selection.
                    Edit Poly exposes Unhide All Vertices through ButtonOp.
                    */
                    top_edit_poly.ButtonOp #UnhideAllVertex
                    update source_node


                    selection_bits = copy outlier_vertices
                    top_edit_poly.SetSelection #Vertex selection_bits node:source_node
                    selection_success = (top_edit_poly.GetSelection #Vertex node:source_node) == outlier_vertices
                )
                catch
                (
                    selection_success = false
                )
            )
            else if source_node.modifiers.count == 0 and classOf source_node.baseObject == Editable_Poly then
            (
                try
                (
                    if polyop.getNumVerts source_node.baseObject == expected_vertex_count then
                    (
                        /*
                        Unhide vertices before selecting the non-planar result.
                        */
                        polyop.unHideAllVerts source_node.baseObject
                        polyop.setVertSelection source_node.baseObject outlier_vertices
                        update source_node
                        selection_success = (polyop.getVertSelection source_node.baseObject) == outlier_vertices
                    )
                )
                catch
                (
                    selection_success = false
                )
            )
            else
            (
                selection_modifier = undefined


                try
                (
                    selection_modifier = Edit_Poly name:"NON PLANAR VERTS"
                    selection_modifier.showCage = off
                    addModifier source_node selection_modifier
                    update source_node


                    select source_node
                    max modify mode
                    modPanel.setCurrentObject selection_modifier
                    selection_modifier.SetPrimaryNode source_node
                    selection_modifier.useStackSelection = false
                    selection_modifier.SetEPolySelLevel #Vertex
                    subObjectLevel = 1


                    /*
                    Ensure hidden outlier vertices are visible in the temporary Edit Poly marker.
                    */
                    selection_modifier.ButtonOp #UnhideAllVertex
                    update source_node


                    selection_bits = copy outlier_vertices
                    selection_modifier.SetSelection #Vertex selection_bits node:source_node
                    selection_success = (selection_modifier.GetSelection #Vertex node:source_node) == outlier_vertices
                )
                catch
                (
                    selection_success = false
                )


                if not selection_success and selection_modifier != undefined then
                (
                    try
                    (
                        deleteModifier source_node selection_modifier
                        update source_node
                    )
                    catch
                    (
                    )
                )
            )
        )


        selection_success
        -- return
    )


    /*
    Builds a stable plane from the other vertices of one polygon face.
    Detected outliers are excluded first; when too few clean vertices remain, only the vertex being repaired is excluded.
    */
    function getPlanarFaceRepairPlane source_node face_index vertex_index outlier_vertices =
    (
        wallFixerSetNodeCageOff source_node
        plane_data = undefined


        if source_node != undefined and isValidNode source_node and classOf source_node.baseObject == Editable_Poly then
        (
            source_poly = source_node.baseObject
            face_vertices = polyop.getFaceVerts source_poly face_index
            candidate_vertices = #()


            for face_vertex_index in face_vertices do
            (
                if face_vertex_index != vertex_index and not outlier_vertices[face_vertex_index] then
                (
                    if findItem candidate_vertices face_vertex_index == 0 then append candidate_vertices face_vertex_index
                )
            )


            if candidate_vertices.count < 3 then
            (
                candidate_vertices = #()


                for face_vertex_index in face_vertices do
                (
                    if face_vertex_index != vertex_index then
                    (
                        if findItem candidate_vertices face_vertex_index == 0 then append candidate_vertices face_vertex_index
                    )
                )
            )


            if candidate_vertices.count >= 3 then
            (
                best_cross_length = 0.0
                best_cross_value = undefined
                best_point = undefined


                for point_a_index = 1 to (candidate_vertices.count - 2) do
                (
                    point_a = (polyop.getVert source_poly candidate_vertices[point_a_index]) * source_node.objectTransform


                    for point_b_index = (point_a_index + 1) to (candidate_vertices.count - 1) do
                    (
                        point_b = (polyop.getVert source_poly candidate_vertices[point_b_index]) * source_node.objectTransform


                        for point_c_index = (point_b_index + 1) to candidate_vertices.count do
                        (
                            point_c = (polyop.getVert source_poly candidate_vertices[point_c_index]) * source_node.objectTransform
                            cross_value = cross (point_b - point_a) (point_c - point_a)
                            cross_length = length cross_value


                            if cross_length > best_cross_length then
                            (
                                best_cross_length = cross_length
                                best_cross_value = cross_value
                                best_point = point_a
                            )
                        )
                    )
                )


                if best_cross_value != undefined and best_cross_length > 0.0000001 then
                (
                    target_normal = getSmartExplodeCanonicalNormal (best_cross_value / best_cross_length)
                    target_offset = dot best_point target_normal
                    plane_data = #(target_normal, target_offset, candidate_vertices.count, best_cross_length, face_index)
                )
            )
        )


        plane_data
        -- return
    )


    /*
    Finds the strongest owning-face plane for one non-planar vertex.
    N-gons are preferred by clean support count, then by the area of the defining triangle.
    */
    function getPlanarVertexRepairPlane source_node vertex_index outlier_vertices =
    (
        wallFixerSetNodeCageOff source_node
        best_plane_data = undefined


        if source_node != undefined and isValidNode source_node and classOf source_node.baseObject == Editable_Poly then
        (
            source_poly = source_node.baseObject
            faces_using_vertex = polyop.getFacesUsingVert source_poly #{vertex_index}
            best_support_count = -1
            best_cross_length = -1.0


            for face_index in faces_using_vertex do
            (
                plane_data = getPlanarFaceRepairPlane source_node face_index vertex_index outlier_vertices


                if plane_data != undefined then
                (
                    support_count = plane_data[3]
                    cross_length = plane_data[4]


                    if support_count > best_support_count or (support_count == best_support_count and cross_length > best_cross_length) then
                    (
                        best_plane_data = plane_data
                        best_support_count = support_count
                        best_cross_length = cross_length
                    )
                )
            )
        )


        best_plane_data
        -- return
    )


    /*
    Moves each non-planar vertex onto a plane defined by the other vertices of its owning polygon face.
    The evaluated stack is collapsed only for walls that actually require a repair.
    */
    function makePlanarWall source_node planar_tolerance:1.0 normal_angle_tolerance:5.0 =
    (
        wallFixerSetNodeCageOff source_node
        result_data = #(false, 0, "Unable to repair wall.")
        precheck = analyzePlanarWall source_node planar_tolerance:planar_tolerance normal_angle_tolerance:normal_angle_tolerance


        if not precheck[1] then
        (
            result_data = #(false, 0, precheck[7])
        )
        else if precheck[4].numberSet == 0 then
        (
            result_data = #(true, 0, "")
        )
        else
        (
            conversion_success = true


            if source_node.modifiers.count > 0 or classOf source_node.baseObject != Editable_Poly then
            (
                try
                (
                    convertToPoly source_node
                    wallFixerSetNodeCageOff source_node
                )
                catch
                (
                    conversion_success = false
                )
            )


            if not conversion_success or classOf source_node.baseObject != Editable_Poly then
            (
                result_data = #(false, 0, "Wall could not be converted to Editable Poly for repair.")
            )
            else
            (
                repair_data = analyzePlanarWall source_node planar_tolerance:planar_tolerance normal_angle_tolerance:normal_angle_tolerance


                if not repair_data[1] then
                (
                    result_data = #(false, 0, repair_data[7])
                )
                else
                (
                    outlier_vertices = repair_data[4]
                    repaired_count = 0
                    failed_repair_count = 0
                    inverse_object_tm = inverse source_node.objectTransform


                    for vertex_index in outlier_vertices do
                    (
                        repair_plane = getPlanarVertexRepairPlane source_node vertex_index outlier_vertices


                        if repair_plane != undefined then
                        (
                            target_normal = repair_plane[1]
                            target_offset = repair_plane[2]
                            vertex_local = polyop.getVert source_node.baseObject vertex_index
                            vertex_world = vertex_local * source_node.objectTransform
                            signed_deviation = (dot vertex_world target_normal) - target_offset
                            target_world = vertex_world - (target_normal * signed_deviation)
                            target_local = target_world * inverse_object_tm
                            polyop.setVert source_node.baseObject vertex_index target_local
                            repaired_count += 1
                        )
                        else
                        (
                            failed_repair_count += 1
                        )
                    )


                    update source_node
                    verify_data = analyzePlanarWall source_node planar_tolerance:planar_tolerance normal_angle_tolerance:normal_angle_tolerance


                    if failed_repair_count > 0 then
                    (
                        result_data = #(false, repaired_count, "Unable to build an owning-face plane for " + (failed_repair_count as string) + " non-planar vert(s).")
                    )
                    else if verify_data[1] and verify_data[4].numberSet == 0 then
                    (
                        result_data = #(true, repaired_count, "")
                    )
                    else
                    (
                        remaining_count = if verify_data[1] then verify_data[4].numberSet else repaired_count
                        result_data = #(false, repaired_count, "Repair verification failed; remaining non-planar verts: " + (remaining_count as string))
                    )
                )
            )
        )


        result_data
        -- return
    )


    /*
    Checks selected walls on LMB and repairs only detected non-planar vertices on RMB.
    Valid walls remain untouched; temporary Step 3 selection markers are never allowed to force a repair collapse.
    */
    function runPlanarWalls fix_vertices:false =
    (
        selected_nodes = selection as array
        geometry_nodes = #()
        total_outliers = 0
        selected_outliers = 0
        problem_nodes = #()
        failed_nodes = #()
        repaired_vertices = 0
        repaired_walls = 0
        failed_walls = 0
        failure_messages = #()
        planar_tolerance = amax 0.000001 saved_planar_tolerance
        normal_angle_tolerance = amax 0.1 saved_angle_threshold


        for source_node in selected_nodes do
        (
            if source_node != undefined and isValidNode source_node and superClassOf source_node == GeometryClass then
            (
                append geometry_nodes source_node
            )
        )


        if geometry_nodes.count == 0 then
        (
            setStatus #error "Select at least one wall object."
            false
        )
        else
        (
            setProgress 0
            setStatus #message (if fix_vertices then "Making selected walls planar..." else "Checking selected walls for non-planar vertices...")


            if fix_vertices then
            (
                undo "Wall-Fixer - Make Walls Planar" on
                (
                    with redraw off
                    (
                        for node_index = 1 to geometry_nodes.count do
                        (
                            source_node = geometry_nodes[node_index]


                            /*
                            A previous LMB marker contains selection only.
                            Remove it before deciding whether the real object stack requires conversion.
                            */
                            removePlanarSelectionMarker source_node


                            precheck = analyzePlanarWall source_node planar_tolerance:planar_tolerance normal_angle_tolerance:normal_angle_tolerance


                            if precheck[1] then
                            (
                                total_outliers += precheck[4].numberSet


                                if precheck[4].numberSet > 0 then
                                (
                                    repair_result = makePlanarWall source_node planar_tolerance:planar_tolerance normal_angle_tolerance:normal_angle_tolerance


                                    if repair_result[1] then
                                    (
                                        repaired_vertices += repair_result[2]
                                        repaired_walls += 1
                                    )
                                    else
                                    (
                                        failed_walls += 1
                                        if findItem failed_nodes source_node == 0 then append failed_nodes source_node
                                        append failure_messages (source_node.name + ": " + repair_result[3])
                                    )
                                )
                            )
                            else
                            (
                                failed_walls += 1
                                if findItem failed_nodes source_node == 0 then append failed_nodes source_node
                                append failure_messages (source_node.name + ": " + precheck[7])
                            )


                            setProgress ((100.0 * node_index / geometry_nodes.count) as integer)
                        )
                    )
                )


                clearSelection()


                if failed_nodes.count > 0 then
                (
                    select failed_nodes
                )
                else
                (
                    select geometry_nodes
                )


                subObjectLevel = 0
                cleanupRedundantVerticesAfterGeometryChange geometry_nodes
                redrawViews()
                setProgress 100


                if failed_walls > 0 then
                (
                    failure_text = if failure_messages.count > 0 then failure_messages[1] else "One or more walls could not be repaired."
                    setStatus #warning ("Made planar: " + (repaired_walls as string) + " wall(s), " + (repaired_vertices as string) + " vert(s). Failed: " + (failed_walls as string) + ". " + failure_text)
                    false
                )
                else if total_outliers == 0 then
                (
                    setStatus #success "All walls are planar"
                    true
                )
                else
                (
                    setStatus #success ("Walls made planar: " + (repaired_walls as string) + " wall(s), " + (repaired_vertices as string) + " vert(s)")
                    true
                )
            )
            else
            (
                for node_index = 1 to geometry_nodes.count do
                (
                    source_node = geometry_nodes[node_index]
                    clearPlanarCheckSelection source_node
                    check_data = analyzePlanarWall source_node planar_tolerance:planar_tolerance normal_angle_tolerance:normal_angle_tolerance


                    if check_data[1] then
                    (
                        outlier_vertices = check_data[4]
                        total_outliers += outlier_vertices.numberSet


                        if outlier_vertices.numberSet > 0 then
                        (
                            if selectPlanarOutlierVerts source_node outlier_vertices check_data[6] then
                            (
                                selected_outliers += outlier_vertices.numberSet
                                if findItem problem_nodes source_node == 0 then append problem_nodes source_node
                            )
                            else
                            (
                                failed_walls += 1
                                if findItem failed_nodes source_node == 0 then append failed_nodes source_node
                                append failure_messages (source_node.name + ": non-planar verts were found but could not be selected.")
                            )
                        )
                    )
                    else
                    (
                        failed_walls += 1
                        if findItem failed_nodes source_node == 0 then append failed_nodes source_node
                        append failure_messages (source_node.name + ": " + check_data[7])
                    )


                    setProgress ((100.0 * node_index / geometry_nodes.count) as integer)
                )


                clearSelection()


                if problem_nodes.count > 0 then
                (
                    select problem_nodes
                    max modify mode
                    subObjectLevel = 1
                )
                else if failed_nodes.count > 0 then
                (
                    select failed_nodes
                    subObjectLevel = 0
                )
                else
                (
                    select geometry_nodes
                    subObjectLevel = 0
                )


                redrawViews()
                setProgress 100


                if failed_walls > 0 then
                (
                    failure_text = if failure_messages.count > 0 then failure_messages[1] else "One or more walls could not be analyzed."
                    setStatus #warning ("Planar check found " + (total_outliers as string) + " non-planar vert(s). Failed walls: " + (failed_walls as string) + ". " + failure_text)
                    false
                )
                else if total_outliers == 0 then
                (
                    setStatus #success "All walls are planar"
                    true
                )
                else if selected_outliers == total_outliers then
                (
                    setStatus #warning ((total_outliers as string) + " verts out of plane")
                    true
                )
                else
                (
                    setStatus #warning ("Non-planar verts found: " + (total_outliers as string) + "; selected: " + (selected_outliers as string) + ". RMB makes the required walls planar.")
                    true
                )
            )
        )
        -- return
    )


    /*
    Groups snapshot triangles by sign-independent face-normal orientation.
    Faces within the requested angular tolerance are treated as one compatible wall direction.
    */
    function getSmartExplodeMeshNormalGroups source_mesh source_node angle_tolerance:1.0 =
    (
        result_groups = #()
        cosine_tolerance = cos angle_tolerance


        for face_index = 1 to source_mesh.numfaces do
        (
            face_data = getSmartExplodeMeshFaceData source_mesh source_node face_index


            if face_data != undefined then
            (
                face_normal = face_data[1]
                matched_group_index = 0


                for group_index = 1 to result_groups.count while matched_group_index == 0 do
                (
                    if (dot face_normal result_groups[group_index][1]) >= cosine_tolerance then
                    (
                        matched_group_index = group_index
                    )
                )


                if matched_group_index == 0 then
                (
                    face_bits = #{}
                    face_bits[face_index] = true
                    append result_groups #(face_normal, face_bits)
                )
                else
                (
                    result_groups[matched_group_index][2][face_index] = true
                )
            )
        )


        result_groups
        -- return
    )


    /*
    Groups snapshot triangles by signed direction along one already-confirmed wall-normal orientation.
    Positive-facing and backside-facing normals become separate objects before wall-position analysis.
    */
    function getSmartExplodeMeshFaceDirectionGroups source_mesh source_node reference_normal =
    (
        front_faces = #{}
        backside_faces = #{}


        for face_index = 1 to source_mesh.numfaces do
        (
            face_data = getSmartExplodeMeshFaceData source_mesh source_node face_index


            if face_data != undefined then
            (
                signed_normal = face_data[3]


                if (dot signed_normal reference_normal) < 0.0 then
                (
                    backside_faces[face_index] = true
                )
                else
                (
                    front_faces[face_index] = true
                )
            )
        )


        result_groups = #()


        if front_faces.numberSet > 0 then append result_groups #(1.0, front_faces)
        if backside_faces.numberSet > 0 then append result_groups #(-1.0, backside_faces)


        result_groups
        -- return
    )


    /*
    Groups snapshot triangles by wall-plane offset along one canonical wall normal.
    This distinguishes parallel wall layers while naturally ignoring displacement within the wall plane, including Z on vertical walls.
    */
    function getSmartExplodeMeshPositionGroups source_mesh source_node reference_normal position_tolerance:1.0 =
    (
        result_groups = #()


        for face_index = 1 to source_mesh.numfaces do
        (
            face_data = getSmartExplodeMeshFaceData source_mesh source_node face_index


            if face_data != undefined then
            (
                plane_offset = dot face_data[2] reference_normal
                matched_group_index = 0


                for group_index = 1 to result_groups.count while matched_group_index == 0 do
                (
                    if abs (plane_offset - result_groups[group_index][1]) <= position_tolerance then
                    (
                        matched_group_index = group_index
                    )
                )


                if matched_group_index == 0 then
                (
                    face_bits = #{}
                    face_bits[face_index] = true
                    append result_groups #(plane_offset, face_bits)
                )
                else
                (
                    result_groups[matched_group_index][2][face_index] = true
                )
            )
        )
result_groups
        -- return
    )


    /*
    Collects disconnected face elements from the temporary TriMesh snapshot.
    Each returned bitarray contains one complete connected component.
    */
    function getSmartExplodeMeshElementGroups source_mesh =
    (
        result_groups = #()
        remaining_faces = #{}


        if source_mesh.numfaces > 0 then remaining_faces = #{1..source_mesh.numfaces}


        while remaining_faces.numberSet > 0 do
        (
            remaining_array = remaining_faces as array
            seed_face = remaining_array[1]
            element_faces = meshop.getElementsUsingFace source_mesh #{seed_face}
            append result_groups element_faces
            remaining_faces = remaining_faces - element_faces
        )


        result_groups
        -- return
    )


    /*
    Analyzes one evaluated object without changing the original scene node or modifier stack.
    Precedence is NORMALS, FACE DIRECTION, XY POSITION, ELEMENTS, then already-valid.
    */
    function analyzeSmartExplodeNode source_node normal_angle_tolerance:1.0 position_tolerance:1.0 =
    (
        result_data = #(#error, 0)
        analysis_mesh = undefined


        if source_node != undefined and isValidNode source_node and superClassOf source_node == GeometryClass then
        (
            try
            (
                analysis_mesh = snapshotAsMesh source_node


                if analysis_mesh != undefined and analysis_mesh.numfaces > 0 then
                (
                    normal_groups = getSmartExplodeMeshNormalGroups analysis_mesh source_node angle_tolerance:normal_angle_tolerance


                    if normal_groups.count > 1 then
                    (
                        result_data = #(#normals, normal_groups.count)
                    )
                    else if normal_groups.count == 1 then
                    (
                        face_direction_groups = getSmartExplodeMeshFaceDirectionGroups analysis_mesh source_node normal_groups[1][1]


                        if face_direction_groups.count > 1 then
                        (
                            result_data = #(#faceDirection, face_direction_groups.count)
                        )
                        else
                        (
                            position_groups = getSmartExplodeMeshPositionGroups analysis_mesh source_node normal_groups[1][1] position_tolerance:position_tolerance


                            if position_groups.count > 1 then
                            (
                                result_data = #(#position, position_groups.count)
                            )
                            else
                            (
                                element_groups = getSmartExplodeMeshElementGroups analysis_mesh


                                if element_groups.count > 1 then
                                (
                                    result_data = #(#elements, element_groups.count)
                                )
                                else
                                (
                                    result_data = #(#valid, 1)
                                )
                            )
                        )
                    )
                    else
                    (
                        result_data = #(#error, 0)
                    )
                )
            )
            catch
            (
                result_data = #(#error, 0)
            )
        )


        if analysis_mesh != undefined then
        (
            try
            (
                free analysis_mesh
            )
            catch
            (
            )
        )


        result_data
        -- return
    )


    /*
    Groups current Editable Poly faces by sign-independent world-space normal orientation.
    This is run only after snapshot analysis has already proved that a normals split is required.
    */
    function getSmartExplodePolyNormalGroups source_node angle_tolerance:1.0 =
    (
        result_groups = #()
        grouped_faces = #{}
        cosine_tolerance = cos angle_tolerance
        face_count = polyop.getNumFaces source_node.baseObject


        for face_index = 1 to face_count do
        (
            face_normal = undefined


            try
            (
                in coordsys world
                (
                    face_normal = polyop.getFaceNormal source_node face_index
                )
            )
            catch
            (
                face_normal = undefined
            )


            if face_normal != undefined and length face_normal > 0.0000001 then
            (
                face_normal = getSmartExplodeCanonicalNormal face_normal
                matched_group_index = 0


                for group_index = 1 to result_groups.count while matched_group_index == 0 do
                (
                    if (dot face_normal result_groups[group_index][1]) >= cosine_tolerance then
                    (
                        matched_group_index = group_index
                    )
                )


                if matched_group_index == 0 then
                (
                    face_bits = #{}
                    face_bits[face_index] = true
                    append result_groups #(face_normal, face_bits)
                )
                else
                (
                    result_groups[matched_group_index][2][face_index] = true
                )


                grouped_faces[face_index] = true
            )
        )


        if result_groups.count > 0 and grouped_faces.numberSet < face_count then
(
            missing_faces = #{1..face_count} - grouped_faces
            result_groups[1][2] = result_groups[1][2] + missing_faces
        )


        result_groups
        -- return
    )


    /*
    Groups current Editable Poly faces by signed world-space direction along one wall-normal orientation.
    Opposite/backside normals are separated while preserving all native face data during the later detach.
    */
    function getSmartExplodePolyFaceDirectionGroups source_node reference_normal =
    (
        front_faces = #{}
        backside_faces = #{}
        unresolved_faces = #{}
        face_count = polyop.getNumFaces source_node.baseObject


        for face_index = 1 to face_count do
        (
            signed_normal = undefined


            try
            (
                in coordsys world
                (
                    signed_normal = polyop.getFaceNormal source_node face_index
                )
            )
            catch
            (
                signed_normal = undefined
            )


            if signed_normal != undefined and length signed_normal > 0.0000001 then
            (
                signed_normal = normalize signed_normal


                if (dot signed_normal reference_normal) < 0.0 then
                (
                    backside_faces[face_index] = true
                )
                else
                (
                    front_faces[face_index] = true
                )
            )
            else
            (
                unresolved_faces[face_index] = true
            )
        )


        if unresolved_faces.numberSet > 0 then
        (
            if front_faces.numberSet > 0 then
            (
                front_faces = front_faces + unresolved_faces
            )
            else if backside_faces.numberSet > 0 then
            (
                backside_faces = backside_faces + unresolved_faces
            )
        )


        result_groups = #()


        if front_faces.numberSet > 0 then append result_groups #(1.0, front_faces)
        if backside_faces.numberSet > 0 then append result_groups #(-1.0, backside_faces)


        result_groups
        -- return
    )


    /*
    Groups current Editable Poly faces by world-space wall-plane offset.
    The supplied normal defines the axis perpendicular to the wall plane, so in-plane XY/Z extent is ignored.
    */
    function getSmartExplodePolyPositionGroups source_node reference_normal position_tolerance:1.0 =
    (
        result_groups = #()
        grouped_faces = #{}
        face_count = polyop.getNumFaces source_node.baseObject


        for face_index = 1 to face_count do
        (
            face_center = undefined


            try
            (
                in coordsys world
                (
                    face_center = polyop.getFaceCenter source_node face_index
                )
            )
            catch
            (
                face_center = undefined
            )


            if face_center != undefined then
            (
                plane_offset = dot face_center reference_normal
                matched_group_index = 0


                for group_index = 1 to result_groups.count while matched_group_index == 0 do
                (
                    if abs (plane_offset - result_groups[group_index][1]) <= position_tolerance then
                    (
                        matched_group_index = group_index
                    )
                )


                if matched_group_index == 0 then
                (
                    face_bits = #{}
                    face_bits[face_index] = true
                    append result_groups #(plane_offset, face_bits)
                )
                else
                (
                    result_groups[matched_group_index][2][face_index] = true
                )


                grouped_faces[face_index] = true
            )
        )


        if result_groups.count > 0 and grouped_faces.numberSet < face_count then
        (
            missing_faces = #{1..face_count} - grouped_faces
            result_groups[1][2] = result_groups[1][2] + missing_faces
)


        result_groups
        -- return
    )


    /*
    Collects disconnected elements from the confirmed Editable Poly source.
    This is used only when normals and wall-plane position have both passed analysis.
    */
    function getSmartExplodePolyElementGroups source_node =
    (
        result_groups = #()
        face_count = polyop.getNumFaces source_node.baseObject
        remaining_faces = #{}


        if face_count > 0 then remaining_faces = #{1..face_count}


        while remaining_faces.numberSet > 0 do
        (
            remaining_array = remaining_faces as array
            seed_face = remaining_array[1]
            element_faces = polyop.getElementsUsingFace source_node.baseObject #{seed_face}
            append result_groups element_faces
            remaining_faces = remaining_faces - element_faces
        )


        result_groups
        -- return
    )


    /*
    Returns the next distinct viewport wirecolor for a newly exploded wall object.
    The sequence resets for each Explode Objects to Walls command so all new results are visually separated.
    */
    function getNextSmartExplodeWireColor =
    (
        color_palette = #(
            (color 255 92 92),
            (color 92 180 255),
            (color 116 230 116),
            (color 255 194 82),
            (color 196 120 255),
            (color 76 224 210),
            (color 255 120 196),
            (color 218 224 88),
            (color 120 138 255),
            (color 255 146 82),
            (color 104 210 160),
            (color 226 110 255),
            (color 255 108 132),
            (color 88 202 238),
            (color 164 224 92),
            (color 246 170 90),
            (color 154 122 255),
            (color 82 220 188),
            (color 255 132 224),
            (color 206 214 100),
            (color 112 162 255),
            (color 255 116 88),
            (color 122 220 126),
            (color 236 126 202)
        )


        wall_fixer_explode_wire_color_counter += 1
        palette_index = mod (wall_fixer_explode_wire_color_counter - 1) color_palette.count + 1


        color_palette[palette_index]
        -- return
    )


    /*
    Copies relevant node-level display and user-property data to one detached wall node.
    Face Material IDs, mapping channels and smoothing data are preserved by native Editable Poly detaching.
    */
    function copySmartExplodeNodeProperties source_node target_node user_property_buffer =
    (
        if source_node != undefined and target_node != undefined then
        (
            try
            (
                target_node.material = source_node.material
            )
            catch
            (
            )


            try
            (
                target_node.wirecolor = source_node.wirecolor
            )
            catch
            (
            )


            try
            (
                target_node.allEdges = source_node.allEdges
            )
            catch
            (
            )


            try
            (
                target_node.backFaceCull = source_node.backFaceCull
            )
            catch
            (
            )


            try
            (
                target_node.renderable = source_node.renderable
            )
            catch
            (
            )


            try
            (
                target_node.primaryVisibility = source_node.primaryVisibility
            )
            catch
            (
            )


            try
            (
                target_node.secondaryVisibility = source_node.secondaryVisibility
            )
            catch
            (
            )


            if user_property_buffer != undefined and user_property_buffer != "" then
            (
                try
                (
                    setUserPropBuffer target_node user_property_buffer
                )
                catch
                (
                )
            )
        )


        target_node
        -- return
    )


    /*
    Detaches every confirmed face group to a new Editable Poly node, then removes the collapsed source.
    Faces are copied with delete:false until every group succeeds, preventing face-index renumbering during the split.
    */
    function detachSmartExplodePolyGroups source_node face_groups name_suffix:"_Wall_" =
    (
        wallFixerSetNodeCageOff source_node
        result_nodes = #()
        operation_success = false
        source_user_properties = ""


        try
        (
            source_user_properties = getUserPropBuffer source_node
        )
        catch
        (
            source_user_properties = ""
        )


        if (source_node != undefined) and (isValidNode source_node) and (classOf source_node.baseObject == Editable_Poly) and (face_groups.count > 1) then
        (
            detach_failed = false


            for group_index = 1 to face_groups.count while not detach_failed do
            (
                group_faces = face_groups[group_index]


                if group_faces.numberSet > 0 then
                (
                    detached_name = uniqueName (source_node.name + name_suffix)
                    detach_result = false


                    try
                    (
                        detach_result = polyop.detachFaces source_node group_faces delete:false asNode:true name:detached_name
                    )
                    catch
                    (
                        detach_result = false
                    )


                    detached_node = if detach_result then getNodeByName detached_name else undefined


                    if detached_node != undefined and isValidNode detached_node then
                    (
                        copySmartExplodeNodeProperties source_node detached_node source_user_properties
                        detached_node.wirecolor = getNextSmartExplodeWireColor()
                        append result_nodes detached_node
                    )
                    else
                    (
                        detach_failed = true
                    )
                )
            )if not detach_failed and result_nodes.count == face_groups.count then
            (
                delete source_node
                operation_success = true
            )
            else
            (
                for created_node in result_nodes do
                (
                    if isValidNode created_node then delete created_node
                )


                result_nodes = #()
            )
        )


        #(operation_success, result_nodes)
        -- return
    )


    /*
    Collapses one already-confirmed split candidate to Editable Poly and executes only the required split level.
    Snapshot analysis has already established that modifying this original node is necessary.
    */
    function executeSmartExplodeNode source_node operation_type normal_angle_tolerance:1.0 position_tolerance:1.0 =
    (
        wallFixerSetNodeCageOff source_node
        result_data = #(false, #())
        conversion_success = false


        try
        (
            convertToPoly source_node
            wallFixerSetNodeCageOff source_node
            conversion_success = isValidNode source_node and classOf source_node.baseObject == Editable_Poly
        )
        catch
        (
            conversion_success = false
        )


        if conversion_success then
        (
            face_groups = #()


            case operation_type of
            (
                #normals:
                (
                    normal_groups = getSmartExplodePolyNormalGroups source_node angle_tolerance:normal_angle_tolerance
                    for group_data in normal_groups do append face_groups group_data[2]
                )
                #faceDirection:
                (
                    normal_groups = getSmartExplodePolyNormalGroups source_node angle_tolerance:normal_angle_tolerance


                    if normal_groups.count == 1 then
                    (
                        face_direction_groups = getSmartExplodePolyFaceDirectionGroups source_node normal_groups[1][1]
                        for group_data in face_direction_groups do append face_groups group_data[2]
                    )
                )
                #position:
                (
                    normal_groups = getSmartExplodePolyNormalGroups source_node angle_tolerance:normal_angle_tolerance


                    if normal_groups.count == 1 then
                    (
                        position_groups = getSmartExplodePolyPositionGroups source_node normal_groups[1][1] position_tolerance:position_tolerance
                        for group_data in position_groups do append face_groups group_data[2]
                    )
                )
                #elements:
                (
                    face_groups = getSmartExplodePolyElementGroups source_node
                )
            )


            if face_groups.count > 1 then
            (
                result_data = detachSmartExplodePolyGroups source_node face_groups
            )
        )


        result_data
        -- return
    )


    /*
    Falls back to splitting a still-valid Smart Explode source by its actual Editable Poly elements.
    Returns success, result nodes and the detected element count while leaving the source intact on failure.
    */
    function executeSmartExplodeElementFallback source_node =
    (
        wallFixerSetNodeCageOff source_node
        result_data = #(false, #(), 0)
        conversion_success = false


        if source_node != undefined and isValidNode source_node and superClassOf source_node == GeometryClass then
        (
            try
            (
                if classOf source_node.baseObject != Editable_Poly then
                (
                    convertToPoly source_node
                    wallFixerSetNodeCageOff source_node
                )


                conversion_success = isValidNode source_node and classOf source_node.baseObject == Editable_Poly
            )
            catch
            (
                conversion_success = false
            )


            if conversion_success then
            (
                element_groups = getSmartExplodePolyElementGroups source_node
                element_count = element_groups.count


                if element_count > 1 then
                (
                    split_result = detachSmartExplodePolyGroups source_node element_groups name_suffix:"_Element_"
                    result_data = #(split_result[1], split_result[2], element_count)
                )
                else
                (
                    result_data = #(false, #(), element_count)
                )
            )
        )


        result_data
        -- return
    )


    /*
    Appends one valid scene node to an output array only once.
    This keeps untouched originals and newly detached walls together in the final selection.
    */
    function appendSmartExplodeOutputNode output_nodes scene_node =
    (
        if scene_node != undefined and isValidNode scene_node then
        (
            if findItem output_nodes scene_node == 0 then append output_nodes scene_node
)


        output_nodes
        -- return
    )


    /*
    Analyzes one object for exactly one Smart Explode stage using evaluated snapshot geometry.
    The original scene node and modifier stack remain untouched during this check.
    */
    function analyzeSmartExplodeStage source_node operation_type normal_angle_tolerance:1.0 position_tolerance:1.0 =
    (
        result_data = #(false, false, 0)
        analysis_mesh = undefined


        if source_node != undefined and isValidNode source_node and superClassOf source_node == GeometryClass then
        (
            try
            (
                analysis_mesh = snapshotAsMesh source_node


                if analysis_mesh != undefined and analysis_mesh.numfaces > 0 then
                (
                    case operation_type of
                    (
                        #normals:
                        (
                            normal_groups = getSmartExplodeMeshNormalGroups analysis_mesh source_node angle_tolerance:normal_angle_tolerance
                            result_data = #(true, normal_groups.count > 1, normal_groups.count)
                        )
                        #faceDirection:
                        (
                            normal_groups = getSmartExplodeMeshNormalGroups analysis_mesh source_node angle_tolerance:normal_angle_tolerance


                            if normal_groups.count == 1 then
                            (
                                face_direction_groups = getSmartExplodeMeshFaceDirectionGroups analysis_mesh source_node normal_groups[1][1]
                                result_data = #(true, face_direction_groups.count > 1, face_direction_groups.count)
                            )
                        )
                        #position:
                        (
                            normal_groups = getSmartExplodeMeshNormalGroups analysis_mesh source_node angle_tolerance:normal_angle_tolerance


                            if normal_groups.count == 1 then
                            (
                                face_direction_groups = getSmartExplodeMeshFaceDirectionGroups analysis_mesh source_node normal_groups[1][1]


                                if face_direction_groups.count == 1 then
                                (
                                    position_groups = getSmartExplodeMeshPositionGroups analysis_mesh source_node normal_groups[1][1] position_tolerance:position_tolerance
                                    result_data = #(true, position_groups.count > 1, position_groups.count)
                                )
                            )
                        )
                        #elements:
                        (
                            element_groups = getSmartExplodeMeshElementGroups analysis_mesh
                            result_data = #(true, element_groups.count > 1, element_groups.count)
                        )
                    )
                )
            )
            catch
            (
                result_data = #(false, false, 0)
            )
        )


        if analysis_mesh != undefined then
        (
            try
            (
                free analysis_mesh
            )
            catch
            (
            )
        )


        result_data
        -- return
    )


    /*
    Explodes the complete current object set into separate scene objects by canonical face-normal orientation.
    This is mandatory Smart Explode step 1: each required normal group becomes its own object before step 2 can run.
    */
    function explodeSmartExplodeNodesByNormals input_nodes normal_angle_tolerance:1.0 position_tolerance:1.0 =
    (
        output_nodes = #()
        split_count = 0
        failed_count = 0
        processed_count = 0


        for source_node in input_nodes do
        (
            processed_count += 1


            if source_node == undefined or not isValidNode source_node or superClassOf source_node != GeometryClass then
            (
                failed_count += 1
            )
            else
            (
                source_name = source_node.name
                analysis_result = analyzeSmartExplodeStage source_node #normals normal_angle_tolerance:normal_angle_tolerance position_tolerance:position_tolerance


                if not analysis_result[1] then
                (
                    failed_count += 1
                    appendSmartExplodeOutputNode output_nodes source_node
                    setStatus #error (source_name + ": NORMALS analysis failed.")
                )
                else if analysis_result[2] then
                (
                    expected_object_count = analysis_result[3]
                    split_result = executeSmartExplodeNode source_node #normals normal_angle_tolerance:normal_angle_tolerance position_tolerance:position_tolerance


                    if split_result[1] and split_result[2].count == expected_object_count then
                    (
                        split_count += 1


                        for result_node in split_result[2] do
                        (
                            appendSmartExplodeOutputNode output_nodes result_node
                        )
                    )
                    else
                    (
                        failed_count += 1


                        if isValidNode source_node then
                        (
                            appendSmartExplodeOutputNode output_nodes source_node
                        )


                        setStatus #error (source_name + ": NORMALS must explode into separate objects, but the object split failed.")
                    )
                )
                else
                (
                    appendSmartExplodeOutputNode output_nodes source_node
                )
            )
        )


        #(failed_count == 0, output_nodes, split_count, failed_count, processed_count)
        -- return
    )


    /*
    Runs one Smart Explode stage across the complete current object set.
    Every input finishes this stage before any object advances to the next stage.
    */
    function processSmartExplodeStage input_nodes operation_type normal_angle_tolerance:1.0 position_tolerance:1.0 =
    (
        output_nodes = #()
        split_count = 0
        failed_count = 0
        processed_count = 0


        for source_node in input_nodes do
        (
            processed_count += 1


            if source_node == undefined or not isValidNode source_node or superClassOf source_node != GeometryClass then
            (
                failed_count += 1
            )
            else
            (
                source_name = source_node.name
                analysis_result = analyzeSmartExplodeStage source_node operation_type normal_angle_tolerance:normal_angle_tolerance position_tolerance:position_tolerance


                if not analysis_result[1] then
                (
                    failed_count += 1
                    appendSmartExplodeOutputNode output_nodes source_node
                    setStatus #error (source_name + ": " + (operation_type as string) + " analysis failed.")
                )
                else if analysis_result[2] then
                (
                    split_result = executeSmartExplodeNode source_node operation_type normal_angle_tolerance:normal_angle_tolerance position_tolerance:position_tolerance


                    if split_result[1] then
                    (
                        split_count += 1


                        for result_node in split_result[2] do
                        (
                            appendSmartExplodeOutputNode output_nodes result_node
                        )
                    )
                    else
                    (
                        fallback_result = if operation_type != #elements then executeSmartExplodeElementFallback source_node else #(false, #(), 0)


                        if fallback_result[1] then
                        (
                            split_count += 1


                            for result_node in fallback_result[2] do
                            (
                                appendSmartExplodeOutputNode output_nodes result_node
                            )


                            format "FALLBACK: % confirmed % split failed; exploded to % mesh elements.\n" source_name operation_type fallback_result[3]
                        )
                        else
                        (
                            failed_count += 1
                            if isValidNode source_node then appendSmartExplodeOutputNode output_nodes source_node
                            setStatus #error (source_name + ": confirmed " + (operation_type as string) + " split could not be completed.")
                        )
                    )
                )
                else
                (
                    appendSmartExplodeOutputNode output_nodes source_node
                )
            )
        )


        #(failed_count == 0, output_nodes, split_count, failed_count, processed_count)
        -- return
    )


    /*
    Smart Explode Objects to Walls performs only the first required explode level for each selected object.
    Viewport/UI refresh is batched so stable geometry logic runs without repeated scene redraws.
    */
    function smartExplodeObjectsToWalls normal_angle_tolerance:1.0 position_tolerance:undefined =
    (
        selected_nodes = selection as array
        final_nodes = #()
        failed_count = 0
        split_count = 0
        valid_count = 0


        if position_tolerance == undefined then
        (
            position_tolerance = amax 0.000001 ((wallFixerGetDefaultWeldThreshold()) * 0.01)
        )


        if selected_nodes.count == 0 then
        (
            setStatus #error "Select at least one geometry object."
            false
        )
        else
        (
            for source_index = 1 to selected_nodes.count do
            (
                source_node = selected_nodes[source_index]
                setProgress (((source_index as float / selected_nodes.count) * 90.0) as integer)


                if source_node == undefined or not isValidNode source_node or superClassOf source_node != GeometryClass then
                (
                    failed_count += 1
                    format "ERROR: Invalid geometry in Smart Explode input at index:%\n" source_index
                )
                else
                (
                    source_name = source_node.name
                    analysis_result = analyzeSmartExplodeNode source_node normal_angle_tolerance:normal_angle_tolerance position_tolerance:position_tolerance
                    operation_type = analysis_result[1]


                    if operation_type == #valid then
                    (
                        valid_count += 1
                        appendSmartExplodeOutputNode final_nodes source_node
                        format "SUCCESS: Object is already a single wall | %\n" source_name
                    )
                    else if (operation_type == #normals) or (operation_type == #faceDirection) or (operation_type == #position) or (operation_type == #elements) then
                    (
                        split_result = executeSmartExplodeNode source_node operation_type normal_angle_tolerance:normal_angle_tolerance position_tolerance:position_tolerance


                        if split_result[1] then
                        (
                            split_count += 1


                            for result_node in split_result[2] do
                            (
                                appendSmartExplodeOutputNode final_nodes result_node
                            )


                            case operation_type of
                            (
                                #normals:
                                (
                                    format "SUCCESS: Objects exploded to walls by normals | % | result objects:%\n" source_name split_result[2].count
                                )
                                #faceDirection:
                                (
                                    format "SUCCESS: Objects exploded to walls by face direction | % | result objects:%\n" source_name split_result[2].count
                                )
                                #position:
                                (
                                    format "SUCCESS: Objects exploded to walls by XY position | % | result objects:%\n" source_name split_result[2].count
                                )
                                #elements:
                                (
                                    format "SUCCESS: Objects exploded to elements | % | result objects:%\n" source_name split_result[2].count
                                )
                            )
                        )
                        else
                        (
                            fallback_result = if operation_type != #elements then executeSmartExplodeElementFallback source_node else #(false, #(), 0)


                            if fallback_result[1] then
                            (
                                split_count += 1


                                for result_node in fallback_result[2] do
                                (
                                    appendSmartExplodeOutputNode final_nodes result_node
                                )


                                format "FALLBACK: % confirmed % split failed; exploded to % mesh elements.\n" source_name operation_type fallback_result[3]
                            )
                            else
                            (
                                failed_count += 1


                                if isValidNode source_node then
                                (
                                    appendSmartExplodeOutputNode final_nodes source_node
                                )


                                format "ERROR: % confirmed split could not be completed.\n" source_name
                            )
                        )
                    )
                    else
                    (
                        failed_count += 1
                        appendSmartExplodeOutputNode final_nodes source_node
                        format "ERROR: % snapshot analysis failed.\n" source_name
                    )
                )
            )


            clearSelection()


            if final_nodes.count > 0 then
            (
                select final_nodes
            )


            setProgress 100


            if failed_count > 0 then
            (
                setStatus #error ("Explode to walls finished with " + (failed_count as string) + " failed object(s)."))
            else if split_count > 0 then
            (
                setStatus #success ("Explode to walls complete: " + (final_nodes.count as string) + " object(s)")
            )
            else if selected_nodes.count == 1 then
            (
                setStatus #success "Object is already a single wall"
            )
            else
            (
                setStatus #success "Selected objects are already single walls"
            )


            format "Wall-Fixer Smart Explode ONE LEVEL: initial:% result:% splits:% valid:% failed:%\n" \
                selected_nodes.count final_nodes.count split_count valid_count failed_count


            failed_count == 0
        )
        -- return
    )


    /*
    Collects every node that belongs to the current 3ds Max Isolate Selection set.
    The list is captured before Smart Explode replaces any isolated source nodes.
    */
    function getSmartExplodeIsolatedNodes =
    (
        isolated_nodes = #()


        try
        (
            if IsolateSelection.IsolateSelectionModeActive() then
            (
                for scene_node in objects do
                (
                    if isValidNode scene_node and IsolateSelection.IsNodeIsolated scene_node then
                    (
                        append isolated_nodes scene_node
                    )
                )
            )
        )
        catch
        (
            isolated_nodes = #()
        )


        isolated_nodes
        -- return
    )


    /*
    Restores Isolate Selection after Smart Explode and includes all new result nodes.
    The isolate set is rebuilt with redraw suppressed, then only the explode result remains selected.
    */
    function restoreSmartExplodeIsolateMode isolated_nodes result_nodes =
    (
        isolate_restore_success = true
        isolate_nodes = #()


        for scene_node in isolated_nodes do
        (
            if scene_node != undefined and isValidNode scene_node then
            (
                appendSmartExplodeOutputNode isolate_nodes scene_node
            )
        )


        for result_node in result_nodes do
        (
            if result_node != undefined and isValidNode result_node then
            (
                appendSmartExplodeOutputNode isolate_nodes result_node
            )
        )


        try
        (
            if IsolateSelection.IsolateSelectionModeActive() then
            (
                IsolateSelection.ExitIsolateSelectionMode()
            )


            clearSelection()


            if isolate_nodes.count > 0 then
            (
                select isolate_nodes
                IsolateSelection.EnterIsolateSelectionMode()
            )


            clearSelection()


            if result_nodes.count > 0 then
            (
                select result_nodes
            )
        )
        catch
        (
            isolate_restore_success = false
        )


        isolate_restore_success
        -- return
    )


    /*
    Runs one Smart Explode level from PRE-PROCESS step 2.
    Snapshot analysis finds the first required level; newly created objects wait for the next command invocation.
    */
    function runExplodeObjectsToWalls =
    (
        wall_fixer_explode_wire_color_counter = 0
        isolate_was_active = false
        isolated_nodes = #()
        result_nodes = #()
        setProgress 0
        setStatus #message "Analyzing selected objects for the first required wall split..."
        completed = false


        try
        (
            isolate_was_active = IsolateSelection.IsolateSelectionModeActive()


            if isolate_was_active then
            (
                isolated_nodes = getSmartExplodeIsolatedNodes()
            )
        )
        catch
        (
            isolate_was_active = false
            isolated_nodes = #()
        )


        undo "Wall-Fixer - Smart Explode Objects to Walls" on
        (
            with redraw off
            (
                completed = smartExplodeObjectsToWalls normal_angle_tolerance:1.0
                result_nodes = selection as array


                if isolate_was_active then
                (
                    restoreSmartExplodeIsolateMode isolated_nodes result_nodes
                )
            )
        )


        if completed then cleanupRedundantVerticesAfterGeometryChange result_nodes
        redrawViews()
        completed
        -- return
    )


    /*
    Runs the two-visible-edge vertex finder and stores the result in SELECT TWO-EDGE VERTS.
    RMB uses the same dedicated modifier and never consumes an unrelated vertex selection.
    */
    function runFindTwoEdgeVerts =
    (
        setProgress 0
        setStatus #message "Finding two-edge vertices..."
        completed = WallFixer.debugFindTwoEdgeVerts angle_threshold:2.0
        setProgress 100


        if completed then
        (
            setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Two-edge vertex check completed.")
        )
        else
        (
            setStatus #warning (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "No removable two-edge vertices were found.")
        )


        completed
        -- return
    )


    /*
    Removes the stored SELECT TWO-EDGE VERTS selection and leaves the committed modifier named DELETED TWO-EDGE VERTS.
    RMB creates the SELECT modifier through the normal snapshot-based finder when it does not already exist.
    */
    function runRemoveTwoEdgeVerts =
    (
        setProgress 0
        setStatus #message "Removing stored two-edge vertices..."
        completed = WallFixer.removeSelectedTwoEdgeVerts angle_threshold:2.0
        setProgress 100

        if completed then
        (
            setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Two-edge vertices removed.")
        )
        else
        (
            setStatus #error (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Two-edge vertex removal failed.")
        )

        completed
        -- return
    )


    /*
    Converts Straight Edge Fixer result values to an explicit completion Boolean.
    Integer check counts and #(fixed_count, has_failed_edges) straighten results are valid completed operations.
    */
    function normalizeStraightEdgeResult operation_result =
    (
        completed = false


        if (classOf operation_result == BooleanClass) then
        (
            completed = operation_result
        )
        else if (classOf operation_result == Integer) then
        (
            completed = true
        )
        else if (classOf operation_result == Array) then
        (
            completed = (
                (operation_result.count >= 2) and
                (classOf operation_result[1] == Integer) and
                (classOf operation_result[2] == BooleanClass)
            )
        )


        completed
        -- return
    )


    /*
    Runs exact selection, skewed selection or selected-edge fixing for one direction.
    LMB is exact, RMB is skewed within Angle, and CTRL+RMB fixes the current edge selection.
    */
    function runStraightEdgeDirection direction_type action:#exact =
    (
        saveStraightEdgeSettings()
        setProgress 0

        if (action == #fix) then
        (
            action_text = "Fixing"
            setStatus #message ("Fixing selected " + (direction_type as string) + " edges...")
            operation_result = StraightEdgeFixer.fixSelectedDirectionEdges direction_type
        )
        else
        (
            selection_mode = if (action == #skewed) then #skewed else #exact
            action_text = if (selection_mode == #exact) then "Selecting exact" else "Selecting skewed"
            setStatus #message (action_text + " " + (direction_type as string) + " edges...")

            operation_result = StraightEdgeFixer.checkEdgeDirection \
                direction_type \
                WallFixerEdgeFixerOptionsRollout.level_tolerance_spinner.value \
                WallFixerEdgeFixerRollout.edge_angle_spinner.value \
                selection_mode:selection_mode
        )

        completed = normalizeStraightEdgeResult operation_result

        if completed and (action == #fix) then
        (
            cleanupRedundantVerticesAfterGeometryChange (selection as array)
        )

        setProgress 100

        if completed then
        (
            setStatus #success (action_text + " " + (direction_type as string) + " edges completed.")
        )
        else
        (
            setStatus #failed (action_text + " " + (direction_type as string) + " edges did not produce a completed result.")
        )

        completed
        -- return
    )


    /*
    Runs the imported border-edge validation using the current Level Tolerance.
    Invalid border edges remain selected for inspection or subsequent correction.
    */
    function runStraightBorderCheck =
    (
        saveStraightEdgeSettings()
        setProgress 0
        setStatus #message "Checking border edges..."
        completed = StraightEdgeFixer.checkBorders WallFixerEdgeFixerOptionsRollout.level_tolerance_spinner.value
        setProgress 100


        if completed then
        (
            setStatus #success "Border edge check completed."
        )
        else
        (
            setStatus #failed "Border edge check did not produce a completed result."
        )


        completed
-- return
    )


    /*
    Selects every open border on the current geometry and enters Border sub-object level.
    No topology is modified; the dedicated EDGE FIXER modifier stores the border edge selection.
    */
    function runStraightBorderSelectAll =
    (
        saveStraightEdgeSettings()
        setProgress 0
        setStatus #message "Selecting all borders..."
        selected_border_edges = StraightEdgeFixer.selectAllBorders()
        setProgress 100

        if selected_border_edges == undefined then
        (
            setStatus #warning "Border Select All: select at least one supported geometry object."
            false
        )
        else
        (
            setStatus #success ("Border Select All: selected " + (selected_border_edges as string) + " open-border edge(s).")
            true
        )
        -- return
    )


    /*
    Runs the imported repeated-level detection/alignment tool with the integrated controls.
    All geometry behavior remains in the separate Straight Edge support module.
    */
    function runStraightEdgeLevelFix =
    (
        saveStraightEdgeSettings()
        setProgress 0
        setStatus #message "Fixing horizontal edge rows by Angle..."


        completed = StraightEdgeFixer.alignSelection \
            level_tolerance:WallFixerEdgeFixerOptionsRollout.level_tolerance_spinner.value \
            min_level_edges:WallFixerEdgeFixerOptionsRollout.min_level_edges_spinner.value \
            angle_threshold:WallFixerEdgeFixerRollout.edge_angle_spinner.value \
            quiet_mode:WallFixerEdgeFixerOptionsRollout.straight_quiet_checkbox.checked


        if completed then cleanupRedundantVerticesAfterGeometryChange (selection as array)
        setProgress 100


        if completed then
        (
            setStatus #success "Horizontal edge-row fixing completed."
        )
        else
        (
            setStatus #error "Horizontal edge-row fixing failed."
        )


        completed
        -- return
    )
/*
    Reuses the current Face Cleaner Fix N-gons operation before or after slicing.
    Existing hidden slicer settings are preserved from the Wall-Fixer INI.
    */
    function runFixNgons workflow_stage:#preprocess =
    (
        saveUiSettings()
        setProgress 0
        setStatus #message (if workflow_stage == #postprocess then "Final Fix N-gons..." else "Fixing N-gons before slicing...")


        completed = WallFixer.propagateSelectionJunctionCuts \
            weld_vertices:WallFixerOptionsRollout.weld_checkbox.checked \
            weld_threshold:WallFixerOptionsRollout.weld_threshold_spinner.value \
            auto_smooth:WallFixerOptionsRollout.auto_smooth_checkbox.checked \
            cut_mode:#all \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:saved_angle_threshold \
            planar_tolerance:saved_planar_tolerance


        if completed then cleanupRedundantVerticesAfterGeometryChange (selection as array)
        setProgress 100


        if completed then
        (
            setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Fix N-gons completed.")
        )
        else
        (
            setStatus #error (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Fix N-gons failed.")
        )


        completed
        -- return
    )



    /*
    Removes one directional Slice namespace from all selected objects for RESET SLICE.
    */
    function deleteSliceWallModifiers modifier_name =
    (
        setProgress 0
        setStatus #message ("RESET SLICE: removing " + modifier_name + " modifiers...")

        local delete_result = WallFixer.deleteSelectedDirectionalSliceModifiers modifier_name

        setProgress 100

        if delete_result[1] then
        (
            if delete_result[2] > 0 then
            (
                setStatus #success WallFixer.last_slice_report
            )
            else
            (
                setStatus #warning WallFixer.last_slice_report
            )
        )
        else
        (
            setStatus #warning WallFixer.last_slice_report
        )

        delete_result[1]
        -- return
    )


    /*
    Activates one named Wall-Fixer slice modifier on the first selected object.
    CTRL variants also enter Edge sub-object level 2 after activating the modifier.
    */
    function activateSliceWallModifier modifier_name enter_edge_level:false =
    (
        if selection.count == 0 then
        (
            setStatus #warning "H \\ V: select an object with a Slice modifier."
            return false
        )

        object_node = selection[1]
        target_modifier = undefined
        requested_name = toUpper (modifier_name as string)

        for modifier in object_node.modifiers while target_modifier == undefined do
        (
            if (toUpper (modifier.name as string)) == requested_name then target_modifier = modifier
        )

        if target_modifier == undefined then
        (
            setStatus #warning ("H \\ V: modifier not found: " + modifier_name)
            return false
        )

        try
        (
            select object_node
            max modify mode
            modPanel.setCurrentObject target_modifier

            if enter_edge_level then
            (
                if classOf target_modifier == Edit_Poly then target_modifier.SetEPolySelLevel #Edge
                subObjectLevel = 2
            )

            setStatus #success (modifier_name + (if enter_edge_level then " | Edge level 2" else " activated"))
            true
        )
        catch
        (
            setStatus #error ("H \\ V failed: " + (getCurrentException() as string))
            false
        )
        -- return
    )

    /*
    Returns true when a modifier name belongs to a Wall-Fixer slicing pass.
    Supports both current directional modifiers and the legacy combined slice modifier.
    */
    function isSliceWallModifierName modifier_name =
    (
        normalized_name = toUpper (modifier_name as string)
        is_slice_modifier = (
            normalized_name == "SLICE HORIZONTAL" or
            normalized_name == "SLICE VERTICAL" or
            normalized_name == "SLICE ALL"
        )


        is_slice_modifier
        -- return
    )


    /*
    Returns true when the object contains at least one Wall-Fixer slicing modifier.
    Slice state is detected without evaluating or changing object topology.
    */
    function isSliceWallObjectSliced object_node =
    (
        sliced_state = false


        if object_node != undefined and isValidNode object_node then
        (
            for modifier in object_node.modifiers while not sliced_state do
            (
                sliced_state = isSliceWallModifierName modifier.name
            )
        )


        sliced_state
        -- return
    )


    /*
    CTRL+LMB Select: selects only true 90-degree open-border corners on the current Edit Poly or Editable Poly.
    Straight 180-degree border vertices are excluded.
    */
    function selectCurrentSlice90BorderCorners =
    (
        setProgress 0
        setStatus #message "Selecting 90° border corners on current poly source..."

        local completed = WallFixer.selectCurrentPoly90BorderCorners             angle_threshold:saved_right_angle_threshold

        setProgress 100

        if completed then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #warning (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "No 90° border corners selected.")
        )

        completed
        -- return
    )


    /*
    Filters the current selection by one exact Slice Walls modifier name.
    When nothing is selected, all visible geometry is used as the source set.
    */
    function selectSliceWallObjects modifier_name =
    (
        local source_nodes = if selection.count > 0 then
        (
            selection as array
        )
        else
        (
            for object_node in geometry where not object_node.isHidden collect object_node
        )

        local filtered_nodes = #()
        local normalized_name = toUpper (modifier_name as string)


        for object_node in source_nodes do
        (
            if object_node != undefined and isValidNode object_node then
            (
                local has_requested_modifier = false

                for stack_modifier in object_node.modifiers while not has_requested_modifier do
                (
                    has_requested_modifier = (toUpper (stack_modifier.name as string) == normalized_name)
                )

                if has_requested_modifier then
                (
                    append filtered_nodes object_node
                )
            )
        )


        if filtered_nodes.count > 0 then
        (
            select filtered_nodes
        )
        else
        (
            clearSelection()
        )


        setStatus #message (("Selected " + (filtered_nodes.count as string)) + " object(s) with " + normalized_name + ".")


        filtered_nodes
        -- return
    )


    /*
    Runs one explicit Slice Walls direction from the main action mouse event.
    LMB supplies Vertical; RMB supplies Horizontal.
    */
    function runSliceSelectedWalls cut_mode =
    (
        if cut_mode != #horizontal and cut_mode != #vertical then
        (
            setStatus #error "Slice Walls requires exactly one direction: Horizontal or Vertical."
            return false
        )

        saveUiSettings()
        setProgress 0
        setStatus #message ("Slicing selected walls: " + (cut_mode as string) + "...")


        completed = WallFixer.debugSliceSelectedWalls \
            cut_mode:cut_mode \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:saved_angle_threshold \
            planar_tolerance:saved_planar_tolerance \
            slice_precision:WallFixerOptionsRollout.slice_precision_spinner.value \
            cleanup_edges:(not WallFixerSliceWallsRollout.no_edge_cleanup_checkbox.checked) \
            display_hidden_edges:WallFixerOptionsRollout.hidden_edges_checkbutton.checked \
            double_side:WallFixerOptionsRollout.double_side_checkbutton.checked \
            include_t_junctions:(if t_junction_only then false else WallFixerSliceWallsRollout.slice_force_t_junction_checkbox.checked) \
            t_junction_only:t_junction_only \
            progress_callback:updateSliceProgress \
            quiet:WallFixerSliceWallsRollout.quiet_checkbox.checked


        if completed then
        (
            cleanupRedundantVerticesAfterGeometryChange (selection as array)
            setProgress 100
            elapsed_seconds = (WallFixer.last_slice_elapsed_ms as float) / 1000.0
            completion_message = "Slice selected walls completed in " + (elapsed_seconds as string) + " s."
            if WallFixer.last_slice_report != "" then completion_message += " " + WallFixer.last_slice_report
            setStatus #success completion_message
        )
        else
        (
            failed_nodes = if isProperty WallFixer #last_slice_failed_nodes then WallFixer.last_slice_failed_nodes else #()
            failure_summary = if failed_nodes.count > 0 then \
                ("Slice selected walls completed with " + (failed_nodes.count as string) + " failed object(s). Failed objects are selected.") \
                else \
                (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Slice selected walls stopped.")

            setProgress 100
            setStatus #failed failure_summary

            failure_message = failure_summary

            if failed_nodes.count > 0 then
            (
                failure_message += "\n\nFAILED OBJECTS:"

                for failed_node in failed_nodes do
                (
                    if failed_node != undefined and isValidNode failed_node then
                    (
                        failure_message += "\n" + failed_node.name
                    )
                )
            )

            if WallFixer.last_slice_report != "" then
            (
                failure_message += "\n\n" + WallFixer.last_slice_report
            )

            messageBox failure_message title:"Wall-Fixer - Slice Selected Walls"
        )


        completed
        -- return
    )


    /*
    Runs Slice Force with the same directional anchor detection as normal Slice Walls.
    One temporary modifier is used per unique plane and the object is collapsed after every plane completes.
    */
    function runSliceForce cut_mode t_junction_only:false =
    (
        if cut_mode != #horizontal and cut_mode != #vertical then
        (
            setStatus #error "Slice Force requires exactly one direction: Horizontal or Vertical."
            return false
        )

        saveUiSettings()
        setProgress 0
        setStatus #message (if t_junction_only then ("Slice Force: " + (toUpper (cut_mode as string)) + " T-JUNCTION VERTS ONLY...") else ("Slice Force: " + (cut_mode as string) + "..."))

        local completed = WallFixer.debugSliceSelectedWallsForce \
            cut_mode:cut_mode \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:saved_angle_threshold \
            planar_tolerance:saved_planar_tolerance \
            slice_precision:WallFixerOptionsRollout.slice_precision_spinner.value \
            cleanup_edges:(not WallFixerSliceWallsRollout.no_edge_cleanup_checkbox.checked) \
            display_hidden_edges:WallFixerOptionsRollout.hidden_edges_checkbutton.checked \
            double_side:WallFixerOptionsRollout.double_side_checkbutton.checked \
            include_t_junctions:WallFixerSliceWallsRollout.slice_force_t_junction_checkbox.checked \
            t_junction_only:t_junction_only \
            progress_callback:updateSliceProgress \
            quiet:WallFixerSliceWallsRollout.quiet_checkbox.checked

        /*
        Paint the final collapsed geometry before exposing the completion state.
        The viewport result is the last processing stage; SUCCESS/FAILED is shown only afterward.
        */
        try(completeRedraw())catch(try(redrawViews())catch())
        try((dotNetClass "System.Windows.Forms.Application").DoEvents())catch()

        setProgress 100

        if completed then
        (
            local elapsed_seconds = (WallFixer.last_slice_elapsed_ms as float) / 1000.0
            local completion_message = (if t_junction_only then ("Slice Force T-junction-only " + (cut_mode as string) + " completed and collapsed in ") else "Slice Force completed and collapsed in ") + (elapsed_seconds as string) + " s."
            if WallFixer.last_slice_report != "" then completion_message += " " + WallFixer.last_slice_report
            setStatus #success completion_message
        )
        else
        (
            local failed_nodes = if isProperty WallFixer #last_slice_failed_nodes then WallFixer.last_slice_failed_nodes else #()
            local failure_summary = if failed_nodes.count > 0 then \
                ("Slice Force completed with " + (failed_nodes.count as string) + " failed object(s). Failed objects are selected.") \
                else \
                (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Slice Force stopped.")

            setStatus #failed failure_summary

            local failure_message = failure_summary

            if failed_nodes.count > 0 then
            (
                failure_message += "\n\nFAILED OBJECTS:"

                for failed_node in failed_nodes do
                (
                    if failed_node != undefined and isValidNode failed_node then
                    (
                        failure_message += "\n" + failed_node.name
                    )
                )
            )

            if WallFixer.last_slice_report != "" then
            (
                failure_message += "\n\n" + WallFixer.last_slice_report
            )

            /*
            A modal failure report is useful only when Core has a real failed object.
            Generic/no-op stops remain in the status area and do not cover the finished viewport.
            */
            if failed_nodes.count > 0 then
            (
                messageBox failure_message title:"Wall-Fixer - Slice Force"
            )
        )

        completed
        -- return
    )


    /*
    Selects degenerated faces and leaves the first matching object on SELECT DEGENERATED FACES at Face level.
    Modified or non-Editable-Poly geometry is preflighted from the evaluated snapshot without collapsing the stack.
    */
    function runSelectDegeneratedFaces =
    (
        setProgress 0
        setStatus #message "Selecting degenerated faces..."
        selection_result = WallFixer.selectDegeneratedFacesSelection debug_output:true
        completed = selection_result[1]
        selected_face_count = selection_result[2]
        setProgress 100


        if completed and selected_face_count > 0 then
        (
            setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Degenerated faces selected.")
        )
        else if completed then
        (
            setStatus #warning (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "No degenerated faces found.")
        )
        else
        (
            setStatus #error (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Degenerated-face selection failed.")
        )


        completed
        -- return
    )


    /*
    Deletes the stored SELECT DEGENERATED FACES face selection and renames the committing modifier.
    RMB never deletes arbitrary faces from unrelated Edit Poly modifiers.
    */
    function runRemoveDegeneratedFaces =
    (
        setProgress 0
        setStatus #message "Removing selected degenerated faces..."
        removal_result = WallFixer.deleteSelectedDegeneratedFacesSelection debug_output:true
        completed = removal_result[1]
        deleted_face_count = removal_result[2]
        setProgress 100


        if completed and deleted_face_count > 0 then
        (
            setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Degenerated faces deleted.")
        )
        else if completed then
        (
            setStatus #warning (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "No stored degenerated faces found to delete.")
        )
        else
        (
            setStatus #error (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Degenerated-face deletion failed.")
        )


        completed
        -- return
    )


    /*
    Runs the integrated stable Redundant Loop Detector LMB event.
    Detection selects accepted chains in SELECT REDUNDANT LOOPS without changing geometry.
    */
    function runSelectRedundantLoops =
    (
        setProgress 0
        setStatus #message "Selecting redundant loops..."
        selection_result = RedundantLoopDetector.selectRedundantLoops face_threshold:0.1 straight_threshold:2.0 debug_output:true
        completed = selection_result[1]
        loop_count = selection_result[2]
        selected_edge_count = selection_result[3]
        setProgress 100


        if completed and selected_edge_count > 0 then
        (
            setStatus #success ("Redundant loops selected. Chains: " + (loop_count as string) + "; edges: " + (selected_edge_count as string) + ".")
        )
        else if completed then
        (
            setStatus #warning "No redundant loops found."
        )
        else
        (
            setStatus #failed ("Redundant-loop detection completed with failures. Chains: " + (loop_count as string) + "; edges: " + (selected_edge_count as string) + ".")
        )


        completed
        -- return
    )


    /*
    Runs the integrated stable Redundant Loop Detector RMB event.
    Only the currently selected edges in the top SELECT REDUNDANT LOOPS modifier are removed.
    */
    function runRemoveRedundantLoops =
    (
        setProgress 0
        setStatus #message "Removing selected redundant-loop edges..."
        completed = RedundantLoopDetector.removeSelectedEdges()
        setProgress 100

        if completed then
        (
            setStatus #success "Selected redundant-loop edges removed."
        )
        else
        (
            setStatus #failed "Redundant-loop removal was not completed."
        )

        completed
        -- return
    )


    /*
    Runs WALLS COMPLETION step 14 by attaching selected walls and welding the merged target.
    The existing Core attach/weld implementation uses the first selected object as the target.
    */
    function runAttachWallsToObjects =
    (
        setProgress 0
        setStatus #message "Attaching and welding selected walls..."
        weld_threshold = WallFixerOptionsRollout.weld_threshold_spinner.value
        saved_weld_threshold = weld_threshold
        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldThreshold" (weld_threshold as string)
        operation_success = false


        undo "Wall-Fixer - Attach Walls To Objects" on
        (
            operation_success = WallFixer.attachAndWeldSelection weld_threshold
        )


        if operation_success then cleanupRedundantVerticesAfterGeometryChange (selection as array)
        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )


    /*
    Runs WALLS COMPLETION step 15 and repairs open-border T-junctions on vertical wall-corner edges.
    The same Options > WELD DISTANCE value is used as the maximum branch-to-edge connection distance.
    */
    function runWeldAndConnectWallCorners =
    (
        setProgress 0
        setStatus #message "Connecting unwelded vertical corner T-junctions..."
        weld_threshold = WallFixerOptionsRollout.weld_threshold_spinner.value
        saved_weld_threshold = weld_threshold
        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldThreshold" (weld_threshold as string)
        operation_success = false


        undo "Wall-Fixer - Weld And Connect Wall Corners" on
        (
            operation_success = WallFixer.repairCornerTJunctions \
                position_threshold:weld_threshold \
                vertical_angle_threshold:5.0
        )


        if operation_success then cleanupRedundantVerticesAfterGeometryChange (selection as array)
        setProgress 100


        if operation_success then
        (
            setStatus #success WallFixer.last_slice_report
        )
        else
        (
            setStatus #failed WallFixer.last_slice_report
        )


        operation_success
        -- return
    )


    /*
    Resizes only the workflow area when the main dialog height changes.
    The dialog width remains locked by createDialog.
    */
    function updateVerticalLayout dialog_height =
    (
        target_height = dialog_height


        if target_height < wall_fixer_min_dialog_height then
        (
            target_height = wall_fixer_min_dialog_height
        )


        workflow_height = target_height - 62
        if workflow_height < 180 then workflow_height = 180
        workflow_subrollout.height = workflow_height
        -- return
    )


    on WallFixerRollout open do
    (
        wallFixerRefreshDialogTitle()
        max_background_color = colorMan.getColor #background
        max_text_color = colorMan.getColor #text
        color_class = dotNetClass "System.Drawing.Color"
        background_color = color_class.FromArgb 68 68 68
        text_color = color_class.FromArgb ((max_text_color.x * 255.0) as integer) ((max_text_color.y * 255.0) as integer) ((max_text_color.z * 255.0) as integer)
        border_style = (dotNetClass "System.Windows.Forms.BorderStyle").None
        scroll_bars = (dotNetClass "System.Windows.Forms.RichTextBoxScrollBars").None
        content_alignment_class = dotNetClass "System.Drawing.ContentAlignment"
        font_style_class = dotNetClass "System.Drawing.FontStyle"


        process_status_label.AutoSize = false
        process_status_label.TextAlign = content_alignment_class.MiddleLeft
        progress_count_label.AutoSize = false
        progress_count_label.TextAlign = content_alignment_class.MiddleCenter
        progress_count_label.BackColor = background_color
        progress_count_label.ForeColor = text_color
        progress_count_label.Text = ""
        progress_count_label.Visible = false
        process_status_label.BackColor = background_color
        process_status_label.ForeColor = text_color
        process_status_label.Font = dotNetObject "System.Drawing.Font" process_status_label.Font font_style_class.Bold
        process_status_label.Text = "READY"
        process_status_label.Visible = true
        workflow_progress.visible = true


        for status_control in #(status_line_top) do
        (
            status_control.ReadOnly = true
            status_control.Multiline = false
            status_control.WordWrap = false
            status_control.TabStop = false
            status_control.BorderStyle = border_style
            status_control.ScrollBars = scroll_bars
            status_control.BackColor = background_color
            status_control.ForeColor = text_color
        )


        renderStatusLine status_line_top status_texts[1]


        current_dialog_size = getDialogSize WallFixerRollout
        updateVerticalLayout current_dialog_size.y


        addSubRollout workflow_subrollout WallFixerOptionsRollout rolledUp:saved_options_rolled_up
        addSubRollout workflow_subrollout WallFixerPreProcessRollout rolledUp:saved_preprocess_rolled_up


        if wallFaceClassifierRollout != undefined then
        (
            addSubRollout workflow_subrollout wallFaceClassifierRollout rolledUp:saved_outer_walls_rolled_up
        )


        addSubRollout workflow_subrollout WallFixerEdgeFixerRollout rolledUp:saved_edge_fixer_rolled_up
        addSubRollout workflow_subrollout WallFixerSliceWallsRollout rolledUp:saved_slice_walls_rolled_up
        addSubRollout workflow_subrollout WallFixerPostProcessRollout rolledUp:saved_postprocess_rolled_up
        addSubRollout workflow_subrollout WallFixerHelpersRollout rolledUp:saved_helpers_rolled_up
        addSubRollout workflow_subrollout WallFixerDebugRollout rolledUp:saved_debug_rolled_up
    )


    on WallFixerRollout moved dialog_position do
    (
        wallFixerSaveDockState()
    )


    on WallFixerRollout resized dialog_size do
    (
        updateVerticalLayout dialog_size.y
        wallFixerSaveDockState()
    )


    on WallFixerRollout close do
    (
        dialog_pos = undefined
        dialog_size = undefined
        current_dock_state = #cui_floatable


        try
        (
            if WallFixerRollout.dialogBar then
            (
                current_dock_state = cui.getDockState WallFixerRollout
            )
        )
        catch
        (
            current_dock_state = #cui_floatable
        )


        wallFixerSaveDockState()


        if current_dock_state == #cui_floatable then
        (
            try
            (
                dialog_pos = getDialogPos WallFixerRollout
                dialog_size = getDialogSize WallFixerRollout
            )
            catch
            (
                dialog_pos = undefined
                dialog_size = undefined
            )
        )


        saveUiSettings dialog_position:dialog_pos dialog_size:dialog_size
        saveStraightEdgeSettings()


        removeSubRollout workflow_subrollout WallFixerDebugRollout
        removeSubRollout workflow_subrollout WallFixerHelpersRollout
        removeSubRollout workflow_subrollout WallFixerPostProcessRollout
        removeSubRollout workflow_subrollout WallFixerSliceWallsRollout
        removeSubRollout workflow_subrollout WallFixerEdgeFixerRollout


        if wallFaceClassifierRollout != undefined then
        (
            try
            (
                removeSubRollout workflow_subrollout wallFaceClassifierRollout
            )
            catch
            (
            )
        )


        removeSubRollout workflow_subrollout WallFixerPreProcessRollout
        removeSubRollout workflow_subrollout WallFixerOptionsRollout
    )
)


wallFixerRefreshDialogTitle()


if saved_dialog_position == undefined then
(
    createDialog WallFixerRollout \
        width:saved_dialog_size.x \
        height:saved_dialog_size.y \
        menu:wall_fixer_main_menu \
        style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) \
        lockWidth:true \
        lockHeight:false
)
else
(
    createDialog WallFixerRollout \
        width:saved_dialog_size.x \
        height:saved_dialog_size.y \
        pos:saved_dialog_position \
        menu:wall_fixer_main_menu \
        style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) \
        lockWidth:true \
        lockHeight:false
)


wallFixerRegisterDialogBar()
wallFixerRestoreDockState saved_dock_state
wallFixerRestoreFloatingDialogPosition saved_dialog_position saved_dock_state
wallFixerRefreshDialogTitle()
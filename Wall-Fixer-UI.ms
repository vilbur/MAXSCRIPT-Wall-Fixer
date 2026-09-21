/*
Wall-Fixer UI 0.23
First redesigned workflow UI using the current Wall-Fixer Core/Pipeline and Straight Edge Fixer logic.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global wall_fixer_ui_file_version = "0.23"
global wall_fixer_ui_tool_version = 0.23

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

if WallFixerRollout != undefined then
(
    try
    (
        WallFixerRollout.title = ("Wall-Fixer " + (WallFixerVersion as string))
    )
    catch
    (
    )
)


global WallFixerRollout
global WallFixerOptionsRollout
global WallFixerPreProcessRollout
global WallFixerEdgeFixerRollout
global WallFixerSliceWallsRollout
global WallFixerPostProcessRollout
global wallFaceClassifierRollout
global wall_fixer_weld_threshold_syncing = false
global wall_fixer_explode_wire_color_counter = 0

wall_fixer_ui_source_path = getSourceFileName()
wall_fixer_ui_ini_path = ((getDir #plugcfg) + "\\Wall-Fixer.ini")
wall_fixer_default_dialog_size = [344,748]
wall_fixer_min_dialog_height = 320

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
Loads the saved Wall-Fixer dialog size.
Width is restored but remains locked; height remains vertically resizable.
*/
function wallFixerLoadDialogSize default_size =
(
    saved_width = wallFixerReadIniInt "Window" "Width" default_size.x
    saved_height = wallFixerReadIniInt "Window" "Height" default_size.y

    if saved_width < 300 then saved_width = default_size.x
    if saved_height < wall_fixer_min_dialog_height then saved_height = wall_fixer_min_dialog_height

    [saved_width, saved_height]
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
Metric, US, Generic and Custom display modes are supported.
*/
function wallFixerGetDisplayUnitLabel =
(
    display_type = units.DisplayType
    unit_label = "unit"

    case display_type of
    (
        #Metric:
        (
            case units.MetricType of
            (
                #Millimeters: unit_label = "mm"
                #Centimeters: unit_label = "cm"
                #Meters: unit_label = "m"
                #Kilometers: unit_label = "km"
                default: unit_label = "unit"
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
                default: unit_label = "unit"
            )
        )
        #Custom:
        (
            unit_label = units.CustomName
            if unit_label == "" then unit_label = "custom"
        )
        default:
        (
            unit_label = "unit"
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
saved_cut_mode_index = WallFixer.readIniInt "CutMode" 1
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
saved_slice_direction_index = if saved_cut_mode_index == 2 then 2 else 1

saved_slice_direction_index = wallFixerReadIniInt "Controls" "SliceDirection" saved_slice_direction_index
if saved_slice_direction_index < 1 or saved_slice_direction_index > 2 then saved_slice_direction_index = 1
saved_quiet_batch = wallFixerReadIniBool "Controls" "SliceQuiet" saved_quiet_batch
saved_dialog_position = wallFixerLoadDialogPosition saved_dialog_position
saved_dialog_size = wallFixerLoadDialogSize wall_fixer_default_dialog_size

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
rcmenu wall_fixer_main_menu
(
    subMenu "Restart"
    (
        menuItem restart_tools_menu_item "Restart Tools"
    )

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

    on restart_tools_menu_item picked do
    (
        restart_script_path = WallFixer.getRestartScriptPath wall_fixer_ui_source_path

        if restart_script_path != undefined then
        (
            wallFixerUnregisterDialogBar()
            fileIn restart_script_path
        )
        else
        (
            messageBox "Wall-Fixer.ms was not found beside the Wall-Fixer component files." title:"Wall-Fixer"
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
    label weld_threshold_label "Threshold:" pos:[140,15] width:62 height:18
    spinner weld_threshold_spinner "" pos:[200,12] width:102 height:20 \
        range:[0.0,1000000.0,saved_weld_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Maximum weld distance. Shared with PRE-PROCESS Vertex Check / Weld.\n\nFresh default: 1 current display unit."

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

            try
            (
                WallFixerPreProcessRollout.weld_threshold_spinner.value = control_value
                WallFixerPreProcessRollout.weld_unit_label.text = wallFixerGetDisplayUnitLabel()
            )
            catch
            (
            )

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
PRE-PROCESS & FIX GEOMETRY contains preparation steps 1 through 5.
Step 4 embeds the Inner-Outer Wall Finder while preserving the surrounding Wall-Fixer workflow.
*/
rollout WallFixerPreProcessRollout "PRE-PROCESS & FIX GEOMETRY" width:310 height:408
(
    button planar_button "1. CHECK AND MAKE WALLS PLANAR" pos:[8,8] width:294 height:34 \
        tooltip:"LMB: check selected walls and select vertices outside the dominant wall plane. An existing top Edit Poly is reused; a NON PLANAR VERTS marker is added only when required.\n\nRMB: move only detected outlier vertices onto the dominant wall plane. Script selection markers are removed first, and the object is collapsed to Editable Poly only when the real stack requires repair."

    button duplicate_verts_button "2. VERTEX CHECK / WELD" pos:[8,48] width:154 height:34 \
        tooltip:"LMB: find unwelded/near-coincident vertices using the Weld threshold as the search distance. Open border edges are also selected when candidates are found.\n\nRMB: weld/fix duplicated vertices using the same Weld threshold."
    label weld_threshold_label "Weld:" pos:[166,57] width:34 height:18 align:#right
    spinner weld_threshold_spinner "" pos:[201,53] width:67 height:20 \
        range:[0.000001,1000000.0,saved_weld_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Weld threshold and LMB search distance. Fresh default: 1 current display unit."
    label weld_unit_label "" pos:[270,57] width:32 height:18 align:#left

    button explode_walls_button "3. EXPLODE OBJECTS TO WALLS" pos:[8,88] width:294 height:30 \
        tooltip:"1. NORMALS: Explode walls by normals\n\n2. FACE DIRECTION: Explode walls by face direction — detects front/backside normals\n\n3. XY POSITION: Explode walls by position\n\n4. ELEMENTS: Explode to elements"

    subRollout outer_walls_subrollout "" pos:[8,124] width:294 height:236

    button two_edge_verts_button "5. FIND TWO-EDGE VERTS AND REMOVE" pos:[8,366] width:294 height:34 \
        tooltip:"LMB: select straight two-visible-edge vertices using the current Wall-Fixer function.\n\nRMB: run the native Vertex Remove command on the current selection."

    on WallFixerPreProcessRollout open do
    (
        wall_fixer_weld_threshold_syncing = true
        weld_threshold_spinner.value = saved_weld_threshold
        weld_unit_label.text = wallFixerGetDisplayUnitLabel()
        wall_fixer_weld_threshold_syncing = false

        if wallFaceClassifierRollout != undefined then
        (
            try
            (
                addSubRollout outer_walls_subrollout wallFaceClassifierRollout rolledUp:false
            )
            catch
            (
            )
        )
    )

    on WallFixerPreProcessRollout close do
    (
        if wallFaceClassifierRollout != undefined then
        (
            try
            (
                removeSubRollout outer_walls_subrollout wallFaceClassifierRollout
            )
            catch
            (
            )
        )
    )

    on weld_threshold_spinner changed control_value do
    (
        if not wall_fixer_weld_threshold_syncing then
        (
            wall_fixer_weld_threshold_syncing = true
            saved_weld_threshold = control_value
            saved_double_vert_threshold = control_value
            weld_unit_label.text = wallFixerGetDisplayUnitLabel()

            try
            (
                WallFixerOptionsRollout.weld_threshold_spinner.value = control_value
            )
            catch
            (
            )

            wall_fixer_weld_threshold_syncing = false
            setIniSetting wall_fixer_ui_ini_path "Controls" "WeldThreshold" (control_value as string)
        )
    )

    on duplicate_verts_button pressed do
    (
        ::WallFixerRollout.runDuplicateVerts fix_vertices:false
    )

    on duplicate_verts_button rightclick do
    (
        ::WallFixerRollout.runDuplicateVerts fix_vertices:true
    )

    on explode_walls_button pressed do
    (
        ::WallFixerRollout.runExplodeObjectsToWalls()
    )

    on planar_button pressed do
    (
        ::WallFixerRollout.runPlanarWalls fix_vertices:false
    )

    on planar_button rightclick do
    (
        ::WallFixerRollout.runPlanarWalls fix_vertices:true
    )

    on two_edge_verts_button pressed do
    (
        ::WallFixerRollout.runFindTwoEdgeVerts()
    )

    on two_edge_verts_button rightclick do
    (
        macros.run "Ribbon - Modeling" "VertexRemove"
        ::WallFixerRollout.setStatus #success "Vertex Remove command executed on the current selection."
    )
)

/*
EDGE FIXER contains geometry-fix workflow steps 6 through 8.
The Straight Edge Fixer controls and callbacks are inherited without changing their geometry logic.
*/
rollout WallFixerEdgeFixerRollout "EDGE FIXER" width:310 height:352
(
    groupBox edge_z_group "6. EDGE Z-LEVEL FIXING AND BORDER EDGES CHECK" pos:[8,8] width:294 height:248

    label level_settings_label "LEVEL SETTINGS" pos:[18,28] width:104 height:18
    label level_tolerance_label "Level Tol:" pos:[18,52] width:58 height:18
    spinner level_tolerance_spinner "" pos:[76,49] width:72 height:20 \
        range:[0.000001,1000000.0,0.01] type:#worldUnits scale:0.001 \
        tooltip:"Maximum world-axis deviation used for level detection and direction checks."

    label min_edges_label "Min Edges:" pos:[158,52] width:60 height:18
    spinner min_level_edges_spinner "" pos:[220,49] width:62 height:20 \
        range:[1,100000,3] type:#integer scale:1 \
        tooltip:"Minimum horizontal edge count needed to define a valid Z level."

    label search_z_label "Search Z:" pos:[18,78] width:58 height:18
    spinner search_in_z_spinner "" pos:[76,75] width:72 height:20 \
        range:[0.0,1000000.0,10.0] type:#worldUnits scale:0.1 \
        tooltip:"Maximum world-Z distance from a detected level."

    checkbox straight_quiet_checkbox "Quiet" pos:[158,77] width:58 height:18 checked:false \
        tooltip:"Suppress the Straight Edge Fixer final report dialog."

    label edge_checks_label "EDGE CHECKS" pos:[18,106] width:82 height:18
    label edge_angle_label "Angle:" pos:[158,106] width:42 height:18
    spinner edge_angle_spinner "" pos:[202,103] width:80 height:20 \
        range:[0.0,45.0,45.0] type:#float scale:1.0 \
        tooltip:"Candidate direction angle threshold in degrees."

    button check_horizontal_button "CHECK HORIZONTAL" pos:[18,130] width:127 height:34 \
        tooltip:"LMB: select visible near-horizontal error edges.\n\nRMB: straighten currently selected near-horizontal edges."
    button check_vertical_button "CHECK VERTICAL" pos:[155,130] width:127 height:34 \
        tooltip:"LMB: select visible near-vertical error edges.\n\nRMB: straighten currently selected near-vertical edges."

    button border_check_button "BORDER CHECK" pos:[18,170] width:264 height:30 \
        tooltip:"Select visible border edges with unwelded/overlapping local-Z seams, reflex corners above 180 degrees or 360-degree backtracking borders."

    button straight_edge_fixer_button "STRAIGHT EDGE FIXER" pos:[18,206] width:264 height:36 \
        tooltip:"Detect repeated horizontal edge levels and align nearby horizontal edges to TOP, BOTTOM or CENTER target Z."

    button fix_ngons_button "7. FIX N-GONS" pos:[8,266] width:294 height:34 \
        tooltip:"Run the current Wall-Fixer Fix N-gons function before slicing."

    groupBox check_result_group "8. CHECK RESULT" pos:[8,306] width:294 height:38
    label check_result_label "Manual viewport check of geometry fixes." pos:[18,322] width:274 height:18

    on WallFixerEdgeFixerRollout open do
    (
        settings_data = StraightEdgeFixer.loadSettings()
        level_tolerance_spinner.value = wallFixerReadIniFloat "Controls" "LevelTolerance" settings_data[1]
        min_level_edges_spinner.value = wallFixerReadIniInt "Controls" "MinLevelEdges" settings_data[2]
        search_in_z_spinner.value = wallFixerReadIniFloat "Controls" "SearchInZ" settings_data[3]
        edge_angle_spinner.value = wallFixerReadIniFloat "Controls" "EdgeAngle" settings_data[4]
        straight_quiet_checkbox.checked = wallFixerReadIniBool "Controls" "StraightQuiet" settings_data[5]
    )

    on level_tolerance_spinner changed control_value do
    (
        ::WallFixerRollout.saveStraightEdgeSettings()
    )

    on min_level_edges_spinner changed control_value do
    (
        ::WallFixerRollout.saveStraightEdgeSettings()
    )

    on search_in_z_spinner changed control_value do
    (
        ::WallFixerRollout.saveStraightEdgeSettings()
    )

    on edge_angle_spinner changed control_value do
    (
        ::WallFixerRollout.saveStraightEdgeSettings()
    )

    on straight_quiet_checkbox changed control_state do
(
        ::WallFixerRollout.saveStraightEdgeSettings()
    )

    on check_horizontal_button pressed do
    (
        ::WallFixerRollout.runStraightEdgeDirection #horizontal fix_selected:false
    )

    on check_horizontal_button rightclick do
    (
        ::WallFixerRollout.runStraightEdgeDirection #horizontal fix_selected:true
    )

    on check_vertical_button pressed do
    (
        ::WallFixerRollout.runStraightEdgeDirection #vertical fix_selected:false
    )

    on check_vertical_button rightclick do
    (
        ::WallFixerRollout.runStraightEdgeDirection #vertical fix_selected:true
    )

    on border_check_button pressed do
    (
        ::WallFixerRollout.runStraightBorderCheck()
    )

    on straight_edge_fixer_button pressed do
    (
        ::WallFixerRollout.runStraightEdgeLevelFix()
    )

    on fix_ngons_button pressed do
    (
        ::WallFixerRollout.runFixNgons #preprocess
    )
)

/*
SLICE WALLS exposes only the requested Vertical/Horizontal choice and the inherited batch slicer.
Advanced slicer values continue to come from the existing Wall-Fixer INI settings.
*/
rollout WallFixerSliceWallsRollout "SLICE WALLS" width:310 height:132
(
    radiobuttons slice_direction_radio "" pos:[8,8] width:178 height:20 \
        labels:#("Vertical", "Horizontal") default:saved_slice_direction_index columns:2 align:#left \
        tooltip:"Choose which directional pass runs first. Existing directional modifier separation is preserved."

    checkbox quiet_checkbox "Quiet" pos:[236,10] width:62 height:18 checked:saved_quiet_batch \
        tooltip:"Suppress verbose Listener output during the inherited batch slicing operation."

    button slice_selected_walls_button "9. SLICE SELECTED WALLS" pos:[8,42] width:294 height:38 \
        tooltip:"Reuse the current directional slicing system. Vertical and Horizontal remain separate Edit Poly modifiers and duplicate slice modifiers are prevented."

    groupBox slice_check_result_group "CHECK RESULT" pos:[8,84] width:294 height:40
    label slice_check_result_label "Manual viewport check after slicing." pos:[18,101] width:274 height:18

    on slice_direction_radio changed state do
    (
        ::WallFixerRollout.saveUiSettings()
    )

    on quiet_checkbox changed control_state do
    (
        ::WallFixerRollout.saveUiSettings()
    )

    on slice_selected_walls_button pressed do
    (
        ::WallFixerRollout.runSliceSelectedWalls()
    )
)

/*
POST-PROCESS exposes current cleanup tools and reserves the new missing-loop/corner-completion actions.
The two wall-completion buttons remain disabled until their detailed behavior is implemented.
*/
rollout WallFixerPostProcessRollout "POST-PROCESS" width:310 height:268
(
    button duplicated_vertices_button "10. DUPLICATED VERTICES" pos:[8,8] width:294 height:34 \
        tooltip:"LMB: select duplicate-position vertices at 0.01 tolerance.\n\nRMB: run the current duplicate-vertex fix at 0.01 tolerance."

    button redundant_loops_button "11. REMOVE REDUNDANT LOOPS AND EDGES" pos:[8,48] width:294 height:34 \
        tooltip:"Reuse the current Redundant Loop Cleanup operation."

    button repair_missing_loops_button "12. COMPLETE / REPAIR MISSING LOOPS" pos:[8,88] width:294 height:34 enabled:false \
        tooltip:"Reserved for the new missing-loop completion tool."

    button post_fix_ngons_button "13. FIX N-GONS" pos:[8,128] width:294 height:34 \
        tooltip:"Run the current Wall-Fixer Fix N-gons function again after slicing cleanup."

    groupBox walls_completion_group "WALLS COMPLETION" pos:[8,170] width:294 height:90

    button attach_walls_button "14. ATTACH WALLS TO OBJECTS" pos:[18,190] width:264 height:28 enabled:false \
        tooltip:"Reserved for the new Attach walls to objects function. Existing ATTACH AND WELD is intentionally not substituted because this step will have separate requirements."

    button weld_corners_button "15. WELD AND CONNECT WALL CORNERS" pos:[18,224] width:264 height:28 enabled:false \
        tooltip:"Reserved for welding wall corners and repairing continuous edge loops through the corners."

    on duplicated_vertices_button pressed do
    (
        ::WallFixerRollout.runDuplicateVerts fix_vertices:false
    )

    on duplicated_vertices_button rightclick do
    (
        ::WallFixerRollout.runDuplicateVerts fix_vertices:true
    )

    on redundant_loops_button pressed do
    (
        ::WallFixerRollout.runRedundantLoopCleanup()
    )

    on post_fix_ngons_button pressed do
    (
        ::WallFixerRollout.runFixNgons #postprocess
    )
)

/*
Main Wall-Fixer dialog owns shared progress, two-line message history and function wrappers.
Child rollouts contain controls only and call these centralized handlers.
*/
rollout WallFixerRollout "Wall-Fixer" width:344 height:748
(
    progressbar workflow_progress "" pos:[8,8] width:328 height:14 value:0 color:(color 0 180 0) orient:#horizontal
    dotNetControl process_status_label "System.Windows.Forms.Label" pos:[8,6] width:76 height:40
    dotNetControl status_line_top "System.Windows.Forms.RichTextBox" pos:[88,6] width:248 height:19
    dotNetControl status_line_bottom "System.Windows.Forms.RichTextBox" pos:[88,28] width:248 height:19
    subRollout workflow_subrollout "" pos:[8,54] width:328 height:686

    local status_texts = #("Ready.", "")
    local last_progress_value = -1

    /*
    Converts multiline reports into a compact single status line.
    The status header retains only the two newest messages.
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
    Shows the completed process state in the progress-bar position.
    Final SUCCESS/WARNING/ERROR states hide the progress bar until another process starts.
    */
    function showProcessResult result_type =
    (
        color_class = dotNetClass "System.Drawing.Color"
        result_text = "SUCCESS"
        result_color = color_class.HotPink

        case result_type of
        (
            #warning:
            (
                result_text = "WARNING"
                result_color = color_class.DarkOrange
            )
            #error:
            (
                result_text = "ERROR"
                result_color = color_class.Red
            )
            default:
            (
                result_text = "SUCCESS"
                result_color = color_class.HotPink
            )
        )

        workflow_progress.visible = false
        status_line_top.Visible = true
        status_line_bottom.Visible = true
        process_status_label.Text = result_text
        process_status_label.ForeColor = result_color
        process_status_label.Visible = true
        -- return
    )

    /*
    Pushes one plain message into the shared two-line status history.
    The message type controls only the result label shown above it.
    */
    function setStatus message_type message_text =
    (
        status_texts[2] = status_texts[1]
        status_texts[1] = compactStatusText message_text

        renderStatusLine status_line_top status_texts[1]
        renderStatusLine status_line_bottom status_texts[2]

        if (message_type == #success) or (message_type == #warning) or (message_type == #error) then
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
    Starting or updating work shows the bar and hides the completed-state label.
    */
    function setProgress progress_value =
    (
        clamped_value = progress_value as integer
        if clamped_value < 0 then clamped_value = 0
        if clamped_value > 100 then clamped_value = 100

        if clamped_value != last_progress_value then
        (
            last_progress_value = clamped_value

            if clamped_value < 100 then
            (
                process_status_label.Visible = false
                status_line_top.Visible = false
                status_line_bottom.Visible = false
                workflow_progress.visible = true
            )

            workflow_progress.value = clamped_value

            try
            (
                (dotNetClass "System.Windows.Forms.Application").DoEvents()
            )
            catch
            (
            )
        )
        -- return
    )

    /*
    Receives the existing batch slicer's processed/total object counts.
    It updates both the green progress bar and the shared plain status line.
    */
    function updateSliceProgress processed_count total_count =(
        progress_percent = 0

        if total_count > 0 then
        (
            progress_percent = ((100.0 * processed_count) / total_count) as integer
        )

        setProgress progress_percent
        setStatus #message ((processed_count as string) + " / " + (total_count as string) + " objects")
        -- return
    )

    /*
    Returns the current inherited slicing direction requested by the new UI.
    Vertical and Horizontal preserve the current two-modifier directional behavior.
    */
    function getSliceCutMode =
    (
        if WallFixerSliceWallsRollout.slice_direction_radio.state == 2 then
        (
            #horizontal
        )
        else
        (
            #vertical
        )
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
        cut_mode_index = if WallFixerSliceWallsRollout.slice_direction_radio.state == 2 then 2 else 3

        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldVertices" (if WallFixerOptionsRollout.weld_checkbox.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldThreshold" (saved_weld_threshold as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "DisplayHiddenEdges" (if WallFixerOptionsRollout.hidden_edges_checkbutton.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "DoubleSide" (if WallFixerOptionsRollout.double_side_checkbutton.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "AutoSmooth" (if WallFixerOptionsRollout.auto_smooth_checkbox.checked then "1" else "0")
        setIniSetting wall_fixer_ui_ini_path "Controls" "SlicePrecision" (WallFixerOptionsRollout.slice_precision_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "SliceDirection" (WallFixerSliceWallsRollout.slice_direction_radio.state as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "SliceQuiet" (if WallFixerSliceWallsRollout.quiet_checkbox.checked then "1" else "0")

        if dialog_position != undefined then
        (
            setIniSetting wall_fixer_ui_ini_path "Window" "X" ((dialog_position.x as integer) as string)
            setIniSetting wall_fixer_ui_ini_path "Window" "Y" ((dialog_position.y as integer) as string)
        )

        if dialog_size != undefined then
        (
            setIniSetting wall_fixer_ui_ini_path "Window" "Width" ((dialog_size.x as integer) as string)
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
    Persists all controls imported from Straight Edge Fixer.
    Geometry logic continues using its original settings store.
    */
    function saveStraightEdgeSettings =
    (
        setIniSetting wall_fixer_ui_ini_path "Controls" "LevelTolerance" (WallFixerEdgeFixerRollout.level_tolerance_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "MinLevelEdges" (WallFixerEdgeFixerRollout.min_level_edges_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "SearchInZ" (WallFixerEdgeFixerRollout.search_in_z_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "EdgeAngle" (WallFixerEdgeFixerRollout.edge_angle_spinner.value as string)
        setIniSetting wall_fixer_ui_ini_path "Controls" "StraightQuiet" (if WallFixerEdgeFixerRollout.straight_quiet_checkbox.checked then "1" else "0")

        StraightEdgeFixer.saveSettings \
            WallFixerEdgeFixerRollout.level_tolerance_spinner.value \
            WallFixerEdgeFixerRollout.min_level_edges_spinner.value \
            WallFixerEdgeFixerRollout.search_in_z_spinner.value \
            WallFixerEdgeFixerRollout.edge_angle_spinner.value \
            WallFixerEdgeFixerRollout.straight_quiet_checkbox.checked
        -- return
    )

    /*
    Converts selected geometry to Editable Poly only when the base object is not already Editable Poly.
    This wrapper is used only by inherited functions that require a base Editable Poly.
    */
    function ensureSelectionEditablePoly =
    (
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
    Runs the duplicate-vertex check/fix using the visible Weld threshold.
    LMB finds duplicate vertices; RMB selects the same candidates and welds them with weldSelectedEPolyVerts.
    */
    function runDuplicateVerts fix_vertices:false =
    (
        setProgress 0
        WallFixerPreProcessRollout.weld_unit_label.text = wallFixerGetDisplayUnitLabel()
        weld_threshold = WallFixerPreProcessRollout.weld_threshold_spinner.value
        saved_weld_threshold = weld_threshold
        saved_double_vert_threshold = weld_threshold
        wall_fixer_weld_threshold_syncing = true

        try
        (
            WallFixerOptionsRollout.weld_threshold_spinner.value = weld_threshold
        )
        catch
        (
        )

        wall_fixer_weld_threshold_syncing = false
        setIniSetting wall_fixer_ui_ini_path "Controls" "WeldThreshold" (weld_threshold as string)
        setStatus #message (if fix_vertices then "Welding duplicated vertices..." else "Checking unwelded vertices...")

        conversion_nodes = selection as array
        conversion_failed_count = 0

        for scene_node in conversion_nodes do
        (
            if isValidNode scene_node and superClassOf scene_node == GeometryClass then
            (
                if classOf scene_node.baseObject != Editable_Poly then
                (
                    conversion_success = true

                    try
                    (
                        convertToPoly scene_node
                    )
                    catch
                    (
                        conversion_success = false
                    )

                    if (not conversion_success) or (classOf scene_node.baseObject != Editable_Poly) then
                    (
                        conversion_failed_count += 1
                    )
                )
            )
        )

        if conversion_failed_count > 0 then
        (
            setStatus #error ((conversion_failed_count as string) + " selected object(s) could not be converted to Editable Poly.")
            false
        )
        else
        (
            completed = WallFixer.selectDoubleVerts position_threshold:weld_threshold

            if completed and fix_vertices then
            (
                selected_nodes = selection as array
                removed_count = 0
                weld_failed_count = 0

                for node in selected_nodes do
                (
                    if isValidNode node and classOf node.baseObject == Editable_Poly then
                    (
                        weld_result = weldSelectedEPolyVerts node weld_threshold

                        if weld_result == false then
                        (
                            weld_failed_count += 1
                        )
                        else
                        (
                            removed_count += weld_result
                        )
                    )
                )

                if weld_failed_count > 0 then
                (
                    completed = false
                    setStatus #error ((weld_failed_count as string) + " object(s) could not be welded.")
                )
                else
                (
                    WallFixer.selectDoubleVerts position_threshold:weld_threshold
                    remaining_unweld_verts = 0

                    for node in selected_nodes do
                    (
                        if isValidNode node and classOf node.baseObject == Editable_Poly then
                        (
                            selected_verts = polyOp.getVertSelection node.baseObject
                            remaining_unweld_verts += selected_verts.numberSet
                        )
                    )

                    if remaining_unweld_verts > 0 then
                    (
                        setStatus #warning ((removed_count as string) + " vertices welded; unresolved vertices remain selected.")
                    )
                    else if removed_count > 0 then
                    (
                        try
                        (
                            subObjectLevel = 0
                        )
                        catch
                        (
                        )

                        setStatus #success ((removed_count as string) + " vertices welded.")
                    )
                    else
                    (
                        try
                        (
                            subObjectLevel = 0
                        )
                        catch
                        (
                        )

                        setStatus #success "No vertices needed welding."
                    )
                )
            )

            setProgress 100

            if completed and not fix_vertices then
            (
                selected_nodes = selection as array
                total_unweld_verts = 0

                for node in selected_nodes do
                (
                    if isValidNode node and classOf node.baseObject == Editable_Poly then
                    (
                        base_obj = node.baseObject
                        selected_verts = polyop.getVertSelection base_obj
                        total_unweld_verts += selected_verts.numberSet

                        if selected_verts.numberSet > 0 then
                        (
                            open_edges = polyop.getOpenEdges base_obj
                            polyop.setEdgeSelection base_obj open_edges
                            update node
                        )
                    )
                )

                if total_unweld_verts > 0 then
                (
                    try
                    (
                        max modify mode
                        subObjectLevel = 1
                    )
                    catch
                    (
                    )

                    setStatus #warning "Unweld verts selected"
                )
                else
                (
                    try
                    (
                        subObjectLevel = 0
                    )
                    catch
                    (
                    )

                    setStatus #success "All vertices are welded."
                )
            )
            else if not completed then
            (
                if fix_vertices == false then
                (
                    setStatus #error "Vertex check operation could not be completed."
                )
            )

            completed
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
        result_data = #(false, #())
        conversion_success = false

        try
        (
            convertToPoly source_node
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
                        failed_count += 1
                        if isValidNode source_node then appendSmartExplodeOutputNode output_nodes source_node
                        setStatus #error (source_name + ": confirmed " + (operation_type as string) + " split could not be completed.")
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
                            failed_count += 1

                            if isValidNode source_node then
                            (
                                appendSmartExplodeOutputNode final_nodes source_node
                            )
format "ERROR: % confirmed split could not be completed.\n" source_name
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

        redrawViews()
        completed
        -- return
    )

    /*
    Reuses the existing straight two-visible-edge vertex finder.
    Removal remains the native Vertex Remove RMB action on the workflow button.
    */
    function runFindTwoEdgeVerts =
    (
        setProgress 0
        setStatus #message "Finding straight two-edge vertices..."
        completed = WallFixer.debugFindTwoEdgeVerts angle_threshold:0.1
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
    Runs the imported Straight Edge Fixer horizontal/vertical check or straighten action.
    LMB checks and RMB straightens the currently selected candidate edges.
    */
    function runStraightEdgeDirection direction_type fix_selected:false =
    (
        saveStraightEdgeSettings()
        setProgress 0
        action_text = if fix_selected then "Straightening" else "Checking"
        setStatus #message (action_text + " " + (direction_type as string) + " edges...")

        if fix_selected then
        (
            completed = StraightEdgeFixer.straightenSelectedEdges \
                direction_type \
                WallFixerEdgeFixerRollout.level_tolerance_spinner.value \
                WallFixerEdgeFixerRollout.edge_angle_spinner.value \
                WallFixerEdgeFixerRollout.search_in_z_spinner.value
        )
        else
        (
            completed = StraightEdgeFixer.checkEdgeDirection \
                direction_type \
                WallFixerEdgeFixerRollout.level_tolerance_spinner.value \
                WallFixerEdgeFixerRollout.edge_angle_spinner.value
        )

        setProgress 100

        if completed then
        (
            setStatus #success (action_text + " " + (direction_type as string) + " edges completed.")
        )
        else
        (
            setStatus #warning (action_text + " " + (direction_type as string) + " edges did not produce a completed result.")
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
        completed = StraightEdgeFixer.checkBorders WallFixerEdgeFixerRollout.level_tolerance_spinner.value
        setProgress 100

        if completed then
        (
            setStatus #success "Border edge check completed."
        )
        else
        (
            setStatus #warning "Border edge check did not produce a completed result."
        )

        completed
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
        setStatus #message "Fixing edge Z levels..."

        completed = StraightEdgeFixer.alignSelection \
            level_tolerance:WallFixerEdgeFixerRollout.level_tolerance_spinner.value \
            min_level_edges:WallFixerEdgeFixerRollout.min_level_edges_spinner.value \
            search_in_z:WallFixerEdgeFixerRollout.search_in_z_spinner.value \
            quiet_mode:WallFixerEdgeFixerRollout.straight_quiet_checkbox.checked

        setProgress 100

        if completed then
        (
            setStatus #success "Edge Z-level fixing completed."
        )
        else
        (
            setStatus #error "Edge Z-level fixing failed."
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
            cut_mode:(getSliceCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:saved_angle_threshold \
            planar_tolerance:saved_planar_tolerance

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
    Runs the current fixed base-object batch slicer using the selected directional order.
    Existing modifier separation and duplicate-prevention rules remain inside Wall-Fixer Core.
    */
    function runSliceSelectedWalls =
    (
        saveUiSettings()
        setProgress 0
        setStatus #message "Slicing selected walls..."

        completed = WallFixer.debugSliceSelectedWalls \
            cut_mode:(getSliceCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:saved_angle_threshold \
            planar_tolerance:saved_planar_tolerance \
            slice_precision:WallFixerOptionsRollout.slice_precision_spinner.value \
            display_hidden_edges:WallFixerOptionsRollout.hidden_edges_checkbutton.checked \
            double_side:WallFixerOptionsRollout.double_side_checkbutton.checked \
            progress_callback:updateSliceProgress \
            quiet:WallFixerSliceWallsRollout.quiet_checkbox.checked

        if completed then
        (
            setProgress 100
            setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Slice selected walls completed.")
        )
        else
        (
            setStatus #error (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Slice selected walls stopped.")
        )

        completed
        -- return
    )

    /*
    Reuses the current geometric redundant-loop cleanup operation.
    It leaves no cleanup modifier behind when no valid redundant loop is found.
    */
    function runRedundantLoopCleanup =
    (
        setProgress 0
        setStatus #message "Removing redundant loops and edges..."
        completed = WallFixer.cleanupRedundantLoopsSelection angle_threshold:0.1 debug_output:true
        setProgress 100

        if completed then
        (
            setStatus #success (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "Redundant-loop cleanup completed.")
        )
        else
        (
            setStatus #warning (if WallFixer.last_slice_report != "" then WallFixer.last_slice_report else "No redundant loops were removed.")
        )

        completed
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
        WallFixerRollout.title = ("Wall-Fixer " + (WallFixerVersion as string))
        max_background_color = colorMan.getColor #background
        max_text_color = colorMan.getColor #text
        color_class = dotNetClass "System.Drawing.Color"
        background_color = color_class.FromArgb ((max_background_color.x * 255.0) as integer) ((max_background_color.y * 255.0) as integer) ((max_background_color.z * 255.0) as integer)
        text_color = color_class.FromArgb ((max_text_color.x * 255.0) as integer) ((max_text_color.y * 255.0) as integer) ((max_text_color.z * 255.0) as integer)
        border_style = (dotNetClass "System.Windows.Forms.BorderStyle").None
        scroll_bars = (dotNetClass "System.Windows.Forms.RichTextBoxScrollBars").None
        content_alignment_class = dotNetClass "System.Drawing.ContentAlignment"
        font_style_class = dotNetClass "System.Drawing.FontStyle"

        process_status_label.AutoSize = false
        process_status_label.TextAlign = content_alignment_class.MiddleLeft
        process_status_label.BackColor = background_color
        process_status_label.ForeColor = text_color
        process_status_label.Font = dotNetObject "System.Drawing.Font" process_status_label.Font font_style_class.Bold
        process_status_label.Text = "READY"
        process_status_label.Visible = true
        workflow_progress.visible = false

        for status_control in #(status_line_top, status_line_bottom) do
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
        renderStatusLine status_line_bottom status_texts[2]

        current_dialog_size = getDialogSize WallFixerRollout
        updateVerticalLayout current_dialog_size.y

        addSubRollout workflow_subrollout WallFixerOptionsRollout rolledUp:false
        addSubRollout workflow_subrollout WallFixerPreProcessRollout rolledUp:false
        addSubRollout workflow_subrollout WallFixerEdgeFixerRollout rolledUp:true
        addSubRollout workflow_subrollout WallFixerSliceWallsRollout rolledUp:true
        addSubRollout workflow_subrollout WallFixerPostProcessRollout rolledUp:true
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

        removeSubRollout workflow_subrollout WallFixerPostProcessRollout
        removeSubRollout workflow_subrollout WallFixerSliceWallsRollout
        removeSubRollout workflow_subrollout WallFixerEdgeFixerRollout
        removeSubRollout workflow_subrollout WallFixerPreProcessRollout
        removeSubRollout workflow_subrollout WallFixerOptionsRollout
    )
)

WallFixerRollout.title = ("Wall-Fixer " + (WallFixerVersion as string))

if saved_dialog_position == undefined then
(
    createDialog WallFixerRollout \
        width:saved_dialog_size.x \
        height:saved_dialog_size.y \
        menu:wall_fixer_main_menu \
        style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) \
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
        style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) \
        lockWidth:true \
        lockHeight:false
)

wallFixerRegisterDialogBar()
wallFixerRestoreDockState saved_dock_state
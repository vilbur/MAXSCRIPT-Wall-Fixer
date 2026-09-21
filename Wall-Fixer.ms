/*
Wall-Fixer Loader 0.22
Loads the fixed canonical component filenames from this folder.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global wall_fixer_loader_file_version = "0.22"
global wall_fixer_loader_tool_version = 0.22

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

wall_fixer_loader_current_tool_version_number = undefined

if WallFixerVersion != undefined then
(
    try
    (
        wall_fixer_loader_current_tool_version_number = WallFixerVersion as float
    )
    catch
    (
        wall_fixer_loader_current_tool_version_number = undefined
    )
)

if wall_fixer_loader_current_tool_version_number == undefined then
(
    WallFixerVersion = wall_fixer_loader_tool_version
)
else if wall_fixer_loader_tool_version > wall_fixer_loader_current_tool_version_number then
(
    WallFixerVersion = wall_fixer_loader_tool_version
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


/*
Requires one canonical Wall-Fixer component from the supplied folder.
Throws a descriptive error when the codebase is incomplete.
*/
function requireWallFixerComponent folder_path file_name =
(
    component_path = folder_path + file_name

    if not doesFileExist component_path then
    (
        throw ("Wall-Fixer loader: missing component: " + component_path)
    )

    component_path
    -- return
)

/*
Prints the exact component files that the loader will use without loading them.
Use this to verify that the unversioned codebase is complete.
*/
function testWallFixerLoader folder_path:undefined =
(
    test_folder = folder_path

    if test_folder == undefined then
    (
        test_folder = getFilenamePath (getSourceFileName())
    )

    pipeline_file = requireWallFixerComponent test_folder "Wall-Fixer-Pipeline.ms"
    core_file = requireWallFixerComponent test_folder "Wall-Fixer-Core.ms"
    straight_edge_file = requireWallFixerComponent test_folder "Straight-Edge-Fixer.ms"
    ui_file = requireWallFixerComponent test_folder "Wall-Fixer-UI.ms"

    format "\n============================================================\n"
    format "WALL-FIXER LOADER TEST %\n" wall_fixer_loader_file_version
    format "Folder:        %\n" test_folder
    format "Pipeline:      %\n" pipeline_file
    format "Core:          %\n" core_file
    format "Straight Edge: %\n" straight_edge_file
    format "UI:            %\n" ui_file
    format "============================================================\n"

    #(pipeline_file, core_file, straight_edge_file, ui_file)
    -- return
)

script_folder = getFilenamePath (getSourceFileName())
pipeline_file = requireWallFixerComponent script_folder "Wall-Fixer-Pipeline.ms"
core_file = requireWallFixerComponent script_folder "Wall-Fixer-Core.ms"
straight_edge_file = requireWallFixerComponent script_folder "Straight-Edge-Fixer.ms"
ui_file = requireWallFixerComponent script_folder "Wall-Fixer-UI.ms"

format "Wall-Fixer loader %\n" wall_fixer_loader_file_version
format "Pipeline: %\n" pipeline_file
format "Core: %\n" core_file
format "Straight Edge: %\n" straight_edge_file
format "UI: %\n" ui_file

/*
Load dependency order:
1. Wall-Fixer Pipeline
2. Wall-Fixer Core
3. Straight Edge Fixer logic
4. Wall-Fixer UI
*/
fileIn pipeline_file
fileIn core_file
fileIn straight_edge_file

try
(
    destroyDialog straightEdgeFixer_ui
)
catch
(
)

fileIn ui_file

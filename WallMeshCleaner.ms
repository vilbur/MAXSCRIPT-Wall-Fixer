/*
WallMeshCleaner development loader.
Keep this file unversioned. It automatically loads the newest versioned
Pipeline, Core and UI files from this same directory.
*/

try
(
    destroyDialog WallMeshCleanerRollout
)
catch
(
)

global WallMeshCleanerScriptPath
global wmc_loaded_pipeline_path
global wmc_loaded_core_path
global wmc_loaded_ui_path
global wmcGetVersionParts
global wmcIsVersionNewer
global wmcGetNewestVersionedFile
global wmcLoadNewestComponent

WallMeshCleanerScriptPath = getSourceFileName()

/*
Returns integer version components parsed from a file suffix such as 0.930.
Non-numeric or missing components make the version invalid.
*/
function wmcGetVersionParts version_text =
(
    version_parts = #()
    text_parts = filterString version_text "."

    if text_parts.count < 1 then
    (
        undefined
    )
    else
    (
        parse_valid = true
        for text_part in text_parts while parse_valid do
        (
            part_value = undefined
            try
            (
                part_value = text_part as integer
            )
            catch
            (
                part_value = undefined
            )

            if part_value == undefined then
            (
                parse_valid = false
            )
            else
            (
                append version_parts part_value
            )
        )

        if parse_valid then version_parts else undefined
    )
    -- return
)

/*
Returns true when candidate_version is newer than current_version.
Version components are compared numerically so 0.1000 is newer than 0.930.
*/
function wmcIsVersionNewer candidate_version current_version =
(
    candidate_parts = wmcGetVersionParts candidate_version
    current_parts = wmcGetVersionParts current_version

    if candidate_parts == undefined then
    (
        false
    )
    else if current_parts == undefined then
    (
        true
    )
    else
    (
        max_part_count = candidate_parts.count
        if current_parts.count > max_part_count then max_part_count = current_parts.count
        comparison_result = false
        comparison_finished = false

        for part_index = 1 to max_part_count while not comparison_finished do
        (
            candidate_part = if part_index <= candidate_parts.count then candidate_parts[part_index] else 0
            current_part = if part_index <= current_parts.count then current_parts[part_index] else 0

            if candidate_part > current_part then
            (
                comparison_result = true
                comparison_finished = true
            )
            else if candidate_part < current_part then
            (
                comparison_result = false
                comparison_finished = true
            )
        )

        comparison_result
    )
    -- return
)

/*
Returns the highest-version component file matching <prefix>_<version>.ms.
Only files in directory_path are considered; subdirectories are not searched.
*/
function wmcGetNewestVersionedFile directory_path file_prefix =
(
    search_pattern = directory_path + file_prefix + "_*.ms"
    candidate_files = getFiles search_pattern
    newest_path = undefined
    newest_version = undefined
    prefix_length = file_prefix.count

    for candidate_path in candidate_files do
    (
        candidate_name = getFilenameFile candidate_path
        version_start = prefix_length + 2

        if candidate_name.count >= version_start then
        (
            version_text = substring candidate_name version_start (candidate_name.count - version_start + 1)
            version_parts = wmcGetVersionParts version_text

            if version_parts != undefined then
            (
                if newest_path == undefined or wmcIsVersionNewer version_text newest_version then
                (
                    newest_path = candidate_path
                    newest_version = version_text
                )
            )
        )
    )

    newest_path
    -- return
)

/*
Loads the newest version of one WallMeshCleaner component from the loader directory.
Throws a clear error when no matching versioned component exists.
*/
function wmcLoadNewestComponent component_prefix =
(
    loader_directory = getFilenamePath WallMeshCleanerScriptPath
    component_path = wmcGetNewestVersionedFile loader_directory component_prefix

    if component_path == undefined then
    (
        throw ("WallMeshCleaner loader: no component found for " + component_prefix + "_*.ms")
    )

    format "WallMeshCleaner loader: %\n" component_path
    fileIn component_path
    component_path
    -- return
)

wmc_loaded_pipeline_path = wmcLoadNewestComponent "WallMeshCleaner-Pipeline"
wmc_loaded_core_path = wmcLoadNewestComponent "WallMeshCleaner-Core"
wmc_loaded_ui_path = wmcLoadNewestComponent "WallMeshCleaner-UI"

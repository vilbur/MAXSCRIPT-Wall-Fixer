/*
Tests WallMeshCleaner loader version resolution without changing component code.
Run WallMeshCleaner.ms first, then run this test file in 3ds Max.
*/

/*
Asserts one loader condition and throws when the condition is false.
Prints a PASS line for successful checks.
*/
function wmcAssertLoaderTest condition_value message_text =
(
    if condition_value then
    (
        format "PASS: %\n" message_text
        true
    )
    else
    (
        throw ("FAIL: " + message_text)
    )
    -- return
)

loader_directory = getFilenamePath WallMeshCleanerScriptPath
pipeline_path = wmcGetNewestVersionedFile loader_directory "WallMeshCleaner-Pipeline"
core_path = wmcGetNewestVersionedFile loader_directory "WallMeshCleaner-Core"
ui_path = wmcGetNewestVersionedFile loader_directory "WallMeshCleaner-UI"

wmcAssertLoaderTest (wmcIsVersionNewer "0.931" "0.930") "0.931 is newer than 0.930"
wmcAssertLoaderTest (wmcIsVersionNewer "0.1000" "0.930") "0.1000 is newer than 0.930"
wmcAssertLoaderTest (not (wmcIsVersionNewer "0.929" "0.930")) "0.929 is not newer than 0.930"
wmcAssertLoaderTest (pipeline_path != undefined) "Pipeline component is found"
wmcAssertLoaderTest (core_path != undefined) "Core component is found"
wmcAssertLoaderTest (ui_path != undefined) "UI component is found"
wmcAssertLoaderTest (wmc_loaded_pipeline_path == pipeline_path) "Loaded Pipeline is newest Pipeline"
wmcAssertLoaderTest (wmc_loaded_core_path == core_path) "Loaded Core is newest Core"
wmcAssertLoaderTest (wmc_loaded_ui_path == ui_path) "Loaded UI is newest UI"
wmcAssertLoaderTest (WallMeshCleaner != undefined) "Core instance exists after loader run"
wmcAssertLoaderTest (WallMeshCleaner.version == "0.930") "Core version is 0.930"
wmcAssertLoaderTest (WallMeshCleaner.getRestartScriptPath WallMeshCleanerScriptPath == WallMeshCleanerScriptPath) "Restart resolves to permanent WallMeshCleaner.ms loader"

format "WallMeshCleaner loader tests complete.\n"

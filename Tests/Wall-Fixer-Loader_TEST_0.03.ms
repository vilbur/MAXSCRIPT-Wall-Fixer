/*
Wall-Fixer bundled loader smoke test 0.03.
Project version 0.36. Run Wall-Fixer.ms first; this test does not modify scene geometry.
*/


global wall_fixer_loader_test_file_version = "0.03"
global wall_fixer_loader_test_tool_version = 0.36


/*
Asserts one bundled-loader smoke-test condition.
Successful checks are printed to the MAXScript Listener.
*/
function wallFixerAssertTest condition_value message_text =
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


wallFixerAssertTest (wall_fixer_loader_file_version == "0.30") "Bundled launcher file version is 0.30"
wallFixerAssertTest ((WallFixerVersion as float) >= 0.36) "Global project version is at least 0.36"
wallFixerAssertTest (wall_fixer_runtime_mode == #bundled) "Runtime mode is bundled"
wallFixerAssertTest (wall_fixer_pipeline_file_version == "0.22") "Pipeline source is bundled"
wallFixerAssertTest (wall_fixer_core_file_version == "0.22") "Core source is bundled"
wallFixerAssertTest (wall_fixer_ui_file_version == "0.27") "UI source is bundled"
wallFixerAssertTest (WallFixerRollout != undefined) "Wall-Fixer UI rollout exists"


format "Wall-Fixer bundled loader smoke tests complete.\n"
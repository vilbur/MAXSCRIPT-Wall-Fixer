/*
Wall-Fixer loader/UI smoke test 0.02.
Run Wall-Fixer.ms first, then evaluate this file; it does not modify scene geometry.
*/

/*
Asserts one Wall-Fixer smoke-test condition.
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

loader_directory = getFilenamePath WallFixerScriptPath
pipeline_path = findWallFixerComponent loader_directory "Wall-Fixer-Pipeline"
core_path = findWallFixerComponent loader_directory "Wall-Fixer-Core"
straight_edge_path = findWallFixerComponent loader_directory "Wall-Fixer-StraightEdge"
ui_path = findWallFixerComponent loader_directory "Wall-Fixer-UI"

wallFixerAssertTest (WallFixerLoaderVersion == "0.02") "Wall-Fixer loader version is 0.02"
wallFixerAssertTest (pipeline_path != undefined) "Pipeline component is found"
wallFixerAssertTest (core_path != undefined) "Core component is found"
wallFixerAssertTest (straight_edge_path != undefined) "Straight Edge support component is found"
wallFixerAssertTest (ui_path != undefined) "Wall-Fixer UI component is found"
wallFixerAssertTest (WallFixerLoadedPipelinePath == pipeline_path) "Loaded Pipeline is the newest available Pipeline"
wallFixerAssertTest (WallFixerLoadedCorePath == core_path) "Loaded Core is the newest available Core"
wallFixerAssertTest (WallFixerLoadedStraightEdgePath == straight_edge_path) "Loaded Straight Edge module is the newest available module"
wallFixerAssertTest (WallFixerLoadedUiPath == ui_path) "Loaded Wall-Fixer UI is the newest available UI"
wallFixerAssertTest (Wall-Fixer != undefined) "Core runtime exists"
wallFixerAssertTest (StraightEdgeFixer != undefined) "Straight Edge runtime exists"
wallFixerAssertTest (WallFixerRollout != undefined) "Wall-Fixer rollout exists"
wallFixerAssertTest (WallFixerVersion == "0.02") "Wall-Fixer UI version is 0.02"
wallFixerAssertTest (WallFixerRollout.workflow_progress.color == (color 0 180 0)) "Global progress bar is green"

format "Wall-Fixer loader/UI smoke tests complete.\n"

/*
Straight Edge Fixer 0.58 parser and loop-realignment smoke test.
Run this file from the Wall-Fixer Tests folder.
*/

/*
Loads the bundled Wall-Fixer script; reaching the PASS print proves the previous struct parser error is gone.
*/
function partOfTest1 =
(
    test_dir = getFilenamePath (getSourceFileName())
    wall_fixer_path = test_dir + "..\\Wall-Fixer.ms"

    if not doesFileExist wall_fixer_path then
    (
        throw ("Wall-Fixer.ms not found: " + wall_fixer_path)
    )

    fileIn wall_fixer_path
    format "PART 1 PASS: Wall-Fixer.ms parsed and loaded.\n"
    true
    -- return
)

/*
Runs the existing logical direction-loop regression used by the active fixSelectedDirectionEdges implementation.
*/
function partOfTest2 =
(
    test_passed = false

    if StraightEdgeFixer != undefined then
    (
        test_passed = StraightEdgeFixer.testDirectionLoopClusterRealignment()
    )

    format "PART 2 %: direction loop cluster realignment.\n" (if test_passed then "PASS" else "FAIL")
    test_passed
    -- return
)

partOfTest1()
partOfTest2()

format "UNDO ORDER: existing regression manages its own temporary test geometry.\n"

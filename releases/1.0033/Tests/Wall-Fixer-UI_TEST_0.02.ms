/*
Wall-Fixer UI 0.02 command-list test.
Reads the UI source only and does not modify scene geometry.
*/

/*
Reads a text file into one string for static label/order checks.
Returns undefined when the file cannot be opened.
*/
function readWallFixerTestFile file_path =
(
    file_stream = undefined
    file_text = ""

    try
    (
        file_stream = openFile file_path mode:"rt"
    )
    catch
    (
        file_stream = undefined
    )

    if file_stream == undefined then
    (
        undefined
    )
    else
    (
        while not eof file_stream do
        (
            file_text += (readLine file_stream) + "\n"
        )

        close file_stream
        file_text
    )
    -- return
)

/*
Checks required Wall-Fixer 0.02 workflow labels and their first-occurrence order.
The test is source-only and is safe to run in any scene.
*/
function testWallFixerUiCommandList ui_path =
(
    source_text = readWallFixerTestFile ui_path
    passed = true

    if source_text == undefined then
    (
        format "ERROR: Cannot read %\n" ui_path
        passed = false
    )
    else
    (
        expected_labels = #(
            "1. CHECK AND MAKE WALLS PLANAR",
            "2. VERTEX CHECK / WELD",
            "3. EXPLODE OBJECTS TO WALLS",
            "4. GET OUTTER WALLS",
            "5. FIND TWO-EDGE VERTS AND REMOVE",
            "6. EDGE Z-LEVEL FIXING AND BORDER EDGES CHECK",
            "7. FIX N-GONS",
            "8. CHECK RESULT",
            "9. SLICE SELECTED WALLS",
            "10. DUPLICATED VERTICES",
            "11. REMOVE REDUNDANT LOOPS AND EDGES",
            "12. COMPLETE / REPAIR MISSING LOOPS",
            "13. FIX N-GONS",
            "14. ATTACH WALLS TO OBJECTS",
            "15. WELD AND CONNECT WALL CORNERS"
        )

        previous_position = 0

        for label_text in expected_labels while passed do
        (
            label_position = findString source_text label_text

            if label_position == undefined then
            (
                format "ERROR: Missing label: %\n" label_text
                passed = false
            )
            else if label_position <= previous_position then
            (
                format "ERROR: Label out of order: %\n" label_text
                passed = false
            )
            else
            (
                previous_position = label_position
            )
        )

        if findString source_text "VISUAL CHECK" != undefined then
        (
            format "ERROR: Old VISUAL CHECK label still exists.\n"
            passed = false
        )

        if findString source_text "Wall-Fixer 0.02" == undefined then
        (
            format "ERROR: UI version 0.02 was not found.\n"
            passed = false
        )
    )

    if passed then
    (
        format "SUCCESS: Wall-Fixer UI 0.02 command-list test passed.\n"
    )

    passed
    -- return
)

test_folder = getFilenamePath (getSourceFileName())
test_ui_path = test_folder + "..\\Wall-Fixer-UI_0.02.ms"
testWallFixerUiCommandList test_ui_path

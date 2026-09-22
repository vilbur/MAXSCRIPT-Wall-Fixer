; Wall-Fixer deployment helper.
; Script version 1.3.
; Target: AutoHotkey 1.1.36.02.


#NoEnv
#SingleInstance Force
SetBatchLines, -1


wall_fixer_deploy_script_version := "1.3"


if (A_Args.MaxIndex() && (A_Args[1] = "--test"))
{
    test_passed := testDeployWallFixer()
    exit_code := test_passed ? 0 : 1
    ExitApp, %exit_code%
}


deployWallFixer(A_ScriptDir)
ExitApp




; Deploys the current Wall-Fixer project beside its source folder.
; The destination name is suffixed with the current tool version.
deployWallFixer(source_dir)
{
    tool_version := getWallFixerToolVersion(source_dir)


    if (tool_version = "")
    {
        MsgBox, 16, Wall-Fixer Deploy, Could not read the tool version from Wall-Fixer.ms.
        return false
    }


    destination_dir := getDeployDestination(source_dir, tool_version)


    if (destination_dir = "")
    {
        MsgBox, 16, Wall-Fixer Deploy, Could not build the deployment folder path.
        return false
    }


    if (FileExist(destination_dir))
    {
        MsgBox, 48, Wall-Fixer Deploy, Deployment already exists:`n`n%destination_dir%
        return false
    }


    if (!copyProjectWithoutGit(source_dir, destination_dir))
    {
        MsgBox, 16, Wall-Fixer Deploy, Deployment failed.`n`nSource:`n%source_dir%`n`nDestination:`n%destination_dir%
        return false
    }


    MsgBox, 64, Wall-Fixer Deploy, Deployed Wall-Fixer %tool_version%:`n`n%destination_dir%
    return true
}




; Reads the current shared tool version from the bundled Wall-Fixer.ms loader.
; The header Project version value is preferred, with the loader value as fallback.
getWallFixerToolVersion(source_dir)
{
    version_file := source_dir . "\Wall-Fixer.ms"


    if (!FileExist(version_file))
        return ""


    Loop, Read, %version_file%
    {
        if RegExMatch(A_LoopReadLine, "i)Project\s+version\s+([0-9]+\.[0-9]+)", match)
            return match1
    }


    Loop, Read, %version_file%
    {
        if RegExMatch(A_LoopReadLine, "i)wall_fixer_loader_tool_version\s*=\s*([0-9]+\.[0-9]+)", match)
            return match1
    }


    return ""
}




; Builds the sibling deployment path using <project-folder>_<tool-version>.
; Example: MAXSCRIPT-Wall-Fixer_0.xxx.
getDeployDestination(source_dir, tool_version)
{
    SplitPath, source_dir, project_name, parent_dir


    if ((project_name = "") || (parent_dir = "") || (tool_version = ""))
        return ""


    return parent_dir . "\" . project_name . "_" . tool_version
}




; Copies the full project tree while excluding only the .git directory.
; Robocopy success codes 0-7 are accepted; .gitignore and all other files remain included.
copyProjectWithoutGit(source_dir, destination_dir)
{
    if (!FileExist(source_dir))
        return false


    if (FileExist(destination_dir))
        return false


    robocopy_path := A_WinDir . "\System32\robocopy.exe"


    if (!FileExist(robocopy_path))
        return false


    command := quoteArgument(robocopy_path)
    command .= " " . quoteArgument(source_dir)
    command .= " " . quoteArgument(destination_dir)
    command .= " /E /COPY:DAT /DCOPY:DAT /R:1 /W:1"
    command .= " /XD " . quoteArgument(source_dir . "\.git")
    command .= " /NFL /NDL /NJH /NJS /NP"


    RunWait, %command%,, Hide UseErrorLevel
    robocopy_exit_code := ErrorLevel


    if (robocopy_exit_code = "ERROR")
        return false


    if (robocopy_exit_code >= 8)
        return false


    return FileExist(destination_dir) ? true : false
}




; Quotes one command-line argument for Windows paths containing spaces.
; The returned value includes the surrounding double quotes.
quoteArgument(value)
{
    return Chr(34) . value . Chr(34)
}




; Tests version parsing, sibling naming, full copying, and .git exclusion.
; Run with: Wall-Fixer-Deploy.ahk --test
testDeployWallFixer()
{
    test_id := A_TickCount
    source_dir := A_Temp . "\WallFixerDeployTest_" . test_id
    expected_version := "9.876"


    FileCreateDir, %source_dir%
    FileCreateDir, %source_dir%\Doc
    FileCreateDir, %source_dir%\.git


    FileAppend, Project version %expected_version%.`r`n, %source_dir%\Wall-Fixer.ms
    FileAppend, test`r`n, %source_dir%\Doc\readme.txt
    FileAppend, *.tmp`r`n, %source_dir%\.gitignore
    FileAppend, internal git data`r`n, %source_dir%\.git\config


    parsed_version := getWallFixerToolVersion(source_dir)
    destination_dir := getDeployDestination(source_dir, parsed_version)
    copied := copyProjectWithoutGit(source_dir, destination_dir)


    passed := true
    passed := passed && (parsed_version = expected_version)
    passed := passed && copied
    passed := passed && FileExist(destination_dir . "\Wall-Fixer.ms")
    passed := passed && FileExist(destination_dir . "\Doc\readme.txt")
    passed := passed && FileExist(destination_dir . "\.gitignore")
    passed := passed && !FileExist(destination_dir . "\.git")


    FileRemoveDir, %source_dir%, 1


    if (destination_dir != "")
        FileRemoveDir, %destination_dir%, 1


    if (passed)
        MsgBox, 64, Wall-Fixer Deploy Test, PASS - deployment copy and .git exclusion work as expected.
    else
        MsgBox, 16, Wall-Fixer Deploy Test, FAIL - one or more deployment checks failed.


    return passed
}
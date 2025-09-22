#Requires AutoHotkey v2

; Support for launching a file in an editor
; Currently only knows Notepad.
;
; You can choose an editor by setting the env var 'ahk_launch_myEditor'.
;
; Idea: Add the ability to look up a definition in the editor's tagging system.

; Ignore lineNumber for now. Could maybe implement by sending Ctrl-G (may need to wait) and then sending the line number + Enter.
launch_fileInNotepad(filename, lineNumber) {
    Run("notepad.exe " . filename)
}

launch_fileInVsCode(filename, lineNumber) {
    Run("code.cmd -g " . filename . ":" . lineNumber)
}


;
; General
;

findAndlaunch_fileInEditor(filename, lineNumber) {
    myEditor := get_editorForUser()
    launchFunc := "launch_fileIn" . myEditor

    if !FileExist(filename) {
        MsgBox("Not found: " . filename)
        return false
    }

    %launchFunc%(filename, lineNumber)
}

get_editorForUser() {
    myEditor := EnvGet("ahk_launch_myEditor")
    if (myEditor != "") {
        return myEditor
    }
    return "Notepad"
}

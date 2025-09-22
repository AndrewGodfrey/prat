#Requires AutoHotkey v2

select_lineUnderMouse() {
    ; Triple-click works in many apps (e.g. SlickEdit, Chrome, Outlook)
    Click(,3)
}

autolaunch_matchers := [almatcher_filenameAndLine, almatcher_knowledgeBaseArticle]

almatcher_filenameAndLine(&foundPos, input, &launcher) {
    if (accumulate_foundPos(&foundPos, match_filenameAndLine(input, &Filename, &LineNumber))) {
        thisLauncher() {
            findAndlaunch_fileInEditor(Filename, LineNumber)
        }
        launcher := thisLauncher
    }
}

almatcher_knowledgeBaseArticle(&foundPos, input, &launcher) {
    if (accumulate_foundPos(&foundPos, match_knowledgeBaseArticle(input, &KbId))) {
        thisLauncher() {
            launch_knowledgeBaseArticle(KbId)
        }
        launcher := thisLauncher
    }
}

autolaunch(normalizedInputString) {
    error_launcher() {
        MsgBox("Unrecognized input: " . normalizedInputString)
    }
    launcher := error_launcher
    foundPos := 0
 
    for (matcher in autolaunch_matchers) {
        matcher(&foundPos, normalizedInputString, &launcher)
    }

    launcher()
}

#Requires AutoHotkey v2

; accumulate_foundPos: Keeps track of the earliest match found.
accumulate_foundPos(&FoundPos, newPos) {
    if newPos > 0 {
        if ((FoundPos = 0) OR (newPos < FoundPos)) {
            FoundPos := newPos
            return true
        }
    }
    return false
}


; Test strings:
;     c:\foo\bar\file.cpp(53,32): error C2248:
match_filenameAndLine(normalizedInputString, &filename, &lineNumber) {
    foundPos := 0
    lineNumber := ""
    filename := ""

    ; Note: Doesn't recognize filenames having spaces.
    if (accumulate_foundPos(&foundPos, RegExMatch(normalizedInputString, "(?P<File>([\w]:)\\[\w~]+\\[\w\.\\]+)(?P<LineSection>(, line \d+| @ \d+|:\d+| ?\(\d+(,\d+)?\)))?", &Match))) {
        filename := Match.File
        if (RegExMatch(Match.LineSection, "(?P<Line>\d+)", &Match) > 0)
            lineNumber := Match.Line
    }

    if lineNumber = "" {
        lineNumber := 0
    }

    return foundPos
}

; Test strings:
;     KB5023773
match_knowledgeBaseArticle(normalizedInputString, &kbId) {
    FoundPos := 0

    if (accumulate_foundPos(&FoundPos, RegExMatch(NormalizedInputString, "KB(?P<Id>\d\d\d+)", &Match))) {
        kbId := Match.Id
    }

    return FoundPos
}



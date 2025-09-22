#Requires AutoHotkey v2

; Based off of source at: https://www.autohotkey.com/docs/Hotstrings.htm
; Credit: Andreas Borutta

normalizedSelection(StringFromClipboard) {
    Temp := StrReplace(StringFromClipboard, "``", "````")  ; Do this replacement first to avoid interfering with the others below.
    Temp := StrReplace(Temp, "`r`n", "`r")  ; Using `r works better than `n in MS Word, etc.
    Temp := StrReplace(Temp, "`n", "`r")
    Temp := StrReplace(Temp, A_Tab, "`t")
    Temp := StrReplace(Temp, "`;", "```;")  ; I REALLY don't get what this one is for.

    ; Trim the result.
    ;   Example: When I double-click the number in the following string in Outlook,
    ;   the trailing space is included, and breaks lookup if I don't trim it:
    ;   "Please refer to ICM 165955900 for further updates on the incident"

    Temp := Trim(Temp)

    return Temp
}

get_normalizedSelectionFromApp(&result) {
    ; Get the text currently selected. The clipboard is used instead of
    ;   "ControlGet Selected" because it works in a greater variety of editors
    ;   (namely word processors).

    ClipboardOld := ClipboardAll()
    A_Clipboard := "" ; Must start off blank for detection to work.
    Send("^c")
    waitResult := ClipWait(1)
    if waitResult = 0 ; ClipWait timed out.
        return false

    NormalizedInputString := normalizedSelection(A_Clipboard)

    A_Clipboard := ClipboardOld  ; Restore previous contents of clipboard.

    result := NormalizedInputString

    return true
}


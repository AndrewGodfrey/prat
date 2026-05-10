# Layer violation config for the 'prat' repo.
# Higher layers (prefs, de) may augment this config when scanning prat.
#
# Patterns are literal strings (case-insensitive). Assembled here to avoid the scanner
# flagging this config file itself.

@{
    bannedPatterns = @(
        @{
            pattern     = ("~" + "/de/")
            description = ("~" + "/de/") + " reference (home-de path — not available in standalone prat)"
        },
        @{
            pattern     = ("~" + "/prefs/")
            description = ("~" + "/prefs/") + " reference (prefs layer — not available in standalone prat)"
        }
    )
}

# Layer violation config for the 'prat' repo.
# Dot-source this file to get $pratLayerViolationsConfig for use with Find-LayerViolations.ps1.
# Higher layers (prefs, de) may augment this config when scanning prat.
#
# Patterns are literal strings (case-insensitive). Assembled here to avoid the scanner
# flagging this config file itself.

$pratLayerViolationsConfig = @{
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

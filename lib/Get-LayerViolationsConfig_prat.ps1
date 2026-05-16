# Layer violation config for the 'prat' repo.
# Higher layers contribute rules via augmentPrat in their own config files.
# Own bannedPatterns would need assembled strings to avoid self-flagging, but are currently empty.

@{
    bannedPatterns = @()
    excludedPaths  = @('auto/')
}

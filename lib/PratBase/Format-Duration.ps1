function Format-Duration([double] $sec) {
    switch ($true) {
        ($sec -lt 12)    { return "{0:F1}s"         -f $sec }
        ($sec -lt 60)    { return "{0:F0}s"         -f $sec }
        ($sec -lt 100)   { return "{0:F0}m {1:F0}s" -f ([Math]::Floor($sec / 60)), ($sec % 60) }
        ($sec -lt 720)   { return "{0:F1}m"         -f ($sec / 60) }
        ($sec -lt 3600)  { return "{0:F0}m"         -f [Math]::Round($sec / 60) }
        ($sec -lt 86400) { return "{0:F1}h"         -f ($sec / 3600) }
        default          { return "{0:F1}d"         -f ($sec / 86400) }
    }
}

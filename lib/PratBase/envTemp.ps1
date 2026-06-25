function _applyEnvVar($key, $value) {
    if ($null -eq $value) {
        Remove-Item "env:$key" -ErrorAction SilentlyContinue
    } else {
        Set-Item "env:$key" $value
    }
}

function Save-Env {
    param([string[]] $Names)
    $token = @{}
    foreach ($name in $Names) {
        $token[$name] = [System.Environment]::GetEnvironmentVariable($name)
    }
    return $token
}

function Set-EnvTemp {
    param([hashtable] $Vars)
    $token = Save-Env ([string[]] $Vars.Keys)
    foreach ($key in $Vars.Keys) {
        _applyEnvVar $key $Vars[$key]
    }
    return $token
}

function Restore-Env {
    param([hashtable] $Token)
    foreach ($key in $Token.Keys) {
        _applyEnvVar $key $Token[$key]
    }
}

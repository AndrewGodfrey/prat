# For the previous exception that was thrown, get the ScriptStackTrace

if ($error[0] -eq $null) { return }

# Select starting frame
$errorToShow = $error[0]
if ($errorToShow.GetType().Name -eq "ActionPreferenceStopException") {
    $errorToShow = $error[1]
}

# Find ErrorRecord
if ($errorToShow.GetType().Name -eq "ErrorRecord") {
    $errorRecord = $errorToShow
} else {
    $errorRecord = $errorToShow.ErrorRecord
}

return $errorRecord.ScriptStackTrace


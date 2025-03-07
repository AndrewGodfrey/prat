# .SYNOPSIS
# Gets the error statuses of the last command/script/Windows program etc.
#
# .NOTES
# Powershell has many ways of getting the error status of the last X. I need to observe them in order to make
# sense of them.
#
# One thing I know is that X varies - so e.g. 'dollarQuestionmark' may refer to a different command than 'mostRecentError' does.
return @{
    dollarQuestionmark = $?         # "Contains the execution status of the last operation. It contains TRUE if the last operation succeeded and FALSE if it failed."
    mostRecentError = $Error[0]
    lastExitCode = $LastExitCode    # "Contains the exit code of the last Windows-based program that was run."
    stackTrace = $StackTrace        # "Contains a stack trace for the most recent error."
    executionStatus = (get-history -count 1).ExecutionStatus 
}

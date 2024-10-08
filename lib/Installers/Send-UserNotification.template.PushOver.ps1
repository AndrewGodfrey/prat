param(
    [string] $message = ${throw "message needed"},
    [string] $app = "Testing",
    [ArgumentCompleter({
        [array] $suggestedValues = 'pushover,magic,intermission,classical,vibrate,none'.split(',') # See: https://pushover.net/api#sounds
        $suggestedValues -like "$($args[2])*"})]
    [string] $sound = "intermission",
    [switch] $nopIfNoAppToken = $false
)

[hashtable] $tokens = . '[TOKENFILE]'  # See installPushoverNotification for sample data for this file
$appToken = $tokens.apps.$app
if ($null -eq $appToken) {
    if ($nopIfNoAppToken) {
        return
    }
    throw "Unknown app '$app'"
}

$fullMessage = ("$message`n  ("+$env:ComputerName.ToLower() + ")" )

$uri = "https://api.pushover.net/1/messages.json"
$parameters = @{
  token = $appToken
  user = $tokens.user
  message = $fullMessage
  sound = $sound
}
$parameters | Invoke-RestMethod -Uri $uri -Method Post | Out-Null


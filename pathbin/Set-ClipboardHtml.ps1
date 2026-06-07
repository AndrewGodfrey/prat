# .SYNOPSIS
# Copy HTML to the clipboard so Teams, Outlook, Word, etc. render it as formatted content.
#
# Wraps the HTML in a CF_HTML envelope with correct byte offsets, and sets a UnicodeText fallback
# so apps that don't read HTML get something readable. Persists after this process exits.
#
# Examples:
#   Set-ClipboardHtml '<b>bold</b>'
#   Get-Content table.html -Raw | Set-ClipboardHtml
#   Set-ClipboardHtml -Html $html -Plain "fallback for non-HTML readers"
param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true, Position = 0)]
    [string] $Html,

    # Plain-text fallback. If omitted, derived by stripping tags + decoding HTML entities.
    [string] $Plain
)

function Get-HtmlPlainText {
    param([string] $Html)

    if ([string]::IsNullOrEmpty($Html)) { return '' }

    $stripped  = $Html -replace '<[^>]+>', ' '
    $decoded   = [System.Net.WebUtility]::HtmlDecode($stripped)
    $collapsed = $decoded -replace '\s+', ' '
    return $collapsed.Trim()
}

# Only run main logic when invoked directly (not dot-sourced for testing).
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Plain) {
        $Plain = Get-HtmlPlainText $Html
    }

    # Build the CF_HTML payload. Offsets are byte positions into the UTF-8-encoded payload from byte 0.
    $preFragment  = '<html><body><!--StartFragment-->'
    $postFragment = '<!--EndFragment--></body></html>'
    $headerTemplate = "Version:0.9`r`nStartHTML:{0:D10}`r`nEndHTML:{1:D10}`r`nStartFragment:{2:D10}`r`nEndFragment:{3:D10}`r`n"

    $utf8 = [System.Text.Encoding]::UTF8
    # Header length is constant: {0:D10} always emits exactly 10 ASCII chars.
    $headerLen     = ($headerTemplate -f 0, 0, 0, 0).Length
    $startHtml     = $headerLen
    $startFragment = $startHtml + $utf8.GetByteCount($preFragment)
    $endFragment   = $startFragment + $utf8.GetByteCount($Html)
    $endHtml       = $endFragment + $utf8.GetByteCount($postFragment)

    $cfHtml = ($headerTemplate -f $startHtml, $endHtml, $startFragment, $endFragment) +
              $preFragment + $Html + $postFragment

    # Windows clipboard requires an STA thread. PowerShell 7 defaults to MTA — run the clipboard call
    # on a dedicated STA runspace if we're not already STA. The `$true` flag to SetDataObject tells
    # Windows to retain the data after this process exits.
    $setClipboard = {
        param([string] $CfHtml, [string] $PlainText)
        Add-Type -AssemblyName System.Windows.Forms
        $dataObj = New-Object System.Windows.Forms.DataObject
        $dataObj.SetData([System.Windows.Forms.DataFormats]::Html, $CfHtml)
        $dataObj.SetData([System.Windows.Forms.DataFormats]::UnicodeText, $PlainText)
        [System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true)
    }

    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA') {
        & $setClipboard $cfHtml $Plain
    }
    else {
        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = [System.Threading.ApartmentState]::STA
        $rs.Open()
        try {
            $ps = [powershell]::Create()
            try {
                $ps.Runspace = $rs
                $null = $ps.AddScript($setClipboard).AddArgument($cfHtml).AddArgument($Plain)
                $null = $ps.Invoke()
                if ($ps.HadErrors) {
                    throw ($ps.Streams.Error | ForEach-Object { $_.ToString() }) -join "`n"
                }
            }
            finally { $ps.Dispose() }
        }
        finally { $rs.Close(); $rs.Dispose() }
    }
}

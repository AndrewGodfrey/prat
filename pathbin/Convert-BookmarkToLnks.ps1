# Used for moving links to hp.lnks. 
# Copy a link to the clipboard (e.g. from Firefox bookmarks), and then run this.

$aobj = Get-Clipboard -TextFormatType Html
$a = [System.String]::Join("`n", $aobj)
if ($a -match '<!--StartFragment--><A HREF="(?<link>.+)">(?<text>.+)</A>') {
   $result = ("`t[" + $Matches.text + "](" + $Matches.link + ")`r`n")
   Set-Clipboard $result
   Write-Host "Success"
}


# Used for moving links to hp.lnks. 
# Copy a link to the clipboard (e.g. from Firefox bookmarks), and then run this.

if ($PSVersiontable.PSEdition -eq "Core") {
   function getHtmlFromClipboard {
      Add-Type -AssemblyName System.Windows.Forms
      [System.Windows.Forms.Clipboard]::GetData("HTML Format")
   }
} else {
   function getHtmlFromClipboard {
      Get-Clipboard -TextFormatType Html
   }
}

$aobj = getHtmlFromClipboard
if ($null -ne $aobj) {
   $a = [System.String]::Join("`n", $aobj)
   if ($a -match '<!--StartFragment--><A HREF="(?<link>.+)">(?<text>.+)</A>') {
      $result = ("`t[" + $Matches.text + "](" + $Matches.link + ")`r`n")
      Set-Clipboard $result
      Write-Host "Success"
   }
}


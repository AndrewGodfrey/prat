# .SYNOPSIS
# Generates a custom browser home page, 'homePage.html', with useful search boxes and lists of links.
#
# The input consists of a hand-written HTML 'header', and then tables generated from a file like links_work.lnks.
# For example input files, see example\exampleHpHeader.html and example\exampleHp.lnks

function emitHtmlStart($title) {
    @"
<html>
<head> <title> $title </title>
    <style>
    td {font-family: "Calibri", sans-serif}
    tr {font-size: 85%}
    input {font-size: 85%}
    h3 {margin-bottom:7px;margin-top:12px}
    </style>

</head>

<body>
"@
}

function emitHtmlEnd {
    @"
</body>
</html>
"@
}

function startTable {
    # Indent everything with another outer table
    "<table width=`"100%`" cellspacing=`"0`" cellpadding=`"0`" border=`"0`">`n <tr>`n  <td width=`"10`"> </td> <td>`n"

    $script:table_cols = 5
    $script:table_col_width = 100 / $table_cols
    $script:table_current_col = 0
    "<table width=`"100%`">"
}

function emitEndTableRow {
    " </tr>"
}

function emitTableEntry($entry) {
    if ($script:table_current_col -eq 0) {
        " <tr>"
    }

    "  <td width=`"$table_col_width%`" valign=`"top`"> $entry </td>"
    $script:table_current_col++

    if ($script:table_current_col -ge $table_cols) {
        emitEndTableRow
        $script:table_current_col = 0
    }
}

function finishTable {
    if ($script:table_current_col -gt 0) {
        for ($i = $table_current_col; $i -lt $table_cols; $i++) {
            emitTableEntry "&nbsp;"
        }
    }

    "</table>"

    # Unindent
    "  </td>`n </tr>`n</table>"

    "`n`n"
}

function emitLinkList($cat) {
    # Heading
    $cell = "`n    <H3><A NAME=`"$cat`"> $cat</A> </H3>`n"
   
    # Links   
    foreach ($link in $catLinks[$cat]) {
        $desc = $linkDesc[$link]
        $cell += "     <A HREF=`"$link`">$desc</A><br>`n"
    }
    emitTableEntry $cell
}

function emitPage($title, $header) {
    emitHtmlStart $title
    Get-Content $header

    startTable   
    foreach ($cat in $categories.Keys) {
        emitLinkList $cat
    }
    finishTable
    emitHtmlEnd
}


function defineCat($cat, $lineNumber) {
   if ($categories[$cat] -ne $null) {
       throw "Duplicate category definition `"$cat`" at line $lineNumber"
   }
   $categories[$cat] = $True
}

function AddCatLink($cat, $link) {
    if ($catLinks[$cat] -eq $null) {
        $catLinks[$cat] = New-Object System.Collections.ArrayList
    }
    $catLinks[$cat].Add($link) | Out-Null
}

function parseLinksFile([string] $filename) {
    $lineNumber = 0
    $currCat = $null

    foreach ($line in (Get-Content $filename)) {
        $lineNumber++
        if ($line -match '^ *(#.*)?$') {
            # Ignore blank lines and comments
        } elseif ($line -match '^(.*):$') {
            $currCat = $matches[1]
            defineCat $currCat $lineNumber
        } elseif ($line -match '^\t\[(.*)\]\((.*)\) *$') {
            if ($currCat -eq $null) { throw "$filename($linenumber): Unknown category" }

            $newDesc = $matches[1]
            $newLink = $matches[2]
            if ($links[$newLink] -ne $null) { throw "$filename($linenumber): Duplicate link" }
            # Todo: Do a duplicate check on the link description.
            $links[$newLink] = 1
            $linkDesc[$newLink] = $newDesc
            AddCatLink $currCat $newLink
        } else {
            throw "$filename($linenumber): Unrecognized text `"$line`""
        }
    }
}

function New-CustomBrowserHomePage(
    [string] $linksFile,
    [string] $header,
    [string] $title,
    [string] $output
    ) {

    $categories = [ordered] @{}
    $linkDesc = [ordered] @{}
    $catLinks = [ordered] @{}
    $links = [ordered] @{}

    parseLinksFile $linksFile
    # Write-Host ($catLinks | Out-String)
    emitPage $title $header | Out-File -Encoding ASCII $output
}

# .PARAM $smbShareName
# If non-null, will create SMB share that points to $generatedFileDir. This is how I access it from my browser,
# but there may be better ways.
function Install-CustomBrowserHomePage($installationTracker, $tempDir, $inputDir, $generatedFileDir, $smbShareName) {
    $stage = $installationTracker.StartStage("CustomBrowserHomePage")

    $fn = "homePage.html"

    New-CustomBrowserHomePage -linksFile:$inputDir\hp.lnks -header:$inputDir\hpHeader.html -title:Home -output:"$tempDir\$fn"

    Install-File $stage $tempDir $generatedFileDir $fn

    if ($smbShareName -ne $null) {
        $userDomainName = $env:userdomain + "\" + $env:username
        Install-SmbShare $stage $smbShareName $generatedFileDir $userDomainName
    }

    $installationTracker.EndStage($stage)
}


# Source: Version 2.3.0 of: https://github.com/iRon7/ConvertTo-Expression
#         Downloaded around 2/9/2018. I see that (as of April 2024) the corresponding commit no longer exists; the closest
#         is version 2.2.7, commit 6e968392bb99ff790805066e7b596068e63ff84c (and that looks very close to what I downloaded).
#
# My changes from version 2.3.0:
# - Convert from a module to a function in PratBase
# - Remove aliases
# - Hide the $Iteration internal parameter
#
# Note: In April 2024, the author added a comment saying that that this project is deprecated, pointing instead to 
#       [this module](https://github.com/iRon7/ObjectGraphTools). It's also MIT-licensed, I just haven't had a reason to
#       update yet. I only use this to serialize some simple data structures, and for debugging.

<#
MIT License

Copyright (c) [2018] [Ronald Bode]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 
License source: https://github.com/iRon7/ConvertTo-Expression/blob/master/LICENSE.txt 
#> 

# 
# .VERSION 2.3.0
# .AUTHOR Ronald Bode (iRon)

	<#
		.SYNOPSIS
			Serializes an object to a PowerShell expression.

		.DESCRIPTION
			The ConvertTo-Expression cmdlet converts any object to
			a string in PowerShell Object Notation (PSON) format. The properties are
			converted to field names, the field values are converted to property values,
			and the methods are removed. You can then use the Invoke-Expression
            cmdlet to convert a PSON-formatted string to a PowerShell object, which
            is easily managed in Windows PowerShell.

		.PARAMETER InputObject
			Specifies the objects to convert to a PSON expression. Enter a variable that
			contains the objects, or type a command or expression that gets the objects.
			You can also pipe one or more objects to ConvertTo-Expression.

		.PARAMETER Depth
			Specifies how many levels of contained objects are included in the PSON
			representation. The default value is 9.

		.PARAMETER Expand
			Specifies till what level the contained objects are expanded over separate lines
			and indented according to the -Indentation and -IndentChar parameters.
			The default value is 9.
			
			A negative value will remove redundant spaces and compress the PSON expression to
			a single line (except for multiline strings).
			
			Xml documents and multiline strings are embedded in a "here string" and aligned
			to the left.
			
		.PARAMETER Indentation
			Specifies how many IndentChars to write for each level in the hierarchy.

		.PARAMETER IndentChar
			Specifies which character to use for indenting.

		.PARAMETER Type
			Defines how the explicite the object type is being parsed:

			-Type None
				No type information will be added to the (embedded) objects and values in
				the PSON string. This means that objects and values will be parsed to one
				of the following data types when reading them back with Invoke-Expression:
				a numeric value, a [String] ('...'), an [Array] (@(...)) or a [HashTable]
				(@{...}).

			-Type Native
				The original type prefix is added to the (embedded) objects and values in
				the PSON string. Note that most system (.Net) objects can’t be read back
				with Invoke-Expression, but -SetType Name can help to reveal (embedded)
				object types and hierarchies.

			-Type Cast (Default)
				The type prefix is only added to (embedded) objects and values when
				required and optimized for read back with Invoke-Expression by e.g.
				converting system (.Net) objects to PSCustomObject objects. Numeric values
				won't have a strict type and therefor parsed to the default type that fits
				the value when read back with Invoke-Expression.

			-Type Strict
				All (embedded) objects and values will have an explicit type prefix
				optimized for read back with Invoke-Expression by e.g. converting system
				(.Net) objects to PSCustomObject objects.

		.PARAMETER NewLine
			Specifies which characters to use for a new line. The default is defined by the
			operating system.

        .EXAMPLE 

			PS C:\>(Get-UICulture).Calendar | ConvertTo-Expression	# Convert a Calendar object to a PowerShell expression

			[PSCustomObject]@{
				'AlgorithmType' = 'SolarCalendar'
				'CalendarType' = 'Localized'
				'Eras' = 1
				'IsReadOnly' = $False
				'MaxSupportedDateTime' = [DateTime]'9999-12-31T23:59:59.9999999'
				'MinSupportedDateTime' = [DateTime]'0001-01-01T00:00:00.0000000'
				'TwoDigitYearMax' = 2029
			}

		.EXAMPLE 

			PS C:\>@{Account="User01";Domain="Domain01";Admin="True"} | ConvertTo-Expression -Expand -1	# Compress the PSON output

			@{'Admin'='True';'Account'='User01';'Domain'='Domain01'}


		.EXAMPLE 

			PS C:\>Get-Date | Select-Object -Property * | ConvertTo-Expression	# Convert an object to a PSON expression and to a PowerShell object

			[PSCustomObject]@{
				'Date' = [DateTime]'2018-01-09T00:00:00.0000000+01:00'
				'DateTime' = 'Tuesday, January 9, 2018 7:22:57 PM'
				'Day' = 9
				'DayOfWeek' = 'Tuesday'
				'DayOfYear' = 9
				'DisplayHint' = 'DateTime'
				'Hour' = 19
				'Kind' = 'Local'
				'Millisecond' = 671
				'Minute' = 22
				'Month' = 1
				'Second' = 57
				'Ticks' = 636511225776716485
				'TimeOfDay' = [TimeSpan]'19:22:57.6716485'
				'Year' = 2018
			}

			PS C:\>Get-Date | Select-Object -Property * | ConvertTo-Expression | Invoke-Expression

			Date        : 2018-01-09 12:00:00 AM
			DateTime    : Tuesday, January 9, 2018 7:27:43 PM
			Day         : 9
			DayOfWeek   : Tuesday
			DayOfYear   : 9
			DisplayHint : DateTime
			Hour        : 19
			Kind        : Local
			Millisecond : 76
			Minute      : 27
			Month       : 1
			Second      : 43
			Ticks       : 636511228630764893
			TimeOfDay   : 19:27:43.0764893
			Year        : 2018

		.EXAMPLE 

			PS C:\>WinInitProcess = Get-Process WinInit | ConvertTo-Expression	# Convert the WinInit Process to a PSON expression

		.EXAMPLE 

			PS C:\>Get-Host | ConvertTo-Expression -Depth 4	# Reveal complex object hierarchies

		.LINK
			Invoke-Expression (Alias ConvertFrom-Pson)
	#>

Function ConvertTo-Expression {
	[CmdletBinding()][OutputType([String])]Param (
		[Parameter(ValueFromPipeLine = $True)][Object[]]$InputObject, [Int]$Depth = 9, [Int]$Expand = 9,
		[Int]$Indentation = 1, [String]$IndentChar = "`t", [ValidateSet("None", "Native", "Cast", "Strict")][String]$TypePrefix = "Cast",
		[String]$NewLine = [System.Environment]::NewLine, [Int]$Iteration = 0
	)
	$PipeLine = $Input | ForEach-Object {$_}; If ($PipeLine) {$InputObject = $PipeLine}
	Function Iterate ($Value) {ConvertTo-Expression @(,$Value) $Depth $Expand $Indentation $IndentChar $TypePrefix $NewLine ($Iteration + 1)}
	Function Embed ($List, $Dictionary) {If ($Iteration -ge $Depth) {If ($Null -ne $Dictionary) {Return "@{}"} Else {Return "@()"}}
		$Items = ForEach ($Key in $List) {If ($Null -ne $Dictionary) {"'$Key'$Space=$Space" + (Iterate $Dictionary.$Key)} Else {Iterate $Key}}
		$Open, $Join, $Separator, $Close = If ($Null -ne $Dictionary) {"@{", ";$Space", "$LineUp$Tab", "}"} Else {"@(", ",$Space", ",$LineUp$Tab", ")"}
		$Open + (&{If (($Iteration -ge $Expand) -or (@($Items).Count -le 1)) {$Items -Join $Join} Else {"$LineUp$Tab$($Items -Join $Separator)$LineUp"}}) + $Close
	}
	$Object = If (@($InputObject).Count -eq 1) {@($InputObject)[0]} Else {$InputObject}
	If ($Null -eq $Object) {"`$Null"} Else {
		$Space = If ($Iteration -gt $Expand) {
			""
		} Else {
			" "
		}
		$Tab = $IndentChar * $Indentation; $LineUp = "$NewLine$($Tab * $Iteration)"
		$Type = $Object.GetType().Name; $Cast = $Null; $Enumerator = $Object.GetEnumerator.OverloadDefinitions
		$Expression = If ($Object -is [Boolean]) {
			If ($Object) {'$True'} Else {'$False'}
		} ElseIf ($Object -is [Char]) {
			$Cast = $Type; "'$Object'"
		} ElseIf ($Object -is [String]) {
			If ($Object -Match "[`r`n]") {
				"@'$NewLine$Object$NewLine'@$NewLine"
			} Else {
				"'$($Object.Replace('''', ''''''))'"
			}
		} ElseIf ($Object -is [DateTime]) {
			$Cast = $Type; "'$($Object.ToString('o'))'"
		} ElseIf ($Object -is [Scriptblock]) {
			"{$($Object.ToString())}"
		} ElseIf ($Object -is [TimeSpan] -or $Object -is [Version]) {
			$Cast = $Type; "'$Object'"
		} ElseIf ($Object -is [Enum]) {
			$Type = "String"; "'$($Object)'"
		} ElseIf ($Object -is [Xml]) {
			$Cast = "Xml"; $SW = New-Object System.IO.StringWriter; $XW = New-Object System.Xml.XmlTextWriter $SW
			$XW.Formatting = If ($Level -gt $Expand) {"None"} Else {"Indented"}; $XW.Indentation = $Indentation; $XW.IndentChar = $IndentChar
			$Object.WriteContentTo($XW); If ($Level -gt $Expand) {"'$SW'"} Else {"@'$NewLine$SW$NewLine'@$NewLine"}
		} ElseIf ($Object.GetType().Name -eq "DictionaryEntry" -or $Type -like "KeyValuePair*") {
			$Type = "Hashtable"; Embed $Object.Key @{$Object.Key = $Object.Value}
		} ElseIf ($Object.GetType().Name -eq "OrderedDictionary") {
			$Type = "Hashtable"; $Cast = "Ordered"; Embed $Object.Keys $Object
		} ElseIf ($Enumerator -match "[\W]IDictionaryEnumerator[\W]") {
			$Type = "Hashtable"; Embed $Object.Keys $Object
		} ElseIf ($Enumerator -match "[\W]IEnumerator[\W]" -or $Object.GetType().Name -eq "DataTable") {
			$Type = "Array"; Embed $Object
		} Else {
			$Property = $Object | Get-Member -Type Property
			If (!$Property) {
				$Property = $Object | Get-Member -Type NoteProperty
			}
			$Names = ForEach ($Name in ($Property | Select-Object -Expand "Name")) {
				$Object.PSObject.Properties |
				Where-Object {$_.Name -eq $Name -and $_.IsGettable} | Select-Object -Expand "Name"
			}
			If ($Property) {
				$Type = "PSCustomObject"; $Cast = $Type; Embed $Names $Object
			} Else {
				$Object
			}
		}
		Switch ($TypePrefix) {
			'None'  	{"$Expression"}
			'Native'	{"[$($Object.GetType().Name)]$Expression"}
			'Cast'  	{If ($Cast) {"[$Cast]$Expression"} Else {"$Expression"}}
			'Strict'	{If ($Cast) {"[$Cast]$Expression"} Else {"[$Type]$Expression"}}
		}
	}
}
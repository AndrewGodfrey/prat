# See daily_cleanManagedDirectories.ps1
param([switch] $AddRecommendedDirectories = $false)

@{ path = "$home\prat\auto\log"; days = 14 }

# Some more recommendations, you can opt in to this when you override this script.
if ($AddRecommendedDirectories) {
    # Symbol caches - they get put in various places. Once, I found all 5 of these on the same machine!
    @('x:\symbols', 'x:\symcache', 'c:\symbols', 'c:\symcache', 'c:\debuggers\sym') | 
        Foreach-Object { @{ path = $_; days = 180} }

    @{ path = "$env:userprofile\Downloads\"; days = 14 }
    @{ path = "C:\tmp"; days = 60 }
}



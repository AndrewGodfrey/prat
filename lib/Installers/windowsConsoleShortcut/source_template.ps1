# This just documents how template.bin was created.
# These steps were done on Windows 10 21H1

# Step 1: Create .lnk file. This produces a small .lnk that has no ConsoleDataBlock section.
$wshell = New-Object -comObject WScript.Shell
$link = $wshell.CreateShortcut("$PSScriptRoot\step1.lnk")
$link.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$link.Arguments = ""
$link.Description = ""
$link.WorkingDirectory = "C:\Windows\System32\drivers\etc"
$link.IconLocation = "%SystemRoot%\System32\shell32.dll, 173"
$link.Save()

# Then: Manually edit:
# - Clear the SID associated with Format ID 46588ae2-4cbc-4338-bbfc-139326986dce. (I think this is the SID of the .lnk creator?)
#   Change the SID to S-1-5-00-00000000-0000000000-0000000000-1001
# - Clear the machine name. Change it to 'xxxxx' etc.


# Step 2:
# - Copy step1.lnk to step2.lnk
# - Edit step2.lnk in Windows - change the font size to something else (I picked 42).
#   This triggered addition of a ConsoleDataBlock section and another property with Format ID 0c570607-0396-43de-9d61-e321d7df5026.
# - Copy step2.lnk to template.bin


# Step 3:
# During development, I also updated template.bin with the result of loading 'template.bin' in class ShellLink.Shortcut and saving it again.
# That caused lots of changes (to view: compare 'step2.lnk' against 'step3.lnk'), but Windows still seems happy with the result.
# Maybe it only reordered the fields. Note: While windows seems to be okay with it, it prefers a different ordering, that it imposes if I
# make a small edit to the link.


# note4.lnk: Just for reference. If I copy step3.lnk and edit the target to use an environment variable,
#   then I get a mess that's similar to what the EnvironmentDataBlock code creates.


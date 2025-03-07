rem Description: Launch a PowerShell script without any popup windows
rem Params: <pwd> <scriptFilename>

Dim Args,pwdForScript,scriptFile,shell,command
Set Arg = WScript.Arguments
pwdForScript = Arg(0)
scriptFile = Arg(1)
Set shell = CreateObject("WScript.Shell")

shell.CurrentDirectory = pwdForScript
command = "pwsh.exe -nologo -File " & scriptFile
shell.Run command,0,True

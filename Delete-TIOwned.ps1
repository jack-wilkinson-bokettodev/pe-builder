param(
	[Parameter(Mandatory=$true)]
	[string]$Path,
	
	[Parameter()]
	[switch]$Recurse = $false
)

if (Test-Path -PathType 'Leaf' -LiteralPath "${PSScriptRoot}\Tools\temp.cfg") {Remove-Item -LiteralPath "${PSScriptRoot}\Tools\temp.cfg" -Force}
if ($Recurse) {$rstring='-Recurse '} else {$rstring=''}
$config = @"
[General]
EXEFilename=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
CommandLine="Remove-Item -Path "${Path}" ${rstring}-Force"
WaitProcess=1
WindowState=1
RunAs=8
AutoRun=1
"@
$config | Out-File -LiteralPath "${PSScriptRoot}\Tools\temp.cfg"

Start-Process -Wait -FilePath "${PSScriptRoot}\Tools\AdvancedRun.exe" -ArgumentList @('/cfg',"${PSScriptRoot}\Tools\temp.cfg")
Remove-Item -LiteralPath "${PSScriptRoot}\Tools\temp.cfg"
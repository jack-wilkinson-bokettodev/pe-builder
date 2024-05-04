param(
	[Parameter()]
	[ValidateSet('AMD64')]
	[string]$Architecture	=	'AMD64',

	[Parameter()]
	[string]$Language		=	'en-gb',

	[Parameter(mandatory=$true)]
	[string]$BuildPath,

	[Parameter(mandatory=$true)]
	[string]$SourcePath,

	[Parameter()]
	[switch]$WIMOnly		=	[bool]0
)

Clear-Host
$MountDir = Join-Path $BuildPath 'mount'

$BuildDate = ([DateTime]::UTCNow).ToString('yyyy-MM-dd\THHmm\Zzz')
$DestBuildFolder = Join-Path $SourcePath (Join-Path '/Builds/' $BuildDate)
$LogFile = New-Item -Force -ItemType File -Path $DestBuildFolder -Name 'build.log'

. (Join-Path $PSScriptRoot '/modules.ps1')

$BuildTimer = [Diagnostics.Stopwatch]::StartNew()
Create-PE-Environment -Architecture $Architecture -Path $BuildPath -Rebuild

$Packages = @(
	'WinPE-FMAPI'
	'WinPE-EnhancedStorage'
	'WinPE-WMI'
	'WinPE-NetFX'
	'WinPE-Scripting'
	'WinPE-PowerShell'
	'WinPE-DismCmdlets'
	'WinPE-SecureBootCmdlets'
	'WinPE-StorageWMI'
)

Write-Log -Level 'INFO' -Message 'Mounting WinPE Image'
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @('/Mount-Wim',"/mountdir:`"${MountDir}`"","/WimFile:`"${BuildPath}\media\sources\boot.wim`"",'/index:1')
$p.WaitForExit()

Write-Log -Level 'INFO' -Message "Finding ($($Packages.Count)) WinPE Packages"
$DISMParams = @("/Image:`"${MountDir}`"",'/Add-Package')
foreach ($Package in $Packages)
{
	$DISMParams += Add-PE-Package -Architecture $Architecture -Language $Language -PEPath $BuildPath -Name $Package -ReturnArgs
}

Write-Log -Level 'INFO' -Message "Applying $($DISMParams.Count - 2) WinPE Packages"
Start-Process -Wait -NoNewWindow -FilePath 'dism.exe' -ArgumentList $DISMParams

Write-Log -Level 'INFO' -Message 'Setting WinPE Scratch Space to 512MB (Max)'
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @("/Image:`"${MountDir}`"",'/Set-ScratchSpace:512')
$p.WaitForExit()

Write-Log -Level 'INFO' -Message 'Committing Changes to WIM'
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @('/Commit-Wim',"/mountdir:`"${MountDir}`"")
$p.WaitForExit()

Write-Log -Level 'INFO' -Message 'Copying Source Files to WinPE Image'
Write-Log -Level 'INFO' -LogOnly -Message 'Copying "winpe.jpg"'
Copy-TIOwned -Path (Join-Path $SourcePath '/bg.jpg') -Destination (Join-Path $MountDir '/Windows/System32/winpe.jpg')
Write-Log -Level 'INFO' -LogOnly -Message 'Copying Delta Files'
Copy-Item -Path "${SourcePath}\Files\*" -Destination $MountDir -Force -Recurse

if ($Architecture -eq 'AMD64')
{
	Write-Log -Level 'INFO' -Message 'Removing Unused System Files to Optimize Size'
	Delete-TIOwned -Path (Join-Path $MountDir '/Windows/SysWOW64')
	Delete-TIOwned -Path (Join-Path $MountDir '/Windows/Microsoft.Net/Framework')
	Delete-TIOwned -Path (Join-Path $MountDir '/Windows/Microsoft.Net/assembly/GAC_32')
	Delete-TIOwnedbyFilter -Path (Join-Path $MountDir '/Windows/WinSxS/') -Filter 'wow64_*'
	Delete-TIOwnedbyFilter -Path (Join-Path $MountDir '/Windows/WinSxS/') -Filter 'x86_*'
}

Write-Log -Level 'INFO' -Message 'Applying Registry Changes'
reg.exe load 'HKEY_LOCAL_MACHINE\SOFTMOUNT' "$(Join-Path $MountDir '/Windows/System32/Config/SOFTWARE')" | Out-Null
$RegBasePath = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTMOUNT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace'
$ToRemove = @(
'{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'	#Desktop
'{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}'	#Music
'{088e3905-0323-4b02-9826-5d99428e115f}'	#Downloads
'{24ad3ad4-a569-4530-98e1-ab02f9417aa8}'	#Pictures
'{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}'	#Videos
'{d3162b92-9365-467a-956b-92703aca08af}'	#Documents
'{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'	#3D Objects
)
foreach ($Key in $ToRemove) {if (Test-Path -Path (Join-Path $RegBasePath $Key) -PathType 'Container') {Write-Log -Level 'INFO' -LogOnly -Message "Removing Key `"$(Join-Path $RegBasePath $Key)`""; Remove-Item -Path (Join-Path $RegBasePath $Key) -Force -Recurse}}
reg.exe unload 'HKEY_LOCAL_MACHINE\SOFTMOUNT' | Out-Null

Write-Log -Level 'INFO' -Message 'Cleaning Up WinPE Image'
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @("/image:`"${MountDir}`"", '/cleanup-image', '/startcomponentcleanup')
$p.WaitForExit()

Write-Log -Level 'INFO' -Message 'Unmounting WinPE Image'
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @('/Unmount-Wim',"/mountdir:`"${MountDir}`"",'/commit')
$p.WaitForExit()

Write-Log -Level 'INFO' -Message 'Optimizing WinPE Image'
$p = Start-Process -PassThru -NoNewWindow -FilePath (Join-Path (Join-Path $PSScriptRoot 'Tools') 'wimlib-imagex.exe') -ArgumentList @('optimize', "`"${BuildPath}\media\sources\boot.wim`"", '--recompress')
$p.WaitForExit()

if (!$WIMOnly)
{
	Write-Log -Level 'INFO' -Message 'Generating ISO'
	$ISOPath = Join-Path $BuildPath "WinPE_${BuildDate}.iso"
	Create-PE-ISO -BuildPath $BuildPath -Architecture $Architecture -SavePath $ISOPath
}

$BuildComplete = $BuildTimer.Elapsed.TotalSeconds

if (!$WIMOnly)
{
	Write-Log -Level 'INFO' -Message 'Copying Completed ISO'
	Copy-Item -Path (Join-Path $BuildPath "WinPE_${BuildDate}.iso")		-Destination (Join-Path $DestBuildFolder "WinPE_${BuildDate}.iso")	-Force
}
	Write-Log -Level 'INFO' -Message 'Copying Completed WIM'
	Copy-Item -Path (Join-Path $BuildPath '/media/sources/boot.wim')	-Destination (Join-Path $DestBuildFolder "boot.wim")								-Force

Write-Log -Level 'INFO' -Message "WinPE Build Completed in $([int]$BuildComplete) Seconds!"
$BuildTimer.Stop()

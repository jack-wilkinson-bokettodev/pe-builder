param(
	[Parameter()]
	[ValidateSet('AMD64')]
	[string]$Architecture	=	'AMD64',
	
	[Parameter()]
	[string]$Language		=	'en-gb',
	
	[Parameter(mandatory=$true)]
	[string]$BuildPath,
	
	[Parameter(mandatory=$true)]
	[string]$SourcePath
	
	[Parameter]
	[switch]$WIMOnly		=	[bool]0
)
#$BuildPath = 'C:\Users\tomo\Desktop\\build-test'

clear
$MountDir = Join-Path $BuildPath 'mount'
#Write-Host $MountDir

.\Create-PE-Environment.ps1 -Architecture $Architecture -Path $BuildPath -Rebuild

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
clear
Write-Host 'Mounting Image..' -foregroundcolor cyan -nonewline
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @('/Mount-Wim',"/mountdir:`"${MountDir}`"","/WimFile:`"${BuildPath}\media\sources\boot.wim`"",'/index:1')
$p.WaitForExit()
pause

clear
Write-Host 'Finding Packages..' -foregroundcolor cyan
$DISMParams = @("/Image:`"${MountDir}`"",'/Add-Package')
foreach ($Package in $Packages)
{
	$DISMParams += .\Add-PE-Package.ps1 -Architecture $Architecture -Language $Language -PEPath $BuildPath -Name $Package -ReturnArgs
}

clear
Write-Host 'Applying Packages..' -foregroundcolor cyan -nonewline
Start-Process -Wait -NoNewWindow -FilePath 'dism.exe' -ArgumentList $DISMParams
pause

clear
Write-Host 'Setting Scratch Space to 512MB..' -foregroundcolor cyan -nonewline
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @("/Image:`"${MountDir}`"",'/Set-ScratchSpace:512')
$p.WaitForExit()

clear
Write-Host 'Committing Changes to WIM..' -foregroundcolor cyan -nonewline
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @('/Commit-Wim',"/mountdir:`"${MountDir}`"")
$p.WaitForExit()

clear
Write-Host 'Copying Files to WinPE Image..' -foregroundcolor cyan
Write-Verbose "`tCopying Background"
.\Copy-TIOwned.ps1 -Path "${SourcePath}\bg.jpg" -Destination "${MountDir}\Windows\System32\winpe.jpg"
Write-Verbose "`tCopying Delta Files"
Copy-Item -Path "${SourcePath}\Files\*" -Destination $MountDir -Force -Recurse

if ($Architecture -eq 'AMD64')
{
	clear
	Write-Host 'Removing Unused System Files to Optimize Size..' -foregroundcolor cyan
	.\Delete-TIOwned.ps1 -Path "${MountDir}\Windows\SysWOW64" -Recurse
	.\Delete-TIOwned.ps1 -Path "${MountDir}\Windows\Microsoft.Net\Framework" -Recurse
	.\Delete-TIOwned.ps1 -Path "${MountDir}\Windows\Microsoft.Net\assembly\GAC_32" -Recurse
	.\Delete-TIOwnedbyFilter.ps1 -Path "${MountDir}\Windows\WinSxS\" -Filter 'wow64_*'
	.\Delete-TIOwnedbyFilter.ps1 -Path "${MountDir}\Windows\WinSxS\" -Filter 'x86_*'
}

clear
Write-Host 'Unmounting WinPE Image..' -foregroundcolor cyan -nonewline
$p = Start-Process -PassThru -NoNewWindow -FilePath 'dism.exe' -ArgumentList @('/Unmount-Wim',"/mountdir:`"${MountDir}`"",'/commit')
$p.WaitForExit()

clear
Write-Host 'WIM Build Completed!' -foregroundcolor green
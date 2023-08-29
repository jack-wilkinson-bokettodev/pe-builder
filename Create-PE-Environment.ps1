param(
	[Parameter()]
	[string]$Path,
	
	[Parameter()]
	[ValidateSet('AMD64','i686','ARM32','ARM64')]
	[string]$Architecture	=	'ARM64',
	
	[Parameter()]
	[switch]$Rebuild		=	$false
)
$PESourcesDir = Join-Path ${env:PROGRAMFILES(X86)} '\Windows Kits\10\Assessment and Deployment Kit'

#dicts to match less shit arch names with the source directories in the kit
$ArchDictPESource = @{
	'AMD64'		=	Join-Path $PESourcesDir '\Windows Preinstallation Environment\amd64'
	'i686'		=	Join-Path $PESourcesDir '\Windows Preinstallation Environment\x86'
	'ARM32'		=	Join-Path $PESourcesDir '\Windows Preinstallation Environment\arm'
	'ARM64'		=	Join-Path $PESourcesDir '\Windows Preinstallation Environment\arm64'
}
$ArchDictOSCDIMGSource = @{
	'AMD64'		=	Join-Path $PESourcesDir '\Deployment Tools\amd64\Oscdimg'
	'i686'		=	Join-Path $PESourcesDir '\Deployment Tools\x86\Oscdimg'
	'ARM32'		=	Join-Path $PESourcesDir '\Deployment Tools\arm\Oscdimg'
	'ARM64'		=	Join-Path $PESourcesDir '\Deployment Tools\arm64\Oscdimg'
}

#So I don't die inside every time I need these values.
$PESourceDir	= $ArchDictPeSource.${Architecture}
$OSCDIMGSource	= $ArchDictOSCDIMGSource.${Architecture}

#Source Path Definitions
$PEBootWim		= Join-Path $PESourceDir '\en-us\winpe.wim'
$PEMedia		= Join-Path $PESourceDir '\Media'
$PEPackageDir	= Join-Path $PESourceDir '\WinPe_OCs'

if (-Not (Test-Path -PathType Container -Path $PESourcesDir))	{Write-Warning 'Windows ADK Not Installed!';return $false}
if (-Not (Test-Path -PathType Container -Path $PESourceDir))	{Write-Warning 'PE Extension Missing from ADK!';return $false}
if (-Not (Test-Path -PathType Container -Path $OSCDIMGSource))	{Write-Warning 'OSCDIMG Missing from ADK!';return $false}

#Destination Path Definitions
$FirmwareFolder	= Join-Path $Path 'fwfiles'
$MediaFolder	= Join-Path $Path 'media'
$MountFolder	= Join-Path $Path 'mount'

#Ensures that a directory exists (if it does not, the directory will be created)
Function Ensure-Dir {
	[CmdletBinding()]
	param(
		[Parameter()]
		[string]$Path
	)
	if (-Not (Test-Path -PathType Container -LiteralPath $Path))
	{
		New-Item -ItemType Directory -Path $Path | Out-Null
		Write-Verbose "Directory `"${Path}`" Created"
		return
	} else {Write-Verbose "Directory `"${Path}`" Exists"; return}
}

#Deleting the working directory first if -Rebuild is specified.
if ((Test-Path -PathType Container -LiteralPath $Path) -And ($Rebuild))
{
	Write-Verbose 'Deleting Current Working Directory'
	Remove-Item -LiteralPath $Path -Force -Recurse
}

#Ensuring the destination directories have been made
Ensure-Dir -Path $Path
Ensure-Dir -Path $FirmwareFolder
Ensure-Dir -Path $MediaFolder
Ensure-Dir -Path "${MediaFolder}\sources"
Ensure-Dir -Path $MountFolder


Write-Host 'Copying Firmware Files..' -foregroundcolor cyan

Write-Verbose 'Copying efisys.bin'
Copy-Item -LiteralPath "${OSCDIMGSource}\efisys.bin" -Destination "${FirmwareFolder}\efisys.bin"

if (($Architecture -eq 'AMD64') -Or ($Architecture -eq 'i686'))
{
	#Appears to be for legacy systems?
	Write-Verbose 'Copying etfsboot.com'
	Copy-Item -LiteralPath "${OSCDIMGSource}\etfsboot.com" -Destination "${FirmwareFolder}\etfsboot.com" -Force
}

Write-Host 'Firmware Files Copied.' -foregroundcolor green



Write-Host 'Copying Media Files..' -foregroundcolor cyan
Write-Verbose 'Copying General Media Files'
Write-Verbose "PEMedia = ${PEMedia}"
Copy-Item -Path "${PEMedia}\*" -Exclude 'BCDTemplate' -Destination "${MediaFolder}" -Recurse -Force
Write-Verbose 'Copying boot.wim'
Copy-Item -LiteralPath $PEBootWim -Destination "${MediaFolder}\sources\boot.wim" -Force
Write-Host 'Media Files Copied.' -foregroundcolor green
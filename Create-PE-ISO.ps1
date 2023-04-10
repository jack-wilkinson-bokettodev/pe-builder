param(
	[Parameter(mandatory=$true)]
	[string]$BuildPath,
	
	[Parameter()]
	[ValidateSet('AMD64','i686','ARM32','ARM64')]
	[string]$Architecture	=	'ARM64',
	
	[Parameter(mandatory=$true)]
	[string]$SavePath
)

$PESourcesDir = Join-Path ${env:PROGRAMFILES(X86)} '\Windows Kits\10\Assessment and Deployment Kit'

$ArchDictOSCDIMGSource = @{
	'AMD64'		=	Join-Path $PESourcesDir '\Deployment Tools\amd64\Oscdimg'
	'i686'		=	Join-Path $PESourcesDir '\Deployment Tools\x86\Oscdimg'
	'ARM32'		=	Join-Path $PESourcesDir '\Deployment Tools\arm\Oscdimg'
	'ARM64'		=	Join-Path $PESourcesDir '\Deployment Tools\arm64\Oscdimg'
}

$BuildMediaDir		=	Join-Path $BuildPath	'/media'
$BuildFWDir			=	Join-Path $BuildPath	'/fwfiles'
$BuildFW_ETFSBoot	=	Join-Path $BuildFWDir	'/etfsboot.com'
$BuildFW_EFISys		=	Join-Path $BuildFWDir	'/efisys.bin'

$OSCDIMGSource = $ArchDictOSCDIMGSource.${Architecture}
$OSCDIMGExe		= Join-Path $OSCDIMGSource '\OSCDIMG.EXE'

if (-Not (Test-Path -PathType Container -Path $PESourcesDir))	{Write-Warning 'Windows ADK Not Installed!';return $false}
if (-Not (Test-Path -PathType Container -Path $OSCDIMGSource))	{Write-Warning 'OSCDIMG Missing from ADK!';return $false}
if (-Not (Test-Path -PathType Leaf -Path $OSCDIMGExe))			{Write-Warning 'OSCDIMG.EXE Missing from ADK!';return $false}
if (-Not (Test-Path -PathType Container -Path $BuildMediaDir))	{Write-Warning '"/media" Folder Missing from Build Directory!';return $false}
if (-Not (Test-Path -PathType Container -Path $BuildFWDir))		{Write-Warning '"/fwfiles" Folder Missing from Build Directory!';return $false}
if (-Not (Test-Path -PathType Leaf -Path $BuildFW_ETFSBoot))	{Write-Warning '"etfsboot.com" Missing from "/fwfiles" Directory!';return $false}
if (-Not (Test-Path -PathType Leaf -Path $BuildFW_EFISys))		{Write-Warning '"efisys.bin" Missing from "/fwfiles" Directory!';return $false}

#not needed lole
#$TempDir = New-Item -ItemType Container -Path (Join-Path $env:temp "{$([System.GUID]::NewGUID().GUID)}") -Force

if (Test-Path -PathType Leaf -Path $SavePath) {Remove-Item -Path $SavePath -Force}

$p = Start-Process -FilePath $OSCDIMGExe -Verb runas -PassThru -ArgumentList @('-m','-o','-u2','-udfver102',"-bootdata:2`#p0,e,b${BuildFW_ETFSBoot}`#pEF,e,b${BuildFW_EFISys}","${BuildMediaDir}","${SavePath}")
$p.WaitForExit()
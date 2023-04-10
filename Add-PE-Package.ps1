param(
	[Parameter()]
	[ValidateSet('AMD64','i686','ARM32','ARM64')]
	[string]$Architecture	=	'ARM64',
	
	[Parameter()]
	[string]$Language		=	'en-gb',
	
	[Parameter(mandatory=$true)]
	[string]$Name,
	
	[Parameter(mandatory=$true)]
	[string]$PEPath,
	
	[Parameter()]
	[switch]$ReturnArgs		=	$false
)

$MountDir = Join-Path $PEPath 'mount'

class InvalidMountDir: System.Exception {
	InvalidMountDir([string]$x) :
		base ("The Path `"${$MountDir}\mount`" is an Invalid MountDir.") {}
}

class InvalidPackageCount: System.Exception {
	InvalidPackageCount([string]$x) :
		base ("Invalid Number of Packages Returned from Get-Pe-Package. (${x})") {}
}

$PackageRes = .\Get-PE-Package.ps1 -Architecture $Architecture -Language $Language -Name $Name

if (Test-Path -PathType 'Container' -LiteralPath $Mountdir)
{
	$baseArgs = @("/Image:`"${$MountDir}\mount`"",'/Add-Package')
	$addArgs = @()
	if ($PackageRes.Count -eq 1)
	{
		$addArgs += "/PackagePath:`"$($PackageRes.NeutralPackage)`""
	} elseif ($PackageRes.Count -eq 2)
	{
		$addArgs += "/PackagePath:`"$($PackageRes.NeutralPackage)`""
		$addArgs += "/PackagePath:`"$($PackageRes.SpecificPackage)`""
	} else {Throw [InvalidPackageCount] $PackageRes.Count}
	$finalArgs = $baseArgs + $addArgs
	if (-Not $ReturnArgs)
	{
		Start-Process -Wait -NoNewWindow -FilePath 'dism.exe' -ArgumentList $finalArgs
	} else {
		return $addArgs
	}
} else {Throw [InvalidMountDir] $MountDir}
class InvalidMountDir: System.Exception {
	InvalidMountDir([string]$x) :
		base ("The Path `"${$MountDir}\mount`" is an Invalid MountDir.") {}
}

class InvalidPackageCount: System.Exception {
	InvalidPackageCount([string]$x) :
		base ("Invalid Number of Packages Returned from Get-Pe-Package. (${x})") {}
}

class InvalidLanguage: System.Exception {
	InvalidLanguage([string]$x) :
		base ("`"${x}`" Is not a valid language.") {}
}

class InvalidPackage: System.Exception {
	InvalidPackage([string]$x) :
		base ("The package `"${x}`" Does not exist.") {}
}

#Needed for taking ownership of TrustedInstaller files
$AdjustTokenPrivileges = 'using System;using System.Runtime.InteropServices;public class TokenManipulator {[DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true)] internal static extern bool AdjustTokenPrivileges(IntPtr htok,bool disall,ref TokPriv1Luid newst,int len,IntPtr prev,IntPtr relen);[DllImport("kernel32.dll",ExactSpelling=true)] internal static extern IntPtr GetCurrentProcess();[DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true)] internal static extern bool OpenProcessToken(IntPtr h,int acc,ref IntPtr phtok);[DllImport("advapi32.dll",SetLastError=true)] internal static extern bool LookupPrivilegeValue(string host,string name,ref long pluid);[StructLayout(LayoutKind.Sequential,Pack=1)] internal struct TokPriv1Luid {public int Count;public long Luid;public int Attr;} internal const int SE_PRIVILEGE_DISABLED=0x00000000; internal const int SE_PRIVILEGE_ENABLED=0x00000002;internal const int TOKEN_QUERY=0x00000008;internal const int TOKEN_ADJUST_PRIVILEGES=0x00000020;public static bool AddPrivilege(string privilege) {try {bool retVal;TokPriv1Luid tp;IntPtr hproc=GetCurrentProcess();IntPtr htok=IntPtr.Zero;retVal=OpenProcessToken(hproc,TOKEN_ADJUST_PRIVILEGES|TOKEN_QUERY,ref htok);tp.Count=1;tp.Luid=0;tp.Attr=SE_PRIVILEGE_ENABLED;retVal=LookupPrivilegeValue(null,privilege,ref tp.Luid);retVal=AdjustTokenPrivileges(htok,false,ref tp,0,IntPtr.Zero,IntPtr.Zero);return retVal;} catch (Exception ex) {throw ex;}}}'
try {Add-Type -TypeDefinition $AdjustTokenPrivileges -Language CSharp -ErrorAction SilentlyContinue} catch {} #It refuses to use to ErrorAction for no good reason.
[void][TokenManipulator]::AddPrivilege("SeRestorePrivilege")
[void][TokenManipulator]::AddPrivilege("SeBackupPrivilege")
[void][TokenManipulator]::AddPrivilege("SeTakeOwnershipPrivilege")
$TrustedInstaller = [System.Security.Principal.SecurityIdentifier]::New('S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464').Translate([System.Security.Principal.NTAccount])
$Administrators = [System.Security.Principal.SecurityIdentifier]::New('S-1-5-32-544').Translate([System.Security.Principal.NTAccount])
$FSAR = [System.Security.AccessControl.FileSystemAccessRule]::New($Administrators, [System.Security.AccessControl.FileSystemRights]::Write, [System.Security.AccessControl.InheritanceFlags]::None, [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Allow)

$esc = [char]27
$ConsoleTags = @{'INFO'="${esc}[96m[INFO]${esc}[0m"; 'WARN'="${esc}[93m[WARN]${esc}[0m"; 'ERROR'="${esc}[91m[ERROR]${esc}[0m"}
Function Write-Log
{
	param(
		[Parameter(mandatory=$true)][ValidateSet('INFO','WARN','ERROR')][string]$Level,
		[Parameter(mandatory=$true)][string]$Message,
		[Parameter()][switch]$LogOnly = $false
	)

	$TimerString = ($BuildTimer.Elapsed.TotalSeconds).ToString('000.000')
	Add-Content -Path $LogFile -Value "[${TimerString}][${Level}] ${Message}"
	if (!$LogOnly) {[Console]::WriteLine("[${TimerString}]$($ConsoleTags[$Level]) ${Message}")}
}

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
		Write-Log -Level 'INFO' -LogOnly -Message "Directory `"${Path}`" Created"
		return
	} else {Write-Log -Level 'INFO' -LogOnly -Message "Directory `"${Path}`" Exists"; return}
}

Function Add-PE-Package
{
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

	$PackageRes = Get-PE-Package -Architecture $Architecture -Language $Language -Name $Name

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
			Write-Log -Level 'INFO' -LogOnly -Message "Started DISM to Apply Package `"${Name}`""
			Start-Process -Wait -NoNewWindow -FilePath 'dism.exe' -ArgumentList $finalArgs
			Write-Log -Level 'INFO' -LogOnly -Message 'DISM Exited'
		} else {
			return $addArgs
		}
	} else {Throw [InvalidMountDir] $MountDir}
}

Function Copy-TIOwned
{
	param(
		[Parameter(Mandatory=$true)][string]$Path,
		[Parameter(Mandatory=$true)][string]$Destination
	)

	Write-Log -Level 'INFO' -LogOnly -Message "Setting Administrators Ownership for `"${Destination}`""
	$ACL = [System.IO.File]::GetAccessControl($Destination, [System.Security.AccessControl.AccessControlSections]::All)
	$ACL.SetOwner($Administrators); $ACL.AddAccessRule($FSAR)
	[System.IO.File]::SetAccessControl($Destination, $ACL)

	Write-Log -Level 'INFO' -LogOnly -Message "Copying `"${Path}`" to `"${Destination}`""
	Copy-Item -Path $Path -Destination $Destination

	Write-Log -Level 'INFO' -LogOnly -Message "Setting TrustedInstaller Ownership for `"${Destination}`""
	$ACL.SetOwner($TrustedInstaller); [void]$ACL.RemoveAccessRule($FSAR)
	[System.IO.File]::SetAccessControl($Destination, $ACL)
}

Function Create-PE-Environment
{
	param(
		[Parameter()]
		[string]$Path,

		[Parameter()]
		[ValidateSet('AMD64','i686','ARM32','ARM64')]
		[string]$Architecture	=	'ARM64',

		[Parameter()]
		[switch]$Rebuild		=	$false
	)
	Write-Log -Level 'INFO' -LogOnly -Message 'Finding Files to Create PE Environment'
	$PESourcesDir = Join-Path ${env:PROGRAMFILES(X86)} '/Windows Kits/10/Assessment and Deployment Kit'

	#dicts to match less shit arch names with the source directories in the kit
	$ArchDictPESource = @{
		'AMD64'		=	Join-Path $PESourcesDir '/Windows Preinstallation Environment/amd64'
		'i686'		=	Join-Path $PESourcesDir '/Windows Preinstallation Environment/x86'
		'ARM32'		=	Join-Path $PESourcesDir '/Windows Preinstallation Environment/arm'
		'ARM64'		=	Join-Path $PESourcesDir '/Windows Preinstallation Environment/arm64'
	}
	$ArchDictOSCDIMGSource = @{
		'AMD64'		=	Join-Path $PESourcesDir '/Deployment Tools/amd64/Oscdimg'
		'i686'		=	Join-Path $PESourcesDir '/Deployment Tools/x86/Oscdimg'
		'ARM32'		=	Join-Path $PESourcesDir '/Deployment Tools/arm/Oscdimg'
		'ARM64'		=	Join-Path $PESourcesDir '/Deployment Tools/arm64/Oscdimg'
	}

	#So I don't die inside every time I need these values.
	$PESourceDir	= $ArchDictPeSource.${Architecture}
	$OSCDIMGSource	= $ArchDictOSCDIMGSource.${Architecture}

	#Source Path Definitions
	$PEBootWim		= Join-Path $PESourceDir '/en-us/winpe.wim'
	$PEMedia		= Join-Path $PESourceDir '/Media'
	$PEPackageDir	= Join-Path $PESourceDir '/WinPe_OCs'

	if (-Not (Test-Path -PathType Container -Path $PESourcesDir))		{Write-Log -Level 'WARN' -Message 'Windows ADK Not Installed!';return $false}
	if (-Not (Test-Path -PathType Container -Path $PESourceDir))		{Write-Log -Level 'WARN' -Message 'PE Extension Missing from ADK!';return $false}
	if (-Not (Test-Path -PathType Container -Path $OSCDIMGSource))	{Write-Log -Level 'WARN' -Message 'OSCDIMG Missing from ADK!';return $false}

	#Destination Path Definitions
	$FirmwareFolder	= Join-Path $Path 'fwfiles'
	$MediaFolder	= Join-Path $Path 'media'
	$MountFolder	= Join-Path $Path 'mount'

	#Deleting the working directory first if -Rebuild is specified.
	if ((Test-Path -PathType Container -LiteralPath $Path) -And ($Rebuild))
	{
		Write-Log -Level 'INFO' -LogOnly -Message 'Deleting Current Working Directory'
		Remove-Item -LiteralPath $Path -Force -Recurse
	}

	#Ensuring the destination directories have been made
	Ensure-Dir -Path $Path
	Ensure-Dir -Path $FirmwareFolder
	Ensure-Dir -Path $MediaFolder
	Ensure-Dir -Path "${MediaFolder}/sources"
	Ensure-Dir -Path $MountFolder


	Write-Log -Level 'INFO' -Message 'Copying Firmware Files for WinPE'

	Write-Log -Level 'INFO' -LogOnly -Message 'Copying "efisys.bin"'
	Copy-Item -Path "${OSCDIMGSource}\efisys.bin" -Destination "${FirmwareFolder}\efisys.bin"

	if (($Architecture -eq 'AMD64') -Or ($Architecture -eq 'i686'))
	{
		#Appears to be for legacy systems?
		Write-Log -Level 'INFO' -LogOnly -Message 'Copying "etfsboot.com"'
		Copy-Item -Path "${OSCDIMGSource}/etfsboot.com" -Destination "${FirmwareFolder}\etfsboot.com" -Force
	}

	Write-Log -Level 'INFO' -Message 'Firmware Files Copied'



	Write-Log -Level 'INFO' -Message 'Copying Media Files for WinPE'
	Copy-Item -Path "${PEMedia}\*" -Exclude 'BCDTemplate' -Destination "${MediaFolder}" -Recurse -Force
	Write-Log -Level 'INFO' -LogOnly -Message 'Copying "boot.wim" to Media Folder'
	Copy-Item -LiteralPath $PEBootWim -Destination "${MediaFolder}\sources\boot.wim" -Force
	Write-Log -Level 'INFO' -Message 'Media Files Copied'
}

Function Create-PE-ISO
{
	param(
		[Parameter(mandatory=$true)]
		[string]$BuildPath,

		[Parameter()]
		[ValidateSet('AMD64','i686','ARM32','ARM64')]
		[string]$Architecture	=	'ARM64',

		[Parameter(mandatory=$true)]
		[string]$SavePath
	)

	$PESourcesDir = Join-Path ${env:PROGRAMFILES(X86)} '/Windows Kits/10/Assessment and Deployment Kit'

	$ArchDictOSCDIMGSource = @{
		'AMD64'		=	Join-Path $PESourcesDir '/Deployment Tools/amd64/Oscdimg'
		'i686'		=	Join-Path $PESourcesDir '/Deployment Tools/x86/Oscdimg'
		'ARM32'		=	Join-Path $PESourcesDir '/Deployment Tools/arm/Oscdimg'
		'ARM64'		=	Join-Path $PESourcesDir '/Deployment Tools/arm64/Oscdimg'
	}

	$BuildMediaDir		=	Join-Path $BuildPath	'/media'
	$BuildFWDir			=	Join-Path $BuildPath	'/fwfiles'
	$BuildFW_ETFSBoot	=	Join-Path $BuildFWDir	'/etfsboot.com'
	$BuildFW_EFISys		=	Join-Path $BuildFWDir	'/efisys.bin'

	$OSCDIMGSource = $ArchDictOSCDIMGSource.${Architecture}
	$OSCDIMGExe		= Join-Path $OSCDIMGSource '/OSCDIMG.EXE'

	if (-Not (Test-Path -PathType Container -Path $PESourcesDir))		{Write-Log -Level 'WARN' -Message 'Windows ADK Not Installed!';			return $false}
	if (-Not (Test-Path -PathType Container -Path $OSCDIMGSource))	{Write-Log -Level 'WARN' -Message 'OSCDIMG Missing from ADK!';			return $false}
	if (-Not (Test-Path -PathType Leaf -Path $OSCDIMGExe))					{Write-Log -Level 'WARN' -Message 'OSCDIMG.EXE Missing from ADK!';	return $false}
	if (-Not (Test-Path -PathType Container -Path $BuildMediaDir))	{Write-Log -Level 'WARN' -Message '"/media" Folder Missing from Build Directory!';			return $false}
	if (-Not (Test-Path -PathType Container -Path $BuildFWDir))			{Write-Log -Level 'WARN' -Message '"/fwfiles" Folder Missing from Build Directory!';		return $false}
	if (-Not (Test-Path -PathType Leaf -Path $BuildFW_ETFSBoot))		{Write-Log -Level 'WARN' -Message '"etfsboot.com" Missing from "/fwfiles" Directory!';	return $false}
	if (-Not (Test-Path -PathType Leaf -Path $BuildFW_EFISys))			{Write-Log -Level 'WARN' -Message '"efisys.bin" Missing from "/fwfiles" Directory!';		return $false}

	if (Test-Path -PathType Leaf -Path $SavePath) {Remove-Item -Path $SavePath -Force}

	Write-Log -Level 'INFO' -LogOnly -Message 'Starting oscdimg.exe to Create ISO'
	$p = Start-Process -FilePath $OSCDIMGExe -NoNewWindow -PassThru -ArgumentList @('-m','-o','-u2','-udfver102',"-bootdata:2`#p0,e,b${BuildFW_ETFSBoot}`#pEF,e,b${BuildFW_EFISys}","${BuildMediaDir}","${SavePath}")
	$p.WaitForExit()
}

Function Delete-TIOwned
{
	param([Parameter(Mandatory=$true)][string]$Path)

	Write-Log -Level 'INFO' -LogOnly -Message "Setting Administrators Ownership for `"${Path}`""
	$ACL = [System.IO.File]::GetAccessControl($Path, [System.Security.AccessControl.AccessControlSections]::All)
	$ACL.SetOwner($Administrators)
	[System.IO.File]::SetAccessControl($Path, $ACL)

	Write-Log -Level 'INFO' -LogOnly -Message "Deleting `"${Path}`""
	$Item = Get-Item -Path $Path
	if ($Item.GetType() -EQ [System.IO.FileInfo]) {Write-Log -Level 'INFO' -LogOnly -Message "Deleting File `"$($Item.FullName)`""; Remove-Item -Path $Item.FullName -Force; return}
	Get-ChildItem -Path $Path -Recurse -File			| % {Write-Log -Level 'INFO' -LogOnly -Message "Deleting File `"$($_.FullName)`""; Remove-Item -Path $_.FullName -Force}
	Get-ChildItem -Path $Path -Recurse -Directory	| % {Write-Log -Level 'INFO' -LogOnly -Message "Deleting Folder `"$($_.FullName)`""; Remove-Item -Path $_.FullName -Force -Recurse}
}

Function Delete-TIOwnedbyFilter
{
	param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)][string]$Filter)

	Write-Log -Level 'INFO' -LogOnly -Message "Setting Administrators Ownership for `"${Path}`""
	$ACL = [System.IO.File]::GetAccessControl($Path, [System.Security.AccessControl.AccessControlSections]::All)
	$ACL.SetOwner($Administrators)
	[System.IO.File]::SetAccessControl($Path, $ACL)

	Write-Log -Level 'INFO' -LogOnly -Message "Deleting `"${Path}`" with Filter `"${Filter}`""
	Get-ChildItem -Path $Path -Filter $Filter -Recurse -File			| % {Write-Log -Level 'INFO' -LogOnly -Message "Deleting File `"$($_.FullName)`""; Remove-Item -Path $_.FullName -Force}
	Get-ChildItem -Path $Path -Filter $Filter -Recurse -Directory	| % {Write-Log -Level 'INFO' -LogOnly -Message "Deleting File `"$($_.FullName)`""; Remove-Item -Path $_.FullName -Force -Recurse}
}

Function Get-PE-Package
{
	param(
		[Parameter()]
		[ValidateSet('AMD64','i686','ARM32','ARM64')]
		[string]$Architecture	=	'ARM64',

		[Parameter()]
		[string]$Language		=	'en-gb',

		[Parameter(mandatory=$true)]
		[string]$Name
	)

	$PESourcesDir = "${env:PROGRAMFILES(X86)}\Windows Kits\10\Assessment and Deployment Kit"

	#dicts to match less shit arch names with the source directories in the kit
	$ArchDictPESource = @{
		'AMD64'		=	"${PESourcesDir}\Windows Preinstallation Environment\amd64"
		'i686'		=	"${PESourcesDir}\Windows Preinstallation Environment\x86"
		'ARM32'		=	"${PESourcesDir}\Windows Preinstallation Environment\arm"
		'ARM64'		=	"${PESourcesDir}\Windows Preinstallation Environment\arm64"
	}

	$PESourceDir = $ArchDictPESource.${Architecture}
	$PEPackageDir	= "${PESourceDir}\WinPe_OCs"

	$AvailableLanguages = (Get-ChildItem -Directory -LiteralPath $PEPackageDir).Name

	if ($AvailableLanguages -notcontains $Language.ToLower()) {Write-Log -Level 'ERROR' -Message "Language `"${Language}`" not Found for Package `"${Name}`" in `"${PEPackageDir}`""; Throw [InvalidLanguage] $Language.ToLower()}

	$NeutralPackages = Get-ChildItem -File -LiteralPath $PEPackageDir
	$LangPackages = Get-ChildItem -File -LiteralPath "${PEPackageDir}\$($Language.ToLower())"

	$temp = @{}
	if ($NeutralPackages.BaseName -Contains $Name)
	{
		Write-Log -Level 'INFO' -LogOnly -Message "Neutral Package Exists for `"${Name}`""
		$temp['NeutralPackage'] = ($NeutralPackages | Where-Object {$_.BaseName -eq $Name}).FullName

		if ($LangPackages.BaseName -Contains "${Name}_$($Language.ToLower())")
		{
			Write-Log -Level 'INFO' -LogOnly -Message "Language Package Exists for `"${Name}`""
			$temp['SpecificPackage'] = ($LangPackages | Where-Object {$_.BaseName -eq "${Name}_$($Language.ToLower())"}).FullName
		}
	} elseif ($LangPackages.BaseName -Contains "${Name}_$($Language.ToLower())") {
		Write-Log -Level 'INFO' -LogOnly -Message "Only Language-Specific Package Exists for `"${Name}`""
		$temp['SpecificPackage'] = ($LangPackages | Where-Object {$_.BaseName -eq "${Name}_$($Language.ToLower())"}).FullName
	}
	if ($temp.Count -eq 0) {Write-Log -Level 'ERROR' -Message "Package `"${Path}`" Doesn't Exist"; Throw [InvalidPackage] $Name} else {
		Write-Log -Level 'INFO' -Message "Package `"${Name}`" Found"
		return $temp
	}
}

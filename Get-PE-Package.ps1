param(
	[Parameter()]
	[ValidateSet('AMD64','i686','ARM32','ARM64')]
	[string]$Architecture	=	'ARM64',
	
	[Parameter()]
	[string]$Language		=	'en-gb',
	
	[Parameter(mandatory=$true)]
	[string]$Name
)

class InvalidLanguage: System.Exception {
	InvalidLanguage([string]$x) :
		base ("`"${x}`" Is not a valid language.") {}
}

class InvalidPackage: System.Exception {
	InvalidPackage([string]$x) :
		base ("The package `"${x}`" Does not exist.") {}
}

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
Write-Verbose $PEPackageDir

$AvailableLanguages = (Get-ChildItem -Directory -LiteralPath $PEPackageDir).Name

if ($AvailableLanguages -notcontains $Language.ToLower()) {Throw [InvalidLanguage] $Language.ToLower()}

$NeutralPackages = Get-ChildItem -File -LiteralPath $PEPackageDir
$LangPackages = Get-ChildItem -File -LiteralPath "${PEPackageDir}\$($Language.ToLower())"

$temp = @{}
if ($NeutralPackages.BaseName -Contains $Name)
{
	Write-Verbose 'a'
	$temp['NeutralPackage'] = ($NeutralPackages | Where-Object {$_.BaseName -eq $Name}).FullName
	
	if ($LangPackages.BaseName -Contains "${Name}_$($Language.ToLower())")
	{
		Write-Verbose 'Package exists with a language-specific counterpart'
		$temp['SpecificPackage'] = ($LangPackages | Where-Object {$_.BaseName -eq "${Name}_$($Language.ToLower())"}).FullName
	}
} elseif ($LangPackages.BaseName -Contains "${Name}_$($Language.ToLower())") {
	Write-Verbose 'b'
	$temp['SpecificPackage'] = ($LangPackages | Where-Object {$_.BaseName -eq "${Name}_$($Language.ToLower())"}).FullName
}
if ($temp.Count -eq 0) {Write-Verbose "Package Doesn't Exist"; Throw [InvalidPackage] $Name} else {
	Write-Verbose 'goodw'
	return $temp
}
param(
	[Parameter()]
	[ValidateSet('AMD64','i686','ARM32','ARM64')]
	[string]$Architecture	=	'ARM64',
	
	[Parameter()]
	[string]$Language		=	'en-gb'
)

class InvalidLanguage: System.Exception {
	InvalidLanguage([string]$x) :
		base ("`"${x}`" Is not a valid language.") {}
}

$PESourcesDir = "${env:PROGRAMFILES(X86)}\Windows Kits\10\Assessment and Deployment Kit"

#dicts to match less shit arch names with the source directories in the kit
$ArchDictPESource = @{
	'AMD64'		=	"${PESourcesDir}\Windows Preinstallation Environment\amd64"
	'i686'		=	"${PESourcesDir}\Windows Preinstallation Environment\x86"
	'ARM32'		=	"${PESourcesDir}\Windows Preinstallation Environment\arm"
	'ARM64'		=	"${PESourcesDir}\Windows Preinstallation Environment\arm64"
}

$PESourceDir = $ArchDictPeSource.${Architecture}
$PEPackageDir	= "${PESourceDir}\WinPe_OCs"

$AvailableLanguages = (Get-ChildItem -Directory -LiteralPath $PEPackageDir).Name

if ($AvailableLanguages -notcontains $Language.ToLower()) {Throw [InvalidLanguage] $Language.ToLower()}

$NeutralPackages = Get-ChildItem -File -LiteralPath $PEPackageDir
$LangPackages = Get-ChildItem -File -LiteralPath "${PEPackageDir}\$($Language.ToLower())"

Write-Host "`nNeutral`n" -foregroundcolor cyan
$NeutralPackages.Name
Write-Host "`nLanguage-Specific`n" -foregroundcolor cyan
$LangPackages.Name
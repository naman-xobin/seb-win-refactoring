param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x86", "x64")]
    [string] $Platform = "x64",

    [switch] $BuildBundle
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$setupProject = Join-Path $repoRoot "Setup\Setup.wixproj"
$bundleProject = Join-Path $repoRoot "SetupBundle\SetupBundle.wixproj"

function Resolve-Tool([string] $Name, [string[]] $Candidates) {
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Unable to locate $Name. Ensure the required build tooling is installed."
}

$wixHeat = if ($env:WIX) { Join-Path $env:WIX "bin\heat.exe" } else { $null }
$heat = Resolve-Tool "heat.exe" @(
    $wixHeat,
    "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin\heat.exe",
    "${env:ProgramFiles}\WiX Toolset v3.11\bin\heat.exe"
)

$msbuild = Resolve-Tool "msbuild.exe" @()

$outputs = @{
    "Application" = @{
        Source = Join-Path $repoRoot "SafeExamBrowser.Runtime\bin\$Platform\$Configuration"
        Group = "ApplicationComponents"
        Directory = "ApplicationDirectory"
        Variable = "var.SafeExamBrowser.Runtime.TargetDir"
        Out = Join-Path $repoRoot "Setup\Components\Application.wxs"
        Transform = Join-Path $repoRoot "Setup\Components\Application.xslt"
    }
    "Configuration" = @{
        Source = Join-Path $repoRoot "SebWindowsConfig\bin\$Platform\$Configuration"
        Group = "ConfigurationComponents"
        Directory = "ConfigurationDirectory"
        Variable = "var.SebWindowsConfig.TargetDir"
        Out = Join-Path $repoRoot "Setup\Components\Configuration.wxs"
        Transform = Join-Path $repoRoot "Setup\Components\Configuration.xslt"
    }
    "Reset" = @{
        Source = Join-Path $repoRoot "SafeExamBrowser.ResetUtility\bin\$Platform\$Configuration"
        Group = "ResetComponents"
        Directory = "ResetDirectory"
        Variable = "var.SafeExamBrowser.ResetUtility.TargetDir"
        Out = Join-Path $repoRoot "Setup\Components\Reset.wxs"
        Transform = Join-Path $repoRoot "Setup\Components\Reset.xslt"
    }
    "Service" = @{
        Source = Join-Path $repoRoot "SafeExamBrowser.Service\bin\$Platform\$Configuration"
        Group = "ServiceComponents"
        Directory = "ServiceDirectory"
        Variable = "var.SafeExamBrowser.Service.TargetDir"
        Out = Join-Path $repoRoot "Setup\Components\Service.wxs"
        Transform = Join-Path $repoRoot "Setup\Components\Service.xslt"
    }
}

foreach ($item in $outputs.GetEnumerator()) {
    if (-not (Test-Path $item.Value.Source)) {
        throw "Expected build output not found for $($item.Key): $($item.Value.Source)"
    }

    & $heat dir $item.Value.Source `
        -nologo `
        -ag `
        -g1 `
        -scom `
        -srd `
        -sreg `
        -cg $item.Value.Group `
        -dr $item.Value.Directory `
        -sfrag `
        -var $item.Value.Variable `
        -out $item.Value.Out `
        -t $item.Value.Transform
}

& $msbuild $setupProject `
    /m `
    /restore:false `
    "/p:Configuration=$Configuration" `
    "/p:Platform=$Platform" `
    "/p:SignOutput=false" `
    "/p:PreBuildEvent=" `
    "/p:PostBuildEvent=" `
    "/p:RunPostBuildEvent=Never"

if ($BuildBundle) {
    $temp = "C:\Temp"
    New-Item -ItemType Directory -Force -Path $temp | Out-Null

    $net48 = Join-Path $temp "ndp48-web.exe"
    if (-not (Test-Path $net48)) {
        Invoke-WebRequest "https://go.microsoft.com/fwlink/?LinkId=2085155" -OutFile $net48
    }

    & $msbuild $bundleProject `
        /m `
        /restore:false `
        "/p:Configuration=$Configuration" `
        "/p:Platform=x64" `
        "/p:SignOutput=false" `
        "/p:PreBuildEvent=" `
        "/p:PostBuildEvent=" `
        "/p:RunPostBuildEvent=Never"
}

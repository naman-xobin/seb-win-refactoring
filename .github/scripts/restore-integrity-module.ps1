param(
    [string] $InstallPath = "C:\SEB",
    [switch] $Required
)

$ErrorActionPreference = "Stop"

function Restore-IntegrityDll([string] $Architecture, [string] $Base64Value) {
    $fileName = "seb_$Architecture.dll"
    $targetPath = Join-Path $InstallPath $fileName

    if ([string]::IsNullOrWhiteSpace($Base64Value)) {
        return $false
    }

    $normalized = $Base64Value -replace '\s', ''
    $bytes = [Convert]::FromBase64String($normalized)
    [IO.File]::WriteAllBytes($targetPath, $bytes)

    Write-Host "Restored $fileName to $InstallPath."
    return $true
}

function Download-IntegrityDll([string] $Architecture, [string] $Url) {
    $fileName = "seb_$Architecture.dll"
    $targetPath = Join-Path $InstallPath $fileName

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    $headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($env:SEB_INTEGRITY_DOWNLOAD_TOKEN)) {
        $headers["Authorization"] = "Bearer $env:SEB_INTEGRITY_DOWNLOAD_TOKEN"
    }

    Invoke-WebRequest -Uri $Url -OutFile $targetPath -Headers $headers
    Write-Host "Downloaded $fileName to $InstallPath."
    return $true
}

New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

$restoredX64 = (Download-IntegrityDll "x64" $env:SEB_INTEGRITY_X64_URL) -or (Restore-IntegrityDll "x64" $env:SEB_INTEGRITY_X64_DLL_BASE64)
$restoredX86 = (Download-IntegrityDll "x86" $env:SEB_INTEGRITY_X86_URL) -or (Restore-IntegrityDll "x86" $env:SEB_INTEGRITY_X86_DLL_BASE64)

$x64Path = Join-Path $InstallPath "seb_x64.dll"
$x86Path = Join-Path $InstallPath "seb_x86.dll"
$hasX64 = Test-Path $x64Path
$hasX86 = Test-Path $x86Path

if ($Required -and (-not $hasX64 -or -not $hasX86)) {
    throw "Release builds require native integrity modules. Configure SEB_INTEGRITY_X64_URL and SEB_INTEGRITY_X86_URL, or SEB_INTEGRITY_X64_DLL_BASE64 and SEB_INTEGRITY_X86_DLL_BASE64 GitHub secrets."
}

if (-not $hasX64 -or -not $hasX86) {
    Write-Warning "Native integrity modules are incomplete. Runtime builds without them can abort during startup."
}

if ($hasX64) {
    Write-Host "Available: $x64Path"
}

if ($hasX86) {
    Write-Host "Available: $x86Path"
}

if (-not $restoredX64 -and -not $restoredX86) {
    Write-Host "No integrity module secrets were provided; using any pre-existing files under $InstallPath."
}

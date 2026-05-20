# Xolock Windows

Xolock Windows is a refactored Safe Exam Browser for Windows distribution. It is a classic .NET Framework 4.8 desktop application with WPF, WinForms, a Windows service, Chromium-based browser integration, and WiX-based installers.

The CI/CD pipeline in this branch mirrors the operational architecture of `xolock-unified-browser`: validate on pull requests, build on Windows, sign application binaries before packaging, sign final installers, upload artifacts, and optionally publish release archives to Google Cloud Storage. Electron Forge and npm steps are intentionally replaced with NuGet, MSBuild, MSTest, and WiX.

## Technology Stack

- .NET Framework 4.8
- WPF and WinForms desktop applications
- Windows service components
- MSTest unit tests
- NuGet `packages.config` package restore
- WiX Toolset v3.x for MSI and bootstrapper bundle generation
- Azure Trusted Signing for CI release signing
- GitHub Actions for CI/CD
- Google Cloud Storage for optional release distribution

## Local Setup

Install the following on Windows:

- Visual Studio 2022 with .NET desktop development tools
- .NET Framework 4.8 Developer Pack and Runtime
- NuGet CLI
- WiX Toolset v3.11 or newer
- Visual C++ 2015-2022 Redistributable for runtime verification

Restore dependencies from the repository root:

```powershell
nuget restore SafeExamBrowser.sln -NonInteractive
```

Some post-build steps optionally copy the native integrity module from `C:\SEB\seb_x64.dll` or `C:\SEB\seb_x86.dll`. Local builds continue when the module is absent, but production builds should provide the correct native integrity binaries.

## Build Instructions

Build the primary x64 application outputs:

```powershell
msbuild SafeExamBrowser.Runtime\SafeExamBrowser.Runtime.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SafeExamBrowser.Client\SafeExamBrowser.Client.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SebWindowsConfig\SebWindowsConfig.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SafeExamBrowser.ResetUtility\SafeExamBrowser.ResetUtility.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SafeExamBrowser.Service\SafeExamBrowser.Service.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
```

Run unit tests after building test projects:

```powershell
msbuild SafeExamBrowser.Core.UnitTests\SafeExamBrowser.Core.UnitTests.csproj /m /p:Configuration=Release /p:Platform=x64
vstest.console.exe **\bin\x64\Release\*UnitTests.dll
```

Build WiX installers through the CI helper to avoid local certificate thumbprint hooks:

```powershell
.github\scripts\build-installer.ps1 -Configuration Release -Platform x64
.github\scripts\build-installer.ps1 -Configuration Release -Platform x86
.github\scripts\build-installer.ps1 -Configuration Release -Platform x64 -BuildBundle
```

## Running Locally

The main runtime executable is produced under:

```text
SafeExamBrowser.Runtime\bin\x64\Release\SafeExamBrowser.exe
```

Run from an elevated Windows environment when testing lockdown, service, installer, or browser security behavior. Some features require OS-level permissions and should not be tested on a personal workstation without a rollback plan.

## CI/CD Overview

GitHub Actions workflows live in `.github/workflows/`:

- `ci.yml` validates pull requests and pushes to `xolock-refactoring`, restores NuGet packages, builds application and test projects, runs MSTest assemblies, and uploads a portable x64 artifact.
- `release.yml` builds x64 and x86 release binaries, signs application outputs with Azure Trusted Signing when configured, creates MSI installers and the setup bundle with WiX, signs final installers, uploads GitHub artifacts, optionally uploads to GCS, and creates GitHub Releases for `v*.*.*` tags.
- `codeql.yml` runs C# CodeQL analysis on `xolock-refactoring`, `master`, and a weekly schedule.
- `issues.yml` keeps existing stale issue maintenance.

The Electron repository used Node.js, npm cache, Electron Forge packaging, Squirrel installers, and Forge zip makers. This repository uses NuGet cache, MSBuild project builds, WiX MSI/bundle packaging, and PowerShell archive creation.

## Branch Strategy

The active refactoring branch is `xolock-refactoring`.

- Pull requests targeting `xolock-refactoring` run CI and CodeQL.
- Pushes to `xolock-refactoring` run CI and release packaging.
- Tags matching `v*.*.*` run release packaging and can create GitHub Releases.
- Manual `workflow_dispatch` is available for CI and release workflows.

## Release Process

1. Merge or push the release candidate to `xolock-refactoring`.
2. Ensure Azure Trusted Signing secrets are configured for signed artifacts.
3. Ensure GCS secrets are configured if cloud distribution is required.
4. Create and push a semantic version tag such as `v1.2.3`.
5. The release workflow builds binaries, signs them, packages MSI and bundle outputs, signs installers, generates checksums, uploads artifacts, and creates a GitHub Release for the tag.

Manual release runs can disable GCS upload with the `publish_to_gcs` input.

## Artifact Outputs

CI produces:

- `Xolock-Windows-x64-portable.zip`
- MSTest `.trx` files when tests run

Release produces:

- `Xolock-Windows-x64-portable.zip`
- `Xolock-Windows-Installers.zip`
- `SHA256SUMS.txt`
- `Setup\bin\x64\Release\Setup.msi`
- `Setup\bin\x86\Release\Setup.msi`
- `SetupBundle\bin\x64\Release\SetupBundle.exe`

The setup bundle includes prerequisite handling for .NET Framework 4.8 and Visual C++ Redistributable. The MSI packages are useful when prerequisites are already managed externally.

## Required Secrets

Signing secrets are required for production releases:

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_ENDPOINT`
- `AZURE_CODE_SIGNING_NAME`
- `AZURE_CERT_PROFILE_NAME`

Cloud upload secrets are optional:

- `GCP_SA_KEY`
- `GCS_BUCKET_NAME`

See `.github/SECRETS.md` for purpose, format, and usage details.

## Troubleshooting

- If package restore fails, delete `packages/` and run `nuget restore SafeExamBrowser.sln -NonInteractive`.
- If WiX packaging fails, verify WiX Toolset v3.x is installed and `heat.exe` is available.
- If GitHub Actions installer builds fail around signing, confirm the workflow is using `.github/scripts/build-installer.ps1` and not the WiX projects' legacy local `signtool` hooks.
- If the runtime starts without integrity enforcement, verify the native `seb_<platform>.dll` module exists under `C:\SEB`.
- If GCS upload is skipped, confirm both `GCP_SA_KEY` and `GCS_BUCKET_NAME` are configured and manual runs have `publish_to_gcs` enabled.

## Developer Notes

Do not rename the `SafeExamBrowser.*` solution, project folders, namespaces, protocol handlers, or `.seb` compatibility surfaces unless the full dependency graph is intentionally migrated.

The GitHub Actions release flow preserves the source Electron pipeline's operational model but adapts implementation details to .NET Framework and WiX. Avoid adding npm, Electron Forge, Squirrel, or Electron-specific signing steps to this repository.

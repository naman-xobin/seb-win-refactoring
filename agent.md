# Agent Guide

This file is repository intelligence for future AI/code agents working on `seb-win-refactoring`.

## Repository Purpose

`seb-win-refactoring` is a Windows-only .NET Framework 4.8 application derived from Safe Exam Browser and branded as Xolock. It contains the runtime shell, client UI, Chromium browser integration, Windows service, configuration tool, reset utility, shared contracts, unit tests, and WiX installer projects.

The active branch for this work is `xolock-refactoring`.

## Important Directories

- `SafeExamBrowser.sln` is the root Visual Studio solution.
- `SafeExamBrowser.Runtime` builds the main `SafeExamBrowser.exe` runtime.
- `SafeExamBrowser.Client` builds the user-facing client and copies browser output into runtime output during post-build.
- `SafeExamBrowser.Browser` contains Chromium/browser integration.
- `SafeExamBrowser.Service` contains the Windows service.
- `SebWindowsConfig` contains the WinForms configuration tool.
- `SafeExamBrowser.ResetUtility` contains the reset utility.
- `SafeExamBrowser.*.Contracts` projects define shared interfaces/contracts.
- `*.UnitTests` projects use MSTest.
- `Setup` is the WiX MSI project.
- `SetupBundle` is the WiX bootstrapper bundle project.
- `.github/workflows` contains CI, release, CodeQL, and issue maintenance workflows.
- `.github/scripts/build-installer.ps1` is the GitHub Actions WiX packaging helper.
- `.github/scripts/restore-integrity-module.ps1` restores native integrity DLLs from GitHub secrets into `C:\SEB` before MSBuild.
- `.github/SECRETS.md` documents required repository secrets.

## Build System Overview

This is a classic .NET Framework repository, not SDK-style .NET Core. Prefer `nuget restore` and `msbuild` over `dotnet build` for reliable CI behavior.

Common restore command:

```powershell
nuget restore SafeExamBrowser.sln -NonInteractive
```

Common release build targets:

```powershell
msbuild SafeExamBrowser.Browser\SafeExamBrowser.Browser.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SafeExamBrowser.Runtime\SafeExamBrowser.Runtime.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SafeExamBrowser.Client\SafeExamBrowser.Client.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SebWindowsConfig\SebWindowsConfig.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SafeExamBrowser.ResetUtility\SafeExamBrowser.ResetUtility.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
msbuild SafeExamBrowser.Service\SafeExamBrowser.Service.csproj /m /p:Configuration=Release /p:Platform=x64 /p:SignOutput=false
```

Build both `x64` and `x86` when producing installers, because `SetupBundle\Bundle.wxs` chains both MSI packages.

## CI/CD Flow

The workflow architecture was adapted from `xolock-unified-browser`, which used a single Windows Electron Forge workflow:

1. Checkout.
2. Set up package manager cache.
3. Build/package application output.
4. Sign internal binaries.
5. Create installer from signed output.
6. Sign final installer.
7. Zip artifacts.
8. Upload to Google Cloud Storage.

The .NET equivalent is:

1. Checkout.
2. Set up NuGet/MSBuild and cache `packages/`.
3. Restore `packages.config` dependencies.
4. Restore native integrity modules into `C:\SEB`.
5. Build .NET Framework application projects.
6. Run MSTest unit tests for CI.
7. Sign built EXE/DLL outputs with Azure Trusted Signing in release runs.
8. Harvest signed outputs into WiX MSI packages.
9. Build WiX bootstrapper bundle.
10. Sign MSI and bundle artifacts.
11. Create portable and installer ZIP archives plus `SHA256SUMS.txt`.
12. Upload GitHub Actions artifacts, optionally upload to GCS, and create GitHub Releases on `v*.*.*` tags.

## Workflow Purposes

- `ci.yml`: PR and branch validation for `xolock-refactoring`; builds x64 app/test projects, runs tests, uploads portable artifact.
- `release.yml`: release orchestration for `xolock-refactoring`, `v*.*.*` tags, and manual dispatch; builds x64/x86, signs, packages, uploads.
- `codeql.yml`: C# CodeQL analysis with an explicit MSBuild build to avoid WiX local signing hooks.
- `issues.yml`: scheduled/manual stale issue maintenance.

## Release Flow

Use semantic version tags matching `v*.*.*` for production releases. The release workflow can run on branch pushes, tags, or manual dispatch. GitHub Release creation is gated to `v*.*.*` tags.

Release artifacts:

- `Xolock-Windows-x64-portable.zip`
- `Xolock-Windows-Installers.zip`
- `SHA256SUMS.txt`
- `Setup\bin\x64\Release\Setup.msi`
- `Setup\bin\x86\Release\Setup.msi`
- `SetupBundle\bin\x64\Release\SetupBundle.exe`

## Packaging Strategy

The repository already contains WiX installer projects, so CI should not introduce Electron/Squirrel packaging. The correct packaging path is WiX MSI plus WiX Burn bootstrapper.

The checked-in WiX projects contain legacy hardcoded `signtool` hooks using a local certificate thumbprint. Do not depend on those in GitHub Actions. Use `.github/scripts/build-installer.ps1`, which regenerates harvested component files and builds WiX artifacts with local signing hooks disabled. Release signing is handled by Azure Trusted Signing workflow steps.

## Required Secrets

Azure Trusted Signing:

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_ENDPOINT`
- `AZURE_CODE_SIGNING_NAME`
- `AZURE_CERT_PROFILE_NAME`

Google Cloud Storage:

- `GCP_SA_KEY`
- `GCS_BUCKET_NAME`

Native integrity modules, preferably from private download URLs:

- `SEB_INTEGRITY_X64_URL`
- `SEB_INTEGRITY_X86_URL`
- `SEB_INTEGRITY_DOWNLOAD_TOKEN`

Fallback native integrity module secrets, only if the DLLs fit GitHub secret limits:

- `SEB_INTEGRITY_X64_DLL_BASE64`
- `SEB_INTEGRITY_X86_DLL_BASE64`

`GITHUB_TOKEN` is provided by GitHub Actions and is used for issue maintenance and GitHub Releases.

## Important Scripts

- `.github/scripts/build-installer.ps1` locates `heat.exe` and `msbuild.exe`, regenerates WiX component fragments from application output directories, builds `Setup.wixproj`, and optionally builds `SetupBundle.wixproj`.
- `.github/scripts/restore-integrity-module.ps1` downloads `SEB_INTEGRITY_X64_URL` and `SEB_INTEGRITY_X86_URL`, or decodes the base64 fallback secrets, into `C:\SEB\seb_x64.dll` and `C:\SEB\seb_x86.dll`. Release workflow uses `-Required` so installers are not produced without the modules.
- `generate-branding.ps1` is a local branding helper from prior rebranding work. Do not run it casually because it may overwrite image assets.

## Common Maintenance Tasks

- Keep package cache keys tied to `packages.config`, `.csproj`, and `.sln` changes.
- If adding a new deployable executable, include it in the release build and signing stages.
- If changing WiX component layout, update `.github/scripts/build-installer.ps1` to harvest the correct directories.
- If release builds abort with `Integrity module is not available!`, verify the integrity module secrets exist and were restored before MSBuild.
- If changing branch strategy, update `ci.yml`, `release.yml`, and `codeql.yml` together.
- If adding new required secrets, update `.github/SECRETS.md` and this file.

## Known Caveats

- The solution and many namespaces remain `SafeExamBrowser.*`; renaming them is high risk and not required for Xolock branding.
- `.seb`, `seb://`, `sebs://`, SEB-Server, and SEB Verificator references may be compatibility surfaces and should not be blindly renamed.
- Production integrity requires native modules under `C:\SEB\seb_x64.dll` and `C:\SEB\seb_x86.dll` during release builds. GitHub Actions restores them from private URLs or base64 fallback secrets before packaging.
- WiX bundle creation expects both x64 and x86 MSI outputs.
- GitHub-hosted runners need WiX installed before packaging.
- The app is Windows-only; use `windows-latest` for build/release jobs.

## Branch Conventions

- Active refactoring branch: `xolock-refactoring`.
- Release tags: `v*.*.*`.
- PR validation should target `xolock-refactoring`.
- Avoid Electron-specific CI commands such as `npm ci`, `electron-forge package`, `electron-forge make`, or Squirrel maker steps in this repository.

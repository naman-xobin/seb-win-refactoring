# GitHub Actions Secrets

This repository uses placeholders only. Never commit certificate files, service-account keys, tenant secrets, or production credentials.

| Secret | Required | Used by | Purpose | Expected format |
| --- | --- | --- | --- | --- |
| `AZURE_TENANT_ID` | Optional for CI, required for signed releases | `.github/workflows/release.yml` | Azure tenant used by Azure Trusted Signing. | GUID string. |
| `AZURE_CLIENT_ID` | Optional for CI, required for signed releases | `.github/workflows/release.yml` | Azure application/client ID authorized for Trusted Signing. | GUID string. |
| `AZURE_CLIENT_SECRET` | Optional for CI, required for signed releases | `.github/workflows/release.yml` | Client secret for the Azure application. | Secret string from Azure Entra ID. |
| `AZURE_ENDPOINT` | Optional for CI, required for signed releases | `.github/workflows/release.yml` | Trusted Signing account endpoint. | HTTPS endpoint URL, for example `https://<region>.codesigning.azure.net/`. |
| `AZURE_CODE_SIGNING_NAME` | Optional for CI, required for signed releases | `.github/workflows/release.yml` | Trusted Signing account name. | Azure Trusted Signing account name. |
| `AZURE_CERT_PROFILE_NAME` | Optional for CI, required for signed releases | `.github/workflows/release.yml` | Certificate profile used to sign EXE, DLL, MSI, and bundle artifacts. | Trusted Signing certificate profile name. |
| `GCP_SA_KEY` | Optional | `.github/workflows/release.yml` | Service account credentials used to upload release archives to Google Cloud Storage. | Full JSON service account key. |
| `GCS_BUCKET_NAME` | Optional | `.github/workflows/release.yml` | Destination bucket/path for release artifacts. | Bucket name or bucket path accepted by `google-github-actions/upload-cloud-storage`. |
| `SEB_INTEGRITY_X64_URL` | Optional for CI, required for release unless using base64 | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Downloads `C:\SEB\seb_x64.dll` before MSBuild so the x64 runtime can pass integrity verification after installation. | HTTPS URL to the native `seb_x64.dll`. |
| `SEB_INTEGRITY_X86_URL` | Optional for CI, required for release unless using base64 | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Downloads `C:\SEB\seb_x86.dll` before MSBuild so the x86 MSI can include the native integrity module. | HTTPS URL to the native `seb_x86.dll`. |
| `SEB_INTEGRITY_DOWNLOAD_TOKEN` | Optional | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Bearer token used when downloading integrity modules from private storage. | Opaque token. Used as `Authorization: Bearer <token>`. |
| `SEB_INTEGRITY_X64_DLL_BASE64` | Optional fallback | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Restores `C:\SEB\seb_x64.dll` from a secret when a download URL is not used. | Base64-encoded contents of the native `seb_x64.dll`; only practical if it fits GitHub secret limits. |
| `SEB_INTEGRITY_X86_DLL_BASE64` | Optional fallback | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Restores `C:\SEB\seb_x86.dll` from a secret when a download URL is not used. | Base64-encoded contents of the native `seb_x86.dll`; only practical if it fits GitHub secret limits. |
| `GITHUB_TOKEN` | Automatically provided | `.github/workflows/issues.yml`, `.github/workflows/release.yml` | Issue maintenance and GitHub release creation. | Built-in GitHub Actions token. |

## Signing Model

The source Electron pipeline signs in two phases: packaged application binaries first, then the final installer. The .NET pipeline keeps the same trust boundary:

1. Build the .NET Framework application outputs for `x64` and `x86`.
2. Sign runtime, configuration tool, reset utility, and service binaries with Azure Trusted Signing when signing secrets are present.
3. Harvest signed outputs into WiX MSI packages.
4. Sign the MSI files and final setup bundle.

The checked-in WiX projects still contain legacy local `signtool` hooks with a certificate thumbprint. GitHub Actions bypasses those hooks through `.github/scripts/build-installer.ps1` and uses Azure Trusted Signing instead.

## Native Integrity Modules

The runtime checks for the native integrity module during startup. If `seb_x64.dll` is missing from the installed application, the log contains `Integrity module is not available!` and startup aborts.

GitHub Actions restores the native modules into `C:\SEB` before MSBuild runs. The existing project post-build events then copy those files into application outputs, and WiX packages them into the MSI.

Preferred production setup is to store the DLLs in private release storage and configure:

- `SEB_INTEGRITY_X64_URL`
- `SEB_INTEGRITY_X86_URL`
- `SEB_INTEGRITY_DOWNLOAD_TOKEN`, if the URLs require authorization

For small test binaries only, generate base64 secret values on a trusted Windows machine:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\SEB\seb_x64.dll")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\SEB\seb_x86.dll")) | Set-Clipboard
```

Add the copied values as `SEB_INTEGRITY_X64_DLL_BASE64` and `SEB_INTEGRITY_X86_DLL_BASE64` in GitHub repository secrets. Treat these binaries as release assets and do not commit them to the repository.

## Google Cloud Storage

GCS upload follows the Electron repository pattern. When `GCP_SA_KEY` and `GCS_BUCKET_NAME` are configured, release archives from `artifacts/` are uploaded with `parent: false`.

For manual runs, the `publish_to_gcs` workflow input can disable the upload without removing secrets.

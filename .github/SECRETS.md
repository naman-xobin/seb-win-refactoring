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
| `GITHUB_TOKEN` | Automatically provided | `.github/workflows/issues.yml`, `.github/workflows/release.yml` | Issue maintenance and GitHub release creation. | Built-in GitHub Actions token. |

## Signing Model

The source Electron pipeline signs in two phases: packaged application binaries first, then the final installer. The .NET pipeline keeps the same trust boundary:

1. Build the .NET Framework application outputs for `x64` and `x86`.
2. Sign runtime, configuration tool, reset utility, and service binaries with Azure Trusted Signing when signing secrets are present.
3. Harvest signed outputs into WiX MSI packages.
4. Sign the MSI files and final setup bundle.

The checked-in WiX projects still contain legacy local `signtool` hooks with a certificate thumbprint. GitHub Actions bypasses those hooks through `.github/scripts/build-installer.ps1` and uses Azure Trusted Signing instead.

## Google Cloud Storage

GCS upload follows the Electron repository pattern. When `GCP_SA_KEY` and `GCS_BUCKET_NAME` are configured, release archives from `artifacts/` are uploaded with `parent: false`.

For manual runs, the `publish_to_gcs` workflow input can disable the upload without removing secrets.

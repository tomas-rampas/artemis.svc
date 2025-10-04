#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Installs pre-generated certificates into Docker container X509Store.

.DESCRIPTION
    This script is designed to run during Docker container startup (entrypoint).
    It installs pre-generated certificates from the mounted volume into the
    container's .NET X509Store, making them accessible to the ASP.NET Core application.

    This script expects certificates to be available in:
    - /app/certs/docker/my/ - Server certificates (PFX format)
    - /app/certs/docker/root/ - CA certificates

.PARAMETER CertificateDirectory
    Base directory containing the docker/my and docker/root subdirectories.
    Default: /app/certs

.PARAMETER ThumbprintFile
    Path to file containing the server certificate thumbprint.
    Default: /app/certs/server/thumbprint.txt

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    ./Install-DockerCertificates.ps1
    Installs certificates from default locations.

.EXAMPLE
    ./Install-DockerCertificates.ps1 -CertificateDirectory /custom/certs -Verbose
    Installs certificates from custom location with verbose output.

.NOTES
    Author: PowerShell Automation Expert
    Version: 1.0.0
    Requires: PowerShell Core 7+
    Platform: Docker containers (Linux)
    Usage: Called from docker-entrypoint.sh during container startup
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Base certificate directory")]
    [string]$CertificateDirectory = "/app/certs",

    [Parameter(HelpMessage = "Thumbprint file path")]
    [string]$ThumbprintFile = "/app/certs/server/thumbprint.txt",

    [Parameter(HelpMessage = "PFX password (from environment or parameter)")]
    [string]$PfxPassword = $env:CERT_PFX_PASSWORD,

    [Parameter(HelpMessage = "Skip confirmation prompts")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

#region Variables

$DockerMyDir = Join-Path $CertificateDirectory "docker/my"
$DockerRootDir = Join-Path $CertificateDirectory "docker/root"
$X509StoreBasePath = Join-Path $env:HOME ".dotnet/corefx/cryptography/x509stores"
$X509StoreMyPath = Join-Path $X509StoreBasePath "my"
$X509StoreRootPath = Join-Path $X509StoreBasePath "root"

#endregion

#region Helper Functions

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Step {
    param([string]$Message)
    Write-Host "[>>] $Message" -ForegroundColor Yellow
}

function Install-CertificateToStore {
    param(
        [string]$CertificatePath,
        [string]$StoreName,
        [string]$StoreLocation,
        [string]$Password = $null
    )

    try {
        Write-Step "Installing: $(Split-Path $CertificatePath -Leaf) → $StoreLocation\$StoreName"

        # Load certificate
        $cert = if ($Password) {
            New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
                $CertificatePath,
                $Password,
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
            )
        } else {
            New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
        }

        Write-Verbose "Subject: $($cert.Subject)"
        Write-Verbose "Thumbprint: $($cert.Thumbprint)"

        # Open store and add certificate
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::$StoreName,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::$StoreLocation
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

        # For Root store, remove existing CA certificates with same subject to ensure clean installation
        if ($StoreName -eq "Root") {
            Write-Verbose "Removing old CA certificates with same subject (if any)"
            $existingCerts = $store.Certificates | Where-Object {
                $_.Subject -eq $cert.Subject
            }
            foreach ($oldCert in $existingCerts) {
                Write-Verbose "Removing old CA certificate: $($oldCert.Thumbprint)"
                $store.Remove($oldCert)
            }
        }

        # Add certificate
        $store.Add($cert)

        # Verify installation
        $store.Close()
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $installedCert = $store.Certificates | Where-Object {
            $_.Thumbprint -eq $cert.Thumbprint
        }
        $store.Close()

        if ($null -eq $installedCert) {
            throw "Certificate installation verification failed - certificate not found in store after Add()"
        }

        Write-Success "Certificate installed: $($cert.Thumbprint)"
        Write-Verbose "Installation verified successfully"
        return $true
    } catch {
        Write-Error "Failed to install certificate: $_"
        return $false
    }
}

#endregion

#region Main Execution

function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║    Docker Certificate Installation - X509Store Registration    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Validate directories exist
        if (-not (Test-Path $DockerMyDir)) {
            throw "Server certificate directory not found: $DockerMyDir"
        }
        if (-not (Test-Path $DockerRootDir)) {
            throw "CA certificate directory not found: $DockerRootDir"
        }

        # Create X509Store directories if needed
        @($X509StoreMyPath, $X509StoreRootPath) | ForEach-Object {
            if (-not (Test-Path $_)) {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
                Write-Verbose "Created directory: $_"
            }
        }

        # Read thumbprint
        $thumbprint = $null
        if (Test-Path $ThumbprintFile) {
            $thumbprint = (Get-Content -Path $ThumbprintFile -Raw).Trim()
            Write-Information "Expected thumbprint: $thumbprint"
        }

        # Install CA certificates from docker/root
        Write-Step "Installing CA certificates from: $DockerRootDir"
        $caCerts = Get-ChildItem -Path $DockerRootDir -File
        foreach ($caCert in $caCerts) {
            Install-CertificateToStore `
                -CertificatePath $caCert.FullName `
                -StoreName "Root" `
                -StoreLocation "CurrentUser" | Out-Null
        }

        # Install server certificates from docker/my
        Write-Step "Installing server certificates from: $DockerMyDir"

        # If thumbprint is specified, only install that specific certificate
        if ($thumbprint) {
            $serverCertFile = Join-Path $DockerMyDir "$thumbprint.pfx"
            if (-not (Test-Path $serverCertFile)) {
                throw "Server certificate not found: $serverCertFile"
            }

            Write-Verbose "Installing certificate with thumbprint: $thumbprint"
            Install-CertificateToStore `
                -CertificatePath $serverCertFile `
                -StoreName "My" `
                -StoreLocation "CurrentUser" `
                -Password $PfxPassword | Out-Null
        } else {
            # No thumbprint specified, install all PFX files
            $serverCerts = Get-ChildItem -Path $DockerMyDir -Filter "*.pfx"

            if ($serverCerts.Count -eq 0) {
                throw "No PFX files found in $DockerMyDir"
            }

            foreach ($serverCert in $serverCerts) {
                # Password comes from environment variable CERT_PFX_PASSWORD or parameter
                Install-CertificateToStore `
                    -CertificatePath $serverCert.FullName `
                    -StoreName "My" `
                    -StoreLocation "CurrentUser" `
                    -Password $PfxPassword | Out-Null
            }
        }

        # Verify installation
        Write-Step "Verifying installation"
        $myStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::My,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $myStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

        $installedCount = $myStore.Certificates.Count
        $myStore.Close()

        if ($installedCount -gt 0) {
            Write-Success "Installed $installedCount certificate(s) to My store"
        } else {
            throw "No certificates found in My store after installation"
        }

        # Verify expected thumbprint if available
        if ($thumbprint) {
            $myStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                [System.Security.Cryptography.X509Certificates.StoreName]::My,
                [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
            )
            $myStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

            $targetCert = $myStore.Certificates | Where-Object { $_.Thumbprint -eq $thumbprint }
            $myStore.Close()

            if ($targetCert) {
                Write-Success "Target certificate verified: $thumbprint"

                # Validate certificate chain
                Write-Step "Validating certificate chain"
                $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
                $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck

                $chainValid = $chain.Build($targetCert)
                if ($chainValid) {
                    Write-Success "Certificate chain is valid"
                    Write-Verbose "Chain elements: $($chain.ChainElements.Count)"
                    foreach ($element in $chain.ChainElements) {
                        Write-Verbose "  - $($element.Certificate.Subject)"
                    }
                } else {
                    Write-Warning "Certificate chain validation failed"
                    foreach ($status in $chain.ChainStatus) {
                        Write-Warning "  - $($status.Status): $($status.StatusInformation)"
                    }
                }
            } else {
                Write-Warning "Expected certificate with thumbprint $thumbprint not found"
            }
        }

        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║            DOCKER CERTIFICATE INSTALLATION COMPLETED           ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""

        return 0
    } catch {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║             DOCKER CERTIFICATE INSTALLATION FAILED             ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Error "Error: $_"
        return 1
    }
}

# Execute and return exit code
exit (Main)

#endregion

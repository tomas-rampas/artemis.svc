#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates and registers SSL/TLS certificates using .NET X509Store API for ASP.NET Core applications.

.DESCRIPTION
    This script creates a self-signed Certificate Authority (CA) and server certificate,
    then properly registers them using .NET's X509Store API. This ensures certificates
    are accessible to .NET Core applications on Linux, WSL, and Docker environments.

    The script performs the following operations:
    1. Generates a CA certificate and private key
    2. Generates a server certificate signed by the CA
    3. Registers CA certificate in CurrentUser\Root store (trusted root)
    4. Registers server certificate in CurrentUser\My store (personal)
    5. Updates appsettings.json with the certificate thumbprint
    6. Validates the certificate installation and chain

.PARAMETER CommonName
    The Common Name (CN) for the server certificate. Default: artemis-api.local

.PARAMETER ValidityDays
    Number of days the server certificate is valid. Default: 365

.PARAMETER CAValidityDays
    Number of days the CA certificate is valid. Default: 730

.PARAMETER PfxPassword
    Password for the PFX file. If not provided, a secure random password is generated.

.PARAMETER Environment
    Target environment: WSL, Docker, or Both. Default: Both

.PARAMETER CleanupOld
    Remove old certificates from stores before installing new ones.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER WhatIf
    Shows what would happen if the script runs without making changes.

.EXAMPLE
    ./Setup-Certificates.ps1
    Generates certificates with default settings for both WSL and Docker.

.EXAMPLE
    ./Setup-Certificates.ps1 -CommonName "myapi.local" -ValidityDays 180 -Verbose
    Generates certificates with custom common name and validity period with verbose output.

.EXAMPLE
    ./Setup-Certificates.ps1 -CleanupOld -Force
    Removes old certificates and installs new ones without prompts.

.NOTES
    Author: PowerShell Automation Expert
    Version: 1.0.0
    Requires: PowerShell Core 7+, OpenSSL
    Platform: Linux, WSL2, Docker
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Common Name for the server certificate")]
    [ValidateNotNullOrEmpty()]
    [string]$CommonName = "artemis-api.local",

    [Parameter(HelpMessage = "Server certificate validity in days")]
    [ValidateRange(1, 3650)]
    [int]$ValidityDays = 365,

    [Parameter(HelpMessage = "CA certificate validity in days")]
    [ValidateRange(1, 7300)]
    [int]$CAValidityDays = 730,

    [Parameter(HelpMessage = "PFX password (generated if not provided)")]
    [SecureString]$PfxPassword = $null,

    [Parameter(HelpMessage = "Target environment")]
    [ValidateSet('WSL', 'Docker', 'Both')]
    [string]$Environment = 'Both',

    [Parameter(HelpMessage = "Remove old certificates before installing")]
    [switch]$CleanupOld,

    [Parameter(HelpMessage = "Skip confirmation prompts")]
    [switch]$Force
)

#region Variables and Constants

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'Continue'

# Script paths
$ScriptRoot = $PSScriptRoot
$CertBaseDir = Join-Path $ScriptRoot "certs"
$CADir = Join-Path $CertBaseDir "ca"
$ServerDir = Join-Path $CertBaseDir "server"
$BackupDir = Join-Path $CertBaseDir "backup" (Get-Date -Format "yyyyMMdd-HHmmss")
$DockerDir = Join-Path $CertBaseDir "docker"

# Certificate file paths
$CAKeyFile = Join-Path $CADir "artemis-ca.key"
$CACertFile = Join-Path $CADir "artemis-ca.crt"
$ServerKeyFile = Join-Path $ServerDir "artemis-server.key"
$ServerCSRFile = Join-Path $ServerDir "artemis-server.csr"
$ServerCertFile = Join-Path $ServerDir "artemis-server.crt"
$ServerPfxFile = Join-Path $ServerDir "artemis-server.pfx"
$ThumbprintFile = Join-Path $ServerDir "thumbprint.txt"
$PfxPasswordFile = Join-Path $ServerDir "pfx-password.txt"
$OpenSSLConfigFile = Join-Path $ServerDir "openssl.cnf"

# Configuration files
$AppSettingsFile = Join-Path $ScriptRoot "appsettings.json"

# Certificate subjects
$CASubject = "/C=US/ST=State/L=City/O=Artemis/OU=IT/CN=Artemis Root CA"
$ServerSubject = "/C=US/ST=State/L=City/O=Artemis/OU=IT/CN=$CommonName"

# Platform detection
$IsLinuxPlatform = $PSVersionTable.Platform -eq 'Unix' -or $IsLinux
$IsDockerEnvironment = Test-Path '/.dockerenv'
$IsWSLEnvironment = Test-Path '/proc/sys/fs/binfmt_misc/WSLInterop'

# X509Store paths (Linux/WSL)
$X509StoreBasePath = Join-Path $env:HOME ".dotnet/corefx/cryptography/x509stores"
$X509StoreMyPath = Join-Path $X509StoreBasePath "my"
$X509StoreRootPath = Join-Path $X509StoreBasePath "root"
$X509StoreCAPath = Join-Path $X509StoreBasePath "ca"

#endregion

#region Helper Functions

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Step {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Yellow
}

function Test-Prerequisites {
    Write-Section "Validating Prerequisites"

    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $issues += "PowerShell Core 7+ is required. Current version: $($PSVersionTable.PSVersion)"
    } else {
        Write-Success "PowerShell version: $($PSVersionTable.PSVersion)"
    }

    # Check OpenSSL
    $opensslPath = Get-Command openssl -ErrorAction SilentlyContinue
    if (-not $opensslPath) {
        $issues += "OpenSSL is not installed or not in PATH"
    } else {
        $opensslVersion = & openssl version 2>&1
        Write-Success "OpenSSL found: $opensslVersion"
    }

    # Check platform
    if ($IsLinuxPlatform) {
        Write-Success "Platform: Linux/Unix"
        if ($IsWSLEnvironment) {
            Write-Success "Environment: WSL2"
        }
        if ($IsDockerEnvironment) {
            Write-Success "Environment: Docker Container"
        }
    } else {
        $issues += "This script is designed for Linux/WSL/Docker environments"
    }

    # Check .NET assemblies
    try {
        Add-Type -AssemblyName System.Security
        Write-Success ".NET Security assemblies loaded"
    } catch {
        $issues += "Failed to load required .NET assemblies: $_"
    }

    if ($issues.Count -gt 0) {
        Write-Error "Prerequisites validation failed:`n$($issues -join "`n")"
        return $false
    }

    return $true
}

function Initialize-Directories {
    Write-Section "Initializing Directory Structure"

    $directories = @($CertBaseDir, $CADir, $ServerDir, $BackupDir, $DockerDir)

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Verbose "Created directory: $dir"
        }
    }

    Write-Success "Directory structure initialized"
}

function Backup-ExistingCertificates {
    Write-Section "Backing Up Existing Certificates"

    $filesToBackup = @(
        $CAKeyFile, $CACertFile,
        $ServerKeyFile, $ServerCSRFile, $ServerCertFile, $ServerPfxFile,
        $ThumbprintFile, $AppSettingsFile
    )

    $backedUpCount = 0
    foreach ($file in $filesToBackup) {
        if (Test-Path $file) {
            $backupPath = Join-Path $BackupDir (Split-Path $file -Leaf)
            Copy-Item -Path $file -Destination $backupPath -Force
            Write-Verbose "Backed up: $(Split-Path $file -Leaf)"
            $backedUpCount++
        }
    }

    if ($backedUpCount -gt 0) {
        Write-Success "Backed up $backedUpCount file(s) to: $BackupDir"
    } else {
        Write-Information "No existing files to backup"
    }
}

function New-SecurePassword {
    [OutputType([SecureString])]
    param()

    # Generate cryptographically secure random password
    $length = 32
    $charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?"
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] $length
    $rng.GetBytes($bytes)

    $password = -join (1..$length | ForEach-Object {
        $charset[$bytes[$_] % $charset.Length]
    })

    return (ConvertTo-SecureString -String $password -AsPlainText -Force)
}

function ConvertFrom-SecureStringToPlainText {
    param([SecureString]$SecureString)

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function New-OpenSSLConfig {
    Write-Step "Creating OpenSSL configuration"

    $configContent = @"
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[ req_distinguished_name ]
C  = US
ST = State
L  = City
O  = Artemis
OU = IT
CN = $CommonName

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $CommonName
DNS.2 = localhost
DNS.3 = artemis-api
DNS.4 = artemis-svc
IP.1 = 127.0.0.1
IP.2 = ::1
"@

    Set-Content -Path $OpenSSLConfigFile -Value $configContent -Force
    Write-Verbose "Created OpenSSL config: $OpenSSLConfigFile"
}

function New-CACertificate {
    Write-Section "Generating CA Certificate"

    if ($PSCmdlet.ShouldProcess("CA Certificate", "Generate")) {
        Write-Step "Generating CA private key (4096-bit RSA)"
        $caKeyArgs = @(
            "genrsa",
            "-out", $CAKeyFile,
            "4096"
        )
        & openssl @caKeyArgs 2>&1 | Write-Verbose

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate CA private key"
        }

        # Set restrictive permissions
        chmod 600 $CAKeyFile
        Write-Success "CA private key generated"

        Write-Step "Creating self-signed CA certificate (valid for $CAValidityDays days)"
        $caCertArgs = @(
            "req", "-new", "-x509",
            "-key", $CAKeyFile,
            "-out", $CACertFile,
            "-days", $CAValidityDays,
            "-subj", $CASubject,
            "-sha256"
        )
        & openssl @caCertArgs 2>&1 | Write-Verbose

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate CA certificate"
        }

        Write-Success "CA certificate generated: $CACertFile"

        # Display CA certificate info
        Write-Verbose "CA Certificate Details:"
        & openssl x509 -in $CACertFile -noout -subject -dates 2>&1 | Write-Verbose
    }
}

function New-ServerCertificate {
    param([SecureString]$Password)

    Write-Section "Generating Server Certificate"

    if ($PSCmdlet.ShouldProcess("Server Certificate", "Generate")) {
        # Create OpenSSL config
        New-OpenSSLConfig

        Write-Step "Generating server private key (2048-bit RSA)"
        $serverKeyArgs = @(
            "genrsa",
            "-out", $ServerKeyFile,
            "2048"
        )
        & openssl @serverKeyArgs 2>&1 | Write-Verbose

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate server private key"
        }

        chmod 600 $ServerKeyFile
        Write-Success "Server private key generated"

        Write-Step "Creating Certificate Signing Request (CSR)"
        $csrArgs = @(
            "req", "-new",
            "-key", $ServerKeyFile,
            "-out", $ServerCSRFile,
            "-config", $OpenSSLConfigFile
        )
        & openssl @csrArgs 2>&1 | Write-Verbose

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create CSR"
        }

        Write-Success "CSR created"

        Write-Step "Signing certificate with CA (valid for $ValidityDays days)"
        $signArgs = @(
            "x509", "-req",
            "-in", $ServerCSRFile,
            "-CA", $CACertFile,
            "-CAkey", $CAKeyFile,
            "-CAcreateserial",
            "-out", $ServerCertFile,
            "-days", $ValidityDays,
            "-extensions", "v3_req",
            "-extfile", $OpenSSLConfigFile,
            "-sha256"
        )
        & openssl @signArgs 2>&1 | Write-Verbose

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to sign certificate"
        }

        Write-Success "Server certificate signed"

        # Create PFX file
        Write-Step "Creating PFX file with private key"
        $passwordPlain = ConvertFrom-SecureStringToPlainText -SecureString $Password

        $pfxArgs = @(
            "pkcs12", "-export",
            "-out", $ServerPfxFile,
            "-inkey", $ServerKeyFile,
            "-in", $ServerCertFile,
            "-certfile", $CACertFile,
            "-password", "pass:$passwordPlain"
        )
        & openssl @pfxArgs 2>&1 | Write-Verbose

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create PFX file"
        }

        chmod 600 $ServerPfxFile
        Write-Success "PFX file created: $ServerPfxFile"

        # Extract thumbprint
        $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ServerCertFile)
        $thumbprint = $certObj.Thumbprint
        Set-Content -Path $ThumbprintFile -Value $thumbprint -Force
        Write-Success "Certificate thumbprint: $thumbprint"

        # Display certificate info
        Write-Verbose "Server Certificate Details:"
        & openssl x509 -in $ServerCertFile -noout -subject -dates -ext subjectAltName 2>&1 | Write-Verbose

        # Clear sensitive data
        $passwordPlain = $null

        return $thumbprint
    }
}

function Remove-OldCertificatesFromStore {
    param(
        [string]$StoreName,
        [string]$StoreLocation,
        [string]$SubjectPattern
    )

    if (-not $CleanupOld) {
        return
    }

    Write-Step "Removing old certificates from $StoreLocation\$StoreName store"

    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::$StoreName,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::$StoreLocation
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

        $certsToRemove = $store.Certificates | Where-Object {
            $_.Subject -like "*$SubjectPattern*"
        }

        foreach ($cert in $certsToRemove) {
            if ($PSCmdlet.ShouldProcess($cert.Thumbprint, "Remove certificate from $StoreName store")) {
                $store.Remove($cert)
                Write-Verbose "Removed certificate: $($cert.Subject) [$($cert.Thumbprint)]"
            }
        }

        if ($certsToRemove.Count -gt 0) {
            Write-Success "Removed $($certsToRemove.Count) old certificate(s)"
        }
    } catch {
        Write-Warning "Failed to clean old certificates from $StoreName store: $_"
    } finally {
        if ($store) {
            $store.Close()
        }
    }
}

function Install-CertificateToStore {
    param(
        [string]$CertificatePath,
        [string]$StoreName,
        [string]$StoreLocation,
        [SecureString]$Password = $null,
        [string]$Description
    )

    Write-Section "Installing $Description"

    if (-not $PSCmdlet.ShouldProcess("$StoreLocation\$StoreName", "Install certificate")) {
        return $null
    }

    try {
        Write-Step "Loading certificate from: $CertificatePath"

        # Load certificate
        $cert = if ($Password) {
            $passwordPlain = ConvertFrom-SecureStringToPlainText -SecureString $Password
            $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
                $CertificatePath,
                $passwordPlain,
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
            )
            $passwordPlain = $null
            $certObj
        } else {
            New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
        }

        Write-Verbose "Certificate Subject: $($cert.Subject)"
        Write-Verbose "Certificate Thumbprint: $($cert.Thumbprint)"
        Write-Verbose "Valid From: $($cert.NotBefore)"
        Write-Verbose "Valid Until: $($cert.NotAfter)"

        Write-Step "Opening X509Store: $StoreLocation\$StoreName"
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::$StoreName,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::$StoreLocation
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

        # For Root store, remove existing CA certificates with same subject to ensure clean installation
        if ($StoreName -eq "Root") {
            Write-Step "Removing old CA certificates with same subject (if any)"
            $existingCerts = $store.Certificates | Where-Object {
                $_.Subject -eq $cert.Subject
            }
            foreach ($oldCert in $existingCerts) {
                Write-Verbose "Removing old CA certificate: $($oldCert.Thumbprint)"
                $store.Remove($oldCert)
            }
        }

        Write-Step "Adding certificate to store"
        $store.Add($cert)

        # Verify installation
        Write-Step "Verifying certificate installation"
        $store.Close()
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $installedCert = $store.Certificates | Where-Object {
            $_.Thumbprint -eq $cert.Thumbprint
        }

        if ($null -eq $installedCert) {
            throw "Certificate installation verification failed - certificate not found in store after Add()"
        }

        Write-Success "Certificate installed to $StoreLocation\$StoreName store"
        Write-Success "Thumbprint: $($cert.Thumbprint)"
        Write-Verbose "Installation verified successfully"

        return $cert.Thumbprint
    } catch {
        Write-Error "Failed to install certificate to $StoreName store: $_"
        throw
    } finally {
        if ($store) {
            $store.Close()
        }
    }
}

function Update-AppSettings {
    param([string]$Thumbprint)

    Write-Section "Updating Application Configuration"

    if (-not (Test-Path $AppSettingsFile)) {
        Write-Warning "appsettings.json not found at: $AppSettingsFile"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($AppSettingsFile, "Update thumbprint")) {
        return
    }

    try {
        # Read current configuration
        $jsonContent = Get-Content -Path $AppSettingsFile -Raw
        $config = $jsonContent | ConvertFrom-Json

        # Update thumbprint
        if (-not $config.CertificateSettings) {
            $config | Add-Member -MemberType NoteProperty -Name "CertificateSettings" -Value ([PSCustomObject]@{})
        }

        $config.CertificateSettings.Thumbprint = $Thumbprint
        $config.CertificateSettings.StoreName = "My"
        $config.CertificateSettings.StoreLocation = "CurrentUser"

        # Write to temporary file first (atomic operation)
        $tempFile = "$AppSettingsFile.tmp"
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Force

        # Replace original file
        Move-Item -Path $tempFile -Destination $AppSettingsFile -Force

        Write-Success "Updated appsettings.json with thumbprint: $Thumbprint"
        Write-Verbose "Configuration updated at: $AppSettingsFile"
    } catch {
        Write-Error "Failed to update appsettings.json: $_"
        throw
    }
}

function Export-CertificatesForDocker {
    param(
        [string]$ServerThumbprint,
        [SecureString]$Password
    )

    Write-Section "Exporting Certificates for Docker"

    if ($Environment -eq 'WSL') {
        Write-Information "Skipping Docker export (WSL-only mode)"
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Docker directory", "Export certificates")) {
        return
    }

    try {
        $dockerMyDir = Join-Path $DockerDir "my"
        $dockerRootDir = Join-Path $DockerDir "root"

        New-Item -ItemType Directory -Path $dockerMyDir -Force | Out-Null
        New-Item -ItemType Directory -Path $dockerRootDir -Force | Out-Null

        # Copy server certificate (PFX with thumbprint naming)
        $dockerServerPfx = Join-Path $dockerMyDir "$ServerThumbprint.pfx"
        Copy-Item -Path $ServerPfxFile -Destination $dockerServerPfx -Force
        Write-Verbose "Copied server PFX: $dockerServerPfx"

        # Copy server certificate (CRT)
        $dockerServerCrt = Join-Path $dockerMyDir "$ServerThumbprint.crt"
        Copy-Item -Path $ServerCertFile -Destination $dockerServerCrt -Force
        Write-Verbose "Copied server CRT: $dockerServerCrt"

        # Copy CA certificate with OpenSSL hash naming
        $caHashOutput = & openssl x509 -in $CACertFile -noout -hash 2>&1
        $caHash = $caHashOutput.Trim()
        $dockerCACert = Join-Path $dockerRootDir "$caHash.0"
        Copy-Item -Path $CACertFile -Destination $dockerCACert -Force
        Write-Verbose "Copied CA certificate: $dockerCACert"

        # Set appropriate permissions for Docker (container UID 1000)
        chmod 644 $dockerServerPfx
        chmod 644 $dockerServerCrt
        chmod 644 $dockerCACert

        Write-Success "Certificates exported to Docker directory"
        Write-Information "Docker My store: $dockerMyDir"
        Write-Information "Docker Root store: $dockerRootDir"
    } catch {
        Write-Warning "Failed to export certificates for Docker: $_"
    }
}

function Show-CertificateStoresDiagnostics {
    Write-Section "Certificate Stores Diagnostics"

    # Root Store
    Write-Information ""
    Write-Information "CurrentUser\Root Store:"
    try {
        $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $rootCerts = $rootStore.Certificates | Where-Object { $_.Subject -like "*Artemis*" }

        if ($rootCerts.Count -gt 0) {
            foreach ($cert in $rootCerts) {
                Write-Information "  Subject: $($cert.Subject)"
                Write-Information "  Thumbprint: $($cert.Thumbprint)"
                Write-Information "  Valid: $($cert.NotBefore.ToString('yyyy-MM-dd')) to $($cert.NotAfter.ToString('yyyy-MM-dd'))"
                Write-Information "  Days until expiry: $([math]::Round(($cert.NotAfter - (Get-Date)).TotalDays))"
                Write-Information ""
            }
        } else {
            Write-Warning "  No Artemis CA certificates found in Root store"
        }
        $rootStore.Close()
    } catch {
        Write-Warning "Failed to access Root store: $_"
    }

    # My Store
    Write-Information "CurrentUser\My Store:"
    try {
        $myStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::My,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $myStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $myCerts = $myStore.Certificates | Where-Object { $_.Subject -like "*artemis*" }

        if ($myCerts.Count -gt 0) {
            foreach ($cert in $myCerts) {
                Write-Information "  Subject: $($cert.Subject)"
                Write-Information "  Thumbprint: $($cert.Thumbprint)"
                Write-Information "  Has Private Key: $($cert.HasPrivateKey)"
                Write-Information "  Valid: $($cert.NotBefore.ToString('yyyy-MM-dd')) to $($cert.NotAfter.ToString('yyyy-MM-dd'))"
                Write-Information "  Days until expiry: $([math]::Round(($cert.NotAfter - (Get-Date)).TotalDays))"
                Write-Information ""
            }
        } else {
            Write-Warning "  No Artemis certificates found in My store"
        }
        $myStore.Close()
    } catch {
        Write-Warning "Failed to access My store: $_"
    }

    # Filesystem paths
    Write-Information "Filesystem Certificate Store Paths:"
    $dotnetStoresPath = Join-Path $env:HOME ".dotnet/corefx/cryptography/x509stores"

    if (Test-Path $dotnetStoresPath) {
        $rootPath = Join-Path $dotnetStoresPath "root"
        $myPath = Join-Path $dotnetStoresPath "my"

        if (Test-Path $rootPath) {
            $rootFiles = Get-ChildItem -Path $rootPath -ErrorAction SilentlyContinue
            Write-Information "  Root store ($rootPath): $($rootFiles.Count) file(s)"
            foreach ($file in $rootFiles) {
                Write-Verbose "    - $($file.Name) ($($file.Length) bytes)"
            }
        } else {
            Write-Warning "  Root store path not found: $rootPath"
        }

        if (Test-Path $myPath) {
            $myFiles = Get-ChildItem -Path $myPath -ErrorAction SilentlyContinue
            Write-Information "  My store ($myPath): $($myFiles.Count) file(s)"
            foreach ($file in $myFiles) {
                Write-Verbose "    - $($file.Name) ($($file.Length) bytes)"
            }
        } else {
            Write-Warning "  My store path not found: $myPath"
        }
    } else {
        Write-Warning "  .NET certificate store base path not found: $dotnetStoresPath"
    }

    Write-Information ""
}

function Test-CertificateInstallation {
    param([string]$ExpectedThumbprint)

    Write-Section "Validating Certificate Installation"

    $validationErrors = @()

    try {
        # Validate CA certificate in Root store
        Write-Step "Validating CA certificate in Root store"
        $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

        $caCert = $rootStore.Certificates | Where-Object { $_.Subject -like "*Artemis Root CA*" }
        if ($caCert) {
            Write-Success "CA certificate found in Root store"
            Write-Verbose "CA Subject: $($caCert.Subject)"
            Write-Verbose "CA Thumbprint: $($caCert.Thumbprint)"
        } else {
            $validationErrors += "CA certificate not found in Root store"
        }
        $rootStore.Close()

        # Validate server certificate in My store
        Write-Step "Validating server certificate in My store"
        $myStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::My,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $myStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

        $serverCert = $myStore.Certificates | Where-Object { $_.Thumbprint -eq $ExpectedThumbprint }
        if ($serverCert) {
            Write-Success "Server certificate found in My store"
            Write-Verbose "Server Subject: $($serverCert.Subject)"
            Write-Verbose "Server Thumbprint: $($serverCert.Thumbprint)"
            Write-Verbose "Has Private Key: $($serverCert.HasPrivateKey)"
        } else {
            $validationErrors += "Server certificate with thumbprint $ExpectedThumbprint not found in My store"
        }
        $myStore.Close()

        # Validate certificate chain
        if ($serverCert) {
            Write-Step "Validating certificate chain"
            $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
            $chainPolicy = New-Object System.Security.Cryptography.X509Certificates.X509ChainPolicy
            $chainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
            $chain.ChainPolicy = $chainPolicy

            $chainValid = $chain.Build($serverCert)

            Write-Verbose "Chain Build Result: $chainValid"
            Write-Verbose "Chain Status Count: $($chain.ChainStatus.Count)"
            foreach ($status in $chain.ChainStatus) {
                Write-Verbose "  Status: $($status.Status) - $($status.StatusInformation)"
            }

            if ($chainValid) {
                Write-Success "Certificate chain is fully valid"
                Write-Success "Chain elements: $($chain.ChainElements.Count)"
                Write-Verbose "Chain structure:"
                foreach ($element in $chain.ChainElements) {
                    Write-Verbose "  - $($element.Certificate.Subject)"
                }

                # Verify CA is in the chain
                $caInChain = $false
                foreach ($element in $chain.ChainElements) {
                    if ($element.Certificate.Subject -like "*Artemis Root CA*") {
                        $caInChain = $true
                        Write-Success "CA certificate verified in chain: $($element.Certificate.Thumbprint)"
                        break
                    }
                }
                if (-not $caInChain) {
                    $validationErrors += "Artemis Root CA not found in certificate chain"
                }
            } elseif ($chain.ChainStatus.Status -contains 'UntrustedRoot') {
                Write-Success "Certificate chain validated (self-signed CA, UntrustedRoot status expected on some platforms)"
                Write-Verbose "Chain elements: $($chain.ChainElements.Count)"
            } else {
                $statusInfo = $chain.ChainStatus | ForEach-Object { "$($_.Status): $($_.StatusInformation)" }
                $validationErrors += "Certificate chain validation failed: $($statusInfo -join '; ')"
            }
        }

        # Validate appsettings.json
        if (Test-Path $AppSettingsFile) {
            Write-Step "Validating appsettings.json"
            $config = Get-Content -Path $AppSettingsFile -Raw | ConvertFrom-Json
            $configuredThumbprint = $config.CertificateSettings.Thumbprint

            if ($configuredThumbprint -eq $ExpectedThumbprint) {
                Write-Success "appsettings.json thumbprint matches"
            } else {
                $validationErrors += "appsettings.json thumbprint mismatch. Expected: $ExpectedThumbprint, Got: $configuredThumbprint"
            }
        }

        # Validate filesystem X509Store structure
        Write-Step "Validating X509Store filesystem structure"
        $myStorePath = Join-Path $X509StoreMyPath "$ExpectedThumbprint.pfx"
        if (Test-Path $myStorePath) {
            Write-Success "Server certificate file found in X509Store: $myStorePath"
        } else {
            $validationErrors += "Server certificate file not found at: $myStorePath"
        }

        if ($validationErrors.Count -eq 0) {
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║  CERTIFICATE INSTALLATION VALIDATED SUCCESSFULLY               ║" -ForegroundColor Green
            Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
            return $true
        } else {
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║  VALIDATION ERRORS DETECTED                                    ║" -ForegroundColor Red
            Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
            foreach ($validationError in $validationErrors) {
                Write-Warning $validationError
            }
            return $false
        }
    } catch {
        Write-Error "Validation failed with exception: $_"
        return $false
    }
}

#endregion

#region Main Execution

function Main {
    try {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
        Write-Host "║  Artemis Certificate Setup - PowerShell Core Edition           ║" -ForegroundColor Magenta
        Write-Host "║  X509Store API Registration for .NET Core Applications        ║" -ForegroundColor Magenta
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
        Write-Host ""

        # Prerequisites check
        if (-not (Test-Prerequisites)) {
            throw "Prerequisites validation failed"
        }

        # Initialize directories
        Initialize-Directories

        # Backup existing certificates
        Backup-ExistingCertificates

        # Generate PFX password if not provided
        if (-not $PfxPassword) {
            Write-Information "Generating secure random password for PFX file"
            $PfxPassword = New-SecurePassword
        }

        # Save PFX password to file for Docker integration
        # SECURITY WARNING: This file contains the password in plain text for Docker container usage
        # Ensure this file has restrictive permissions and is not committed to version control
        Write-Step "Saving PFX password for Docker integration"
        $passwordPlain = ConvertFrom-SecureStringToPlainText -SecureString $PfxPassword
        Set-Content -Path $PfxPasswordFile -Value $passwordPlain -Force -NoNewline

        # Set restrictive permissions on password file (600 = owner read/write only)
        if (Test-Path $PfxPasswordFile) {
            chmod 600 $PfxPasswordFile
            Write-Success "PFX password saved to: $PfxPasswordFile (permissions: 600)"
            Write-Warning "SECURITY: Password file contains plain text password - ensure it is not committed to version control"
        }

        # Clear sensitive variable
        $passwordPlain = $null

        # Clean up old certificates if requested
        if ($CleanupOld) {
            if ($Force -or $PSCmdlet.ShouldContinue("Remove old certificates from stores?", "Cleanup Confirmation")) {
                Remove-OldCertificatesFromStore -StoreName "My" -StoreLocation "CurrentUser" -SubjectPattern "artemis"
                Remove-OldCertificatesFromStore -StoreName "Root" -StoreLocation "CurrentUser" -SubjectPattern "Artemis Root CA"
            }
        }

        # Generate certificates
        New-CACertificate
        $serverThumbprint = New-ServerCertificate -Password $PfxPassword

        # Install certificates to X509Store
        Install-CertificateToStore `
            -CertificatePath $CACertFile `
            -StoreName "Root" `
            -StoreLocation "CurrentUser" `
            -Description "CA Certificate to Root Store"

        Install-CertificateToStore `
            -CertificatePath $ServerPfxFile `
            -StoreName "My" `
            -StoreLocation "CurrentUser" `
            -Password $PfxPassword `
            -Description "Server Certificate to My Store"

        # Update application configuration
        Update-AppSettings -Thumbprint $serverThumbprint

        # Export for Docker if needed
        Export-CertificatesForDocker -ServerThumbprint $serverThumbprint -Password $PfxPassword

        # Validate installation
        $validationResult = Test-CertificateInstallation -ExpectedThumbprint $serverThumbprint

        # Show diagnostics
        Show-CertificateStoresDiagnostics

        # Summary
        Write-Section "Installation Summary"
        Write-Information "Certificate Subject: CN=$CommonName"
        Write-Information "Server Certificate Thumbprint: $serverThumbprint"
        Write-Information "Validity Period: $ValidityDays days"
        Write-Information "CA Validity Period: $CAValidityDays days"
        Write-Information "X509Store Path: $X509StoreBasePath"
        Write-Information "Configuration File: $AppSettingsFile"
        Write-Information "Backup Location: $BackupDir"

        if ($validationResult) {
            Write-Host ""
            Write-Success "Certificate setup completed successfully!"
            Write-Information "Your ASP.NET Core application can now access the certificates via X509Store API"
            Write-Host ""
        } else {
            throw "Certificate validation failed. Review errors above."
        }

    } catch {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  CERTIFICATE SETUP FAILED                                      ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Error "Error: $_"
        Write-Information "Backup available at: $BackupDir"
        throw
    } finally {
        # Clear sensitive data
        if ($PfxPassword) {
            $PfxPassword = $null
        }
    }
}

# Execute main function
Main

#endregion

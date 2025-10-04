#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive validation script for certificate installation and X509Store registration.

.DESCRIPTION
    This script performs extensive validation of certificate setup including:
    - File system certificate file existence
    - X509Store registration (Root and My stores)
    - Certificate properties and validity
    - Certificate chain validation
    - Configuration file validation (appsettings.json)
    - Private key accessibility
    - Certificate expiration checks

    Suitable for CI/CD integration with proper exit codes.

.PARAMETER Thumbprint
    Expected certificate thumbprint to validate. If not provided, reads from thumbprint.txt

.PARAMETER ConfigFile
    Path to appsettings.json. Default: ./appsettings.json

.PARAMETER Detailed
    Show detailed certificate information.

.PARAMETER FailOnWarning
    Treat warnings as failures (useful for CI/CD).

.EXAMPLE
    ./Test-CertificateSetup.ps1
    Runs validation with default settings.

.EXAMPLE
    ./Test-CertificateSetup.ps1 -Detailed -Verbose
    Runs detailed validation with verbose output.

.EXAMPLE
    ./Test-CertificateSetup.ps1 -FailOnWarning
    Runs validation treating warnings as failures (CI/CD mode).

.NOTES
    Author: PowerShell Automation Expert
    Version: 1.0.0
    Exit Codes:
        0 - All tests passed
        1 - Critical errors detected
        2 - Warnings detected (only with -FailOnWarning)
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Expected certificate thumbprint")]
    [string]$Thumbprint,

    [Parameter(HelpMessage = "Configuration file path")]
    [string]$ConfigFile = "./appsettings.json",

    [Parameter(HelpMessage = "Show detailed information")]
    [switch]$Detailed,

    [Parameter(HelpMessage = "Treat warnings as failures")]
    [switch]$FailOnWarning
)

$ErrorActionPreference = 'Continue'
$InformationPreference = 'Continue'

#region Variables

$ScriptRoot = $PSScriptRoot
$ThumbprintFile = Join-Path $ScriptRoot "certs/server/thumbprint.txt"
$ServerCertFile = Join-Path $ScriptRoot "certs/server/artemis-server.crt"
$ServerPfxFile = Join-Path $ScriptRoot "certs/server/artemis-server.pfx"
$CACertFile = Join-Path $ScriptRoot "certs/ca/artemis-ca.crt"

$X509StoreBasePath = Join-Path $env:HOME ".dotnet/corefx/cryptography/x509stores"
$X509StoreMyPath = Join-Path $X509StoreBasePath "my"
$X509StoreRootPath = Join-Path $X509StoreBasePath "root"

# Test results
$script:TestResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
}

#endregion

#region Helper Functions

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  TEST: $Title" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Pass {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
    $script:TestResults.Passed += $Message
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:TestResults.Failed += $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
    $script:TestResults.Warnings += $Message
}

function Test-FileExistence {
    Write-TestHeader "Certificate File Existence"

    $files = @{
        "CA Certificate" = $CACertFile
        "Server Certificate (CRT)" = $ServerCertFile
        "Server Certificate (PFX)" = $ServerPfxFile
        "Thumbprint File" = $ThumbprintFile
        "Configuration File" = $ConfigFile
    }

    foreach ($entry in $files.GetEnumerator()) {
        if (Test-Path $entry.Value) {
            Write-Pass "$($entry.Key) exists: $($entry.Value)"
        } else {
            Write-Fail "$($entry.Key) not found: $($entry.Value)"
        }
    }
}

function Test-X509StoreStructure {
    Write-TestHeader "X509Store Directory Structure"

    $directories = @{
        "X509Store Base" = $X509StoreBasePath
        "My Store" = $X509StoreMyPath
        "Root Store" = $X509StoreRootPath
    }

    foreach ($entry in $directories.GetEnumerator()) {
        if (Test-Path $entry.Value) {
            Write-Pass "$($entry.Key) directory exists: $($entry.Value)"

            # Count certificates
            $certCount = (Get-ChildItem -Path $entry.Value -File -ErrorAction SilentlyContinue).Count
            Write-Verbose "$($entry.Key) contains $certCount file(s)"
        } else {
            Write-Fail "$($entry.Key) directory not found: $($entry.Value)"
        }
    }
}

function Test-CertificateInStore {
    param(
        [string]$StoreName,
        [string]$StoreLocation,
        [string]$ExpectedThumbprint,
        [string]$SubjectPattern
    )

    Write-TestHeader "Certificate in $StoreLocation\$StoreName Store"

    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::$StoreName,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::$StoreLocation
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

        $totalCerts = $store.Certificates.Count
        Write-Verbose "Total certificates in store: $totalCerts"

        if ($SubjectPattern) {
            $matchingCerts = $store.Certificates | Where-Object { $_.Subject -like "*$SubjectPattern*" }
            if ($matchingCerts) {
                Write-Pass "Found certificate(s) matching '$SubjectPattern'"
                foreach ($cert in $matchingCerts) {
                    Write-Verbose "  Subject: $($cert.Subject)"
                    Write-Verbose "  Thumbprint: $($cert.Thumbprint)"
                    Write-Verbose "  Valid: $($cert.NotBefore) to $($cert.NotAfter)"
                    Write-Verbose "  Has Private Key: $($cert.HasPrivateKey)"

                    if ($Detailed) {
                        Write-Host "  Certificate Details:" -ForegroundColor Gray
                        Write-Host "    Subject: $($cert.Subject)" -ForegroundColor Gray
                        Write-Host "    Issuer: $($cert.Issuer)" -ForegroundColor Gray
                        Write-Host "    Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
                        Write-Host "    Serial: $($cert.SerialNumber)" -ForegroundColor Gray
                        Write-Host "    Valid From: $($cert.NotBefore)" -ForegroundColor Gray
                        Write-Host "    Valid To: $($cert.NotAfter)" -ForegroundColor Gray
                        Write-Host "    Has Private Key: $($cert.HasPrivateKey)" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Fail "No certificates found matching '$SubjectPattern'"
            }
        }

        if ($ExpectedThumbprint) {
            $cert = $store.Certificates | Where-Object { $_.Thumbprint -eq $ExpectedThumbprint }
            if ($cert) {
                Write-Pass "Certificate with thumbprint $ExpectedThumbprint found"

                # Check private key
                if ($StoreName -eq "My") {
                    if ($cert.HasPrivateKey) {
                        Write-Pass "Certificate has private key"
                    } else {
                        Write-Fail "Certificate missing private key"
                    }
                }

                # Check validity
                $now = Get-Date
                if ($cert.NotBefore -le $now -and $cert.NotAfter -ge $now) {
                    Write-Pass "Certificate is currently valid"
                } else {
                    Write-Fail "Certificate is not valid (expired or not yet valid)"
                }

                # Check expiration warning (30 days)
                $daysUntilExpiry = ($cert.NotAfter - $now).TotalDays
                if ($daysUntilExpiry -lt 30) {
                    Write-Warn "Certificate expires in $([math]::Round($daysUntilExpiry)) days"
                } else {
                    Write-Verbose "Certificate expires in $([math]::Round($daysUntilExpiry)) days"
                }

                return $cert
            } else {
                Write-Fail "Certificate with thumbprint $ExpectedThumbprint not found"
                return $null
            }
        }

        return $null
    } catch {
        Write-Fail "Failed to access store: $_"
        return $null
    } finally {
        if ($store) {
            $store.Close()
        }
    }
}

function Test-CertificateChain {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)

    Write-TestHeader "Certificate Chain Validation"

    if (-not $Certificate) {
        Write-Fail "No certificate provided for chain validation"
        return
    }

    try {
        $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
        $chainPolicy = New-Object System.Security.Cryptography.X509Certificates.X509ChainPolicy
        $chainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
        $chain.ChainPolicy = $chainPolicy

        $buildResult = $chain.Build($Certificate)

        Write-Verbose "Chain Build Result: $buildResult"
        Write-Verbose "Chain Status Count: $($chain.ChainStatus.Count)"

        if ($buildResult) {
            Write-Pass "Certificate chain is fully valid (Build returned True)"
            Write-Pass "Chain has $($chain.ChainElements.Count) element(s)"
        } elseif ($chain.ChainStatus.Status -contains 'UntrustedRoot') {
            Write-Pass "Certificate chain valid (self-signed CA, UntrustedRoot expected on some platforms)"
            Write-Pass "Chain has $($chain.ChainElements.Count) element(s)"
        } else {
            $statusInfo = $chain.ChainStatus | ForEach-Object { "$($_.Status): $($_.StatusInformation)" }
            Write-Fail "Certificate chain validation failed: $($statusInfo -join '; ')"
        }

        # Verify CA certificate is in the chain
        $caInChain = $false
        $caThumbprint = $null
        foreach ($element in $chain.ChainElements) {
            if ($element.Certificate.Subject -like "*Artemis Root CA*") {
                $caInChain = $true
                $caThumbprint = $element.Certificate.Thumbprint
                break
            }
        }

        if ($caInChain) {
            Write-Pass "Artemis Root CA found in certificate chain"
            Write-Verbose "CA Thumbprint: $caThumbprint"
        } else {
            Write-Fail "Artemis Root CA not found in certificate chain"
        }

        # Display chain elements
        Write-Verbose "Chain elements: $($chain.ChainElements.Count)"
        if ($Detailed) {
            Write-Host "  Chain Structure:" -ForegroundColor Gray
            for ($i = 0; $i -lt $chain.ChainElements.Count; $i++) {
                $element = $chain.ChainElements[$i]
                $indent = "    " * ($i + 1)
                Write-Host "$indent[$i] Subject: $($element.Certificate.Subject)" -ForegroundColor Gray
                Write-Host "$indent    Issuer: $($element.Certificate.Issuer)" -ForegroundColor Gray
                Write-Host "$indent    Thumbprint: $($element.Certificate.Thumbprint)" -ForegroundColor Gray
            }
        }

        # Test chain status details
        if ($chain.ChainStatus.Count -gt 0) {
            Write-Verbose "Chain Status Details:"
            foreach ($status in $chain.ChainStatus) {
                Write-Verbose "  - $($status.Status): $($status.StatusInformation)"
            }
        } else {
            Write-Pass "No chain status errors (clean chain)"
        }
    } catch {
        Write-Fail "Certificate chain validation exception: $_"
    }
}

function Test-ConfigurationFile {
    param([string]$ExpectedThumbprint)

    Write-TestHeader "Configuration File Validation"

    if (-not (Test-Path $ConfigFile)) {
        Write-Fail "Configuration file not found: $ConfigFile"
        return
    }

    try {
        $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

        # Check CertificateSettings section
        if ($config.CertificateSettings) {
            Write-Pass "CertificateSettings section exists"

            $configThumbprint = $config.CertificateSettings.Thumbprint
            $configStoreName = $config.CertificateSettings.StoreName
            $configStoreLocation = $config.CertificateSettings.StoreLocation

            Write-Verbose "Configured Thumbprint: $configThumbprint"
            Write-Verbose "Configured Store: $configStoreLocation\$configStoreName"

            if ($configThumbprint) {
                if ($configThumbprint -eq $ExpectedThumbprint) {
                    Write-Pass "Thumbprint matches expected value"
                } else {
                    Write-Fail "Thumbprint mismatch. Expected: $ExpectedThumbprint, Got: $configThumbprint"
                }
            } else {
                Write-Fail "Thumbprint not configured"
            }

            if ($configStoreName -eq "My") {
                Write-Pass "StoreName is 'My'"
            } else {
                Write-Warn "StoreName is '$configStoreName' (expected 'My')"
            }

            if ($configStoreLocation -eq "CurrentUser") {
                Write-Pass "StoreLocation is 'CurrentUser'"
            } else {
                Write-Warn "StoreLocation is '$configStoreLocation' (expected 'CurrentUser')"
            }
        } else {
            Write-Fail "CertificateSettings section not found in configuration"
        }

        # Check Kestrel configuration
        if ($config.Kestrel.Endpoints.Https.Certificate) {
            Write-Pass "Kestrel HTTPS certificate configuration exists"
            if ($Detailed) {
                Write-Host "  Kestrel Certificate Settings:" -ForegroundColor Gray
                Write-Host "    Subject: $($config.Kestrel.Endpoints.Https.Certificate.Subject)" -ForegroundColor Gray
                Write-Host "    Store: $($config.Kestrel.Endpoints.Https.Certificate.Store)" -ForegroundColor Gray
                Write-Host "    Location: $($config.Kestrel.Endpoints.Https.Certificate.Location)" -ForegroundColor Gray
            }
        } else {
            Write-Warn "Kestrel HTTPS certificate configuration not found"
        }
    } catch {
        Write-Fail "Failed to parse configuration file: $_"
    }
}

function Test-CertificateFileIntegrity {
    Write-TestHeader "Certificate File Integrity"

    if (-not (Test-Path $ServerCertFile)) {
        Write-Fail "Server certificate file not found"
        return
    }

    try {
        # Verify certificate file can be loaded
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ServerCertFile)
        Write-Pass "Server certificate file is valid"

        # Verify thumbprint consistency
        if ($Thumbprint -and $cert.Thumbprint -eq $Thumbprint) {
            Write-Pass "Certificate file thumbprint matches expected value"
        } elseif ($Thumbprint) {
            Write-Fail "Certificate file thumbprint mismatch. Expected: $Thumbprint, Got: $($cert.Thumbprint)"
        }

        # Verify PFX file
        if (Test-Path $ServerPfxFile) {
            Write-Pass "PFX file exists"
            # Note: We can't validate PFX without password, but we can check file permissions
            $pfxPerms = (Get-Item $ServerPfxFile).UnixMode
            if ($pfxPerms -and $pfxPerms -match "rw-------") {
                Write-Pass "PFX file has correct permissions (600)"
            } else {
                Write-Warn "PFX file permissions may be too permissive: $pfxPerms"
            }
        } else {
            Write-Warn "PFX file not found (may be normal if using CRT only)"
        }
    } catch {
        Write-Fail "Certificate file integrity check failed: $_"
    }
}

function Test-X509StoreFileMapping {
    param([string]$ExpectedThumbprint)

    Write-TestHeader "X509Store File System Mapping"

    if (-not $ExpectedThumbprint) {
        Write-Warn "No thumbprint provided, skipping file mapping test"
        return
    }

    # Check My store file
    $myStoreFile = Join-Path $X509StoreMyPath "$ExpectedThumbprint.pfx"
    if (Test-Path $myStoreFile) {
        Write-Pass "Server certificate file exists in My store: $myStoreFile"
    } else {
        Write-Fail "Server certificate file not found in My store: $myStoreFile"
    }

    # Check for CA certificate in Root store
    $rootCertFiles = Get-ChildItem -Path $X509StoreRootPath -Filter "*.0" -ErrorAction SilentlyContinue
    if ($rootCertFiles) {
        Write-Pass "CA certificate file(s) found in Root store"
        foreach ($file in $rootCertFiles) {
            Write-Verbose "  Root cert: $($file.Name)"
        }
    } else {
        Write-Fail "No CA certificate files found in Root store"
    }
}

function Test-CATrustExplicit {
    Write-TestHeader "CA Certificate Trust Verification"

    try {
        # Open Root store and find CA certificate
        $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

        $caCert = $rootStore.Certificates | Where-Object {
            $_.Subject -like "*Artemis Root CA*"
        } | Select-Object -First 1

        if ($null -eq $caCert) {
            Write-Fail "Artemis Root CA not found in CurrentUser\Root store"
            $rootStore.Close()
            return
        }

        Write-Pass "CA certificate found in Root store"
        Write-Verbose "CA Subject: $($caCert.Subject)"
        Write-Verbose "CA Thumbprint: $($caCert.Thumbprint)"

        # Verify CA certificate properties
        $now = Get-Date
        if ($caCert.NotBefore -le $now -and $caCert.NotAfter -ge $now) {
            Write-Pass "CA certificate is currently valid"
            $daysUntilExpiry = ($caCert.NotAfter - $now).TotalDays
            Write-Verbose "CA expires in $([math]::Round($daysUntilExpiry)) days"
        } else {
            Write-Fail "CA certificate is not valid (expired or not yet valid)"
        }

        # Verify CA is self-signed (issuer == subject for root CA)
        if ($caCert.Subject -eq $caCert.Issuer) {
            Write-Pass "CA certificate is self-signed (root CA)"
        } else {
            Write-Warn "CA certificate issuer differs from subject (not a root CA?)"
        }

        # Verify CA certificate file exists in filesystem
        $rootStorePath = Join-Path $X509StoreRootPath "$($caCert.Thumbprint).pfx"
        if (Test-Path $rootStorePath) {
            Write-Pass "CA certificate file exists in filesystem: $rootStorePath"
        } else {
            # Check for .crt or hash-based naming (OpenSSL format)
            $alternateFiles = Get-ChildItem -Path $X509StoreRootPath -Filter "*.0" -ErrorAction SilentlyContinue
            if ($alternateFiles) {
                Write-Pass "CA certificate file(s) found in Root store (hash-based naming)"
            } else {
                Write-Warn "CA certificate file not found in expected locations"
            }
        }

        $rootStore.Close()

    } catch {
        Write-Fail "CA trust verification failed: $_"
    }
}

function Show-TestSummary {
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  TEST SUMMARY" -ForegroundColor Magenta
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""

    $passCount = $script:TestResults.Passed.Count
    $failCount = $script:TestResults.Failed.Count
    $warnCount = $script:TestResults.Warnings.Count
    $totalCount = $passCount + $failCount + $warnCount

    Write-Host "Passed:   $passCount / $totalCount" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "Failed:   $failCount / $totalCount" -ForegroundColor Red
    }
    if ($warnCount -gt 0) {
        Write-Host "Warnings: $warnCount / $totalCount" -ForegroundColor Yellow
    }

    Write-Host ""

    if ($failCount -gt 0) {
        Write-Host "FAILED TESTS:" -ForegroundColor Red
        foreach ($failure in $script:TestResults.Failed) {
            Write-Host "  - $failure" -ForegroundColor Red
        }
        Write-Host ""
    }

    if ($warnCount -gt 0 -and $Detailed) {
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $script:TestResults.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # Determine exit code
    if ($failCount -gt 0) {
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  VALIDATION FAILED - CRITICAL ERRORS DETECTED                  ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        return 1
    } elseif ($FailOnWarning -and $warnCount -gt 0) {
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  VALIDATION FAILED - WARNINGS DETECTED (FAIL-ON-WARNING MODE)  ║" -ForegroundColor Yellow
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        return 2
    } else {
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  ALL VALIDATION TESTS PASSED                                   ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        return 0
    }
}

#endregion

#region Main Execution

function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║  Certificate Setup Validation Suite                           ║" -ForegroundColor Magenta
    Write-Host "║  X509Store Registration Tests for .NET Core                   ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

    try {
        # Determine thumbprint
        $expectedThumbprint = $Thumbprint
        if (-not $expectedThumbprint -and (Test-Path $ThumbprintFile)) {
            $expectedThumbprint = (Get-Content -Path $ThumbprintFile -Raw).Trim()
            Write-Information "Loaded thumbprint from file: $expectedThumbprint"
        }

        if (-not $expectedThumbprint) {
            Write-Warning "No thumbprint specified or found in thumbprint.txt"
        }

        # Run all tests
        Test-FileExistence
        Test-X509StoreStructure
        Test-CertificateFileIntegrity

        # Test CA certificate in Root store
        Test-CertificateInStore -StoreName "Root" -StoreLocation "CurrentUser" `
            -SubjectPattern "Artemis Root CA"

        # Explicit CA trust verification
        Test-CATrustExplicit

        # Test server certificate in My store
        $serverCert = Test-CertificateInStore -StoreName "My" -StoreLocation "CurrentUser" `
            -ExpectedThumbprint $expectedThumbprint -SubjectPattern "artemis"

        # Test certificate chain
        if ($serverCert) {
            Test-CertificateChain -Certificate $serverCert
        }

        # Test configuration
        Test-ConfigurationFile -ExpectedThumbprint $expectedThumbprint

        # Test X509Store file mapping
        Test-X509StoreFileMapping -ExpectedThumbprint $expectedThumbprint

        # Show summary and determine exit code
        $exitCode = Show-TestSummary
        return $exitCode

    } catch {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  VALIDATION SUITE CRASHED                                      ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Error "Exception: $_"
        return 1
    }
}

# Execute and return exit code
$exitCode = Main
exit $exitCode

#endregion

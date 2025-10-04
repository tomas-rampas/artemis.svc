#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Docker container entrypoint script for Artemis API.

.DESCRIPTION
    This script is executed when the Docker container starts. It performs the following:
    1. Validates PowerShell is available (pwsh)
    2. Verifies Install-DockerCertificates.ps1 exists
    3. Runs certificate installation with proper error handling
    4. Starts the .NET application

.NOTES
    Author: PowerShell Automation Expert
    Version: 1.0.0
    Platform: Docker containers (Linux)
    Usage: Container ENTRYPOINT
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

#region Helper Functions

function Write-Banner {
    param([string]$Message)
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Write-StepMessage {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

#endregion

#region Main Execution

try {
    Write-Banner "Artemis API - Container Startup"
    Write-Host ""

    # Check if PowerShell is available
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshPath) {
        Write-ErrorMessage "PowerShell not found in container"
        exit 1
    }

    # Check if certificate installation script exists
    $certScriptPath = "/app/Install-DockerCertificates.ps1"
    if (-not (Test-Path $certScriptPath)) {
        Write-ErrorMessage "Install-DockerCertificates.ps1 not found at $certScriptPath"
        exit 1
    }

    # Run certificate installation
    Write-StepMessage "Installing certificates..."

    $installResult = & pwsh -File $certScriptPath -Force -Verbose
    $exitCode = $LASTEXITCODE

    # Check if certificate installation succeeded
    if ($exitCode -ne 0) {
        Write-ErrorMessage "Certificate installation failed with exit code: $exitCode"
        exit 1
    }

    Write-Host ""
    Write-Banner "Starting Artemis API..."
    Write-Host ""

    # Start the .NET application
    # Using & instead of exec since PowerShell doesn't have exec like bash
    & dotnet artemis.svc.dll

    # Capture exit code from dotnet
    exit $LASTEXITCODE

} catch {
    Write-ErrorMessage "Container startup failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion

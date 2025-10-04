#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Docker Compose startup script with certificate environment variables.

.DESCRIPTION
    This script sets up environment variables for certificate integration before starting Docker containers.
    It reads certificate thumbprint and PFX password from files, exports them as environment variables,
    and executes docker-compose commands.

.PARAMETER Command
    Docker Compose command to execute. Valid values: build, up, down, restart, logs, status, default (up -d).
    Default: "default" (starts containers in detached mode)

.PARAMETER Detached
    Run containers in detached mode (background). Only applies when Command is "up".
    Default: $true for "default" command, $false for explicit "up" command

.EXAMPLE
    ./Start-DockerCompose.ps1
    Starts Docker containers in detached mode (background).

.EXAMPLE
    ./Start-DockerCompose.ps1 -Command build
    Builds Docker images.

.EXAMPLE
    ./Start-DockerCompose.ps1 -Command up
    Starts Docker containers in foreground mode.

.EXAMPLE
    ./Start-DockerCompose.ps1 -Command logs
    Shows Docker container logs (follows).

.EXAMPLE
    ./Start-DockerCompose.ps1 -Command down
    Stops Docker containers.

.EXAMPLE
    ./Start-DockerCompose.ps1 -Command restart
    Restarts Docker containers.

.EXAMPLE
    ./Start-DockerCompose.ps1 -Command status
    Shows status of Docker containers.

.NOTES
    Author: PowerShell Automation Expert
    Version: 1.0.0
    Platform: Cross-platform (Windows, Linux, macOS)
    Requires: Docker, Docker Compose, PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, HelpMessage = "Docker Compose command to execute")]
    [ValidateSet("build", "up", "down", "restart", "logs", "status", "default")]
    [string]$Command = "default",

    [Parameter(HelpMessage = "Run containers in detached mode")]
    [switch]$Detached
)

$ErrorActionPreference = 'Stop'

#region Helper Functions

function Write-Banner {
    param([string]$Message)
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-InfoMessage {
    param([string]$Message, [string]$Value)
    if ($Value) {
        Write-Host "  ${Message}: " -NoNewline -ForegroundColor White
        Write-Host $Value -ForegroundColor Cyan
    } else {
        Write-Host "  $Message" -ForegroundColor White
    }
}

#endregion

#region Main Execution

try {
    Write-Banner "Artemis API - Docker Startup with Certificates"
    Write-Host ""

    # Define file paths
    $thumbprintFile = Join-Path $PSScriptRoot "certs/server/thumbprint.txt"
    $passwordFile = Join-Path $PSScriptRoot "certs/server/pfx-password.txt"

    # Check if thumbprint file exists
    if (-not (Test-Path $thumbprintFile)) {
        Write-ErrorMessage "Thumbprint file not found at $thumbprintFile"
        Write-Host ""
        Write-Host "Please run the certificate setup first:" -ForegroundColor Yellow
        Write-Host "  pwsh ./Setup-Certificates.ps1" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    # Check if password file exists
    if (-not (Test-Path $passwordFile)) {
        Write-ErrorMessage "PFX password file not found at $passwordFile"
        Write-Host ""
        Write-Host "Please run the certificate setup first:" -ForegroundColor Yellow
        Write-Host "  pwsh ./Setup-Certificates.ps1" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    # Read thumbprint and password from files
    $certThumbprint = (Get-Content $thumbprintFile -Raw).Trim()
    $certPfxPassword = (Get-Content $passwordFile -Raw).Trim()

    # Validate thumbprint
    if ([string]::IsNullOrWhiteSpace($certThumbprint)) {
        Write-ErrorMessage "Thumbprint file is empty"
        exit 1
    }

    # Validate password
    if ([string]::IsNullOrWhiteSpace($certPfxPassword)) {
        Write-ErrorMessage "Password file is empty"
        exit 1
    }

    Write-SuccessMessage "Certificate configuration loaded:"
    Write-InfoMessage "Thumbprint" $certThumbprint
    Write-InfoMessage "Password" "[PROTECTED]"
    Write-Host ""

    # Export environment variables for docker-compose
    $env:CERT_THUMBPRINT = $certThumbprint
    $env:CERT_PFX_PASSWORD = $certPfxPassword

    # Execute docker-compose command
    switch ($Command) {
        "build" {
            Write-Host "Building Docker images..." -ForegroundColor Yellow
            docker-compose build
        }
        "up" {
            if ($Detached) {
                Write-Host "Starting Docker containers (background)..." -ForegroundColor Yellow
                docker-compose up -d
            } else {
                Write-Host "Starting Docker containers (foreground)..." -ForegroundColor Yellow
                docker-compose up
            }
        }
        "down" {
            Write-Host "Stopping Docker containers..." -ForegroundColor Yellow
            docker-compose down
        }
        "restart" {
            Write-Host "Restarting Docker containers..." -ForegroundColor Yellow
            docker-compose restart
        }
        "logs" {
            Write-Host "Showing Docker container logs..." -ForegroundColor Yellow
            docker-compose logs -f
        }
        "status" {
            Write-Host "Docker container status:" -ForegroundColor Yellow
            docker-compose ps
        }
        "default" {
            # Default: up in detached mode
            Write-Host "Starting Docker containers (background)..." -ForegroundColor Yellow
            docker-compose up -d

            Write-Host ""
            Write-SuccessMessage "Containers started successfully!"
            Write-Host ""
            Write-Host "View logs with:" -ForegroundColor Cyan
            Write-Host "  pwsh ./Start-DockerCompose.ps1 -Command logs" -ForegroundColor White
            Write-Host ""
            Write-Host "Stop containers with:" -ForegroundColor Cyan
            Write-Host "  pwsh ./Start-DockerCompose.ps1 -Command down" -ForegroundColor White
            Write-Host ""
            Write-Host "Access the API at:" -ForegroundColor Cyan
            Write-Host "  HTTP:    http://localhost:5000/api/invoices" -ForegroundColor White
            Write-Host "  HTTPS:   https://localhost:5001/api/invoices" -ForegroundColor White
            Write-Host "  Swagger: https://localhost:5001/" -ForegroundColor White
            Write-Host ""
        }
    }

    # Check docker-compose exit code
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "docker-compose command failed with exit code: $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    exit 0

} catch {
    Write-ErrorMessage "Script execution failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    # Clear sensitive environment variables
    $env:CERT_PFX_PASSWORD = $null
}

#endregion

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build Red Hat UBI base Docker images for Artemis API.

.DESCRIPTION
    Builds the Red Hat Universal Base Image (UBI) Docker images required for the Artemis API:
    1. artemis/ubi8-dotnet-sdk:9.0 - SDK image for building .NET applications
    2. artemis/ubi8-aspnet-runtime:9.0 - Runtime image with ASP.NET Core and PowerShell

    Corporate requirement: Use Red Hat UBI instead of Microsoft official images.

.PARAMETER BuildSdkOnly
    Build only the SDK base image.

.PARAMETER BuildRuntimeOnly
    Build only the runtime base image.

.PARAMETER NoBuildCache
    Build images without using Docker cache (clean build).

.EXAMPLE
    .\build-base-images.ps1
    Builds both SDK and runtime base images.

.EXAMPLE
    .\build-base-images.ps1 -NoBuildCache
    Builds both images without using Docker cache.

.EXAMPLE
    .\build-base-images.ps1 -BuildSdkOnly
    Builds only the SDK base image.

.NOTES
    These base images must be built before running docker-compose build.
    Author: Artemis Development Team
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Build only the SDK base image")]
    [switch]$BuildSdkOnly,

    [Parameter(HelpMessage = "Build only the runtime base image")]
    [switch]$BuildRuntimeOnly,

    [Parameter(HelpMessage = "Build without using Docker cache")]
    [switch]$NoBuildCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Color output functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Main script
try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Push-Location $scriptDir

    Write-Info "Starting Red Hat UBI base image build process..."
    Write-Info "Script directory: $scriptDir"
    Write-Info "Docker version: $(docker --version)"
    Write-Info ""

    # Determine build cache flag
    $cacheFlag = if ($NoBuildCache) { "--no-cache" } else { "" }
    if ($NoBuildCache) {
        Write-Warning "Building without Docker cache (clean build)..."
    }

    # Build SDK image
    if (-not $BuildRuntimeOnly) {
        Write-Info "========================================="
        Write-Info "Building artemis/ubi8-dotnet-sdk:9.0"
        Write-Info "========================================="

        $sdkDockerfile = Join-Path $scriptDir "Dockerfile.ubi8-dotnet-sdk"
        if (-not (Test-Path $sdkDockerfile)) {
            throw "SDK Dockerfile not found: $sdkDockerfile"
        }

        Write-Info "Dockerfile: $sdkDockerfile"
        Write-Info "Starting build..."

        $buildArgs = @(
            "build",
            "-f", $sdkDockerfile,
            "-t", "artemis/ubi8-dotnet-sdk:9.0",
            "."
        )

        if ($cacheFlag) {
            $buildArgs += $cacheFlag
        }

        $sdkBuildStart = Get-Date
        & docker @buildArgs

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build SDK image. Exit code: $LASTEXITCODE"
        }

        $sdkBuildDuration = (Get-Date) - $sdkBuildStart
        Write-Success "SDK image built successfully in $($sdkBuildDuration.TotalSeconds.ToString('F2')) seconds"
        Write-Info ""
    }

    # Build runtime image
    if (-not $BuildSdkOnly) {
        Write-Info "========================================="
        Write-Info "Building artemis/ubi8-aspnet-runtime:9.0"
        Write-Info "========================================="

        $runtimeDockerfile = Join-Path $scriptDir "Dockerfile.ubi8-aspnet-runtime"
        if (-not (Test-Path $runtimeDockerfile)) {
            throw "Runtime Dockerfile not found: $runtimeDockerfile"
        }

        Write-Info "Dockerfile: $runtimeDockerfile"
        Write-Info "Starting build..."

        $buildArgs = @(
            "build",
            "-f", $runtimeDockerfile,
            "-t", "artemis/ubi8-aspnet-runtime:9.0",
            "."
        )

        if ($cacheFlag) {
            $buildArgs += $cacheFlag
        }

        $runtimeBuildStart = Get-Date
        & docker @buildArgs

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build runtime image. Exit code: $LASTEXITCODE"
        }

        $runtimeBuildDuration = (Get-Date) - $runtimeBuildStart
        Write-Success "Runtime image built successfully in $($runtimeBuildDuration.TotalSeconds.ToString('F2')) seconds"
        Write-Info ""
    }

    # Display image information
    Write-Info "========================================="
    Write-Info "Image Build Summary"
    Write-Info "========================================="

    $images = docker images --filter "reference=artemis/ubi8-*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

    if ($LASTEXITCODE -eq 0 -and $images) {
        Write-Info "Built images:"
        Write-Host $images
        Write-Info ""
    }

    # Verify .NET and PowerShell versions
    Write-Info "========================================="
    Write-Info "Verification"
    Write-Info "========================================="

    if (-not $BuildRuntimeOnly) {
        Write-Info "Verifying SDK image..."
        $sdkVersion = docker run --rm artemis/ubi8-dotnet-sdk:9.0 dotnet --version
        if ($LASTEXITCODE -eq 0) {
            Write-Success "SDK .NET version: $sdkVersion"
        } else {
            Write-Warning "Could not verify SDK .NET version"
        }
    }

    if (-not $BuildSdkOnly) {
        Write-Info "Verifying runtime image..."
        $runtimeDotnetVersion = docker run --rm artemis/ubi8-aspnet-runtime:9.0 dotnet --version
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Runtime .NET version: $runtimeDotnetVersion"
        } else {
            Write-Warning "Could not verify runtime .NET version"
        }

        $pwshVersion = docker run --rm artemis/ubi8-aspnet-runtime:9.0 pwsh -Command '$PSVersionTable.PSVersion.ToString()'
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Runtime PowerShell version: $pwshVersion"
        } else {
            Write-Warning "Could not verify runtime PowerShell version"
        }
    }

    Write-Info ""
    Write-Success "========================================="
    Write-Success "Base image build process completed!"
    Write-Success "========================================="
    Write-Info ""
    Write-Info "Next steps:"
    Write-Info "1. Run 'docker-compose build' to build the main Artemis API image"
    Write-Info "2. Run 'docker-compose up' to start the application"
    Write-Info ""

} catch {
    Write-Error "Build process failed: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
} finally {
    Pop-Location
}

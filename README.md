# ASP.NET Core Docker SSL/TLS Reference Implementation

A comprehensive reference implementation demonstrating SSL/TLS certificate configuration for ASP.NET Core applications running in Docker containers on Linux, with cross-platform certificate management using PowerShell Core and .NET X509Store API.

**Project Focus:** Docker SSL/TLS configuration, not invoice management (the API is just a demo application)

## Overview

This project demonstrates best practices for:
- Self-signed certificate generation for development environments
- X509Store certificate management on Linux and WSL
- Cross-platform certificate deployment (WSL, Linux, Docker)
- Kestrel HTTPS configuration with custom certificates
- Automated certificate installation with PowerShell Core
- Non-root Docker container certificate handling
- Red Hat Universal Base Image (UBI) deployment for enterprise compliance

The project includes a minimal REST API (invoice management) to demonstrate the certificate configuration in a real-world application context.

## Why Red Hat UBI?

This project uses **Red Hat Universal Base Images (UBI)** instead of Microsoft's official .NET container images due to corporate requirements for enterprise support and compliance.

**Benefits of Red Hat UBI:**
- Enterprise support and long-term maintenance from Red Hat
- Security-focused updates through Red Hat's RHEL repositories
- Compliance with corporate container image policies
- Smaller image sizes (UBI8-minimal is ~35% smaller than Microsoft base images)
- Enhanced security with RHEL-based security patches
- Production-ready for regulated environments

**Custom Base Images:**
This project builds two custom base images from Red Hat UBI8:
- `artemis/ubi8-dotnet-sdk:9.0` - For building .NET applications (from UBI8 full)
- `artemis/ubi8-aspnet-runtime:9.0` - For running ASP.NET Core applications (from UBI8-minimal)

Both images include .NET 9.0 and PowerShell Core 7+ installed from Microsoft's official RHEL repositories, ensuring 100% feature parity with Microsoft images while meeting corporate UBI requirements.

## 🚀 Quick Start (5 Minutes)

Get up and running in 5 simple steps:

### 1. Build Base Images (One-time setup)
```bash
pwsh ./build-base-images.ps1
```

### 2. Generate Certificates
```bash
pwsh ./Setup-Certificates.ps1
```

### 3. Start Application
```bash
pwsh ./Start-DockerCompose.ps1
```

### 4. Verify Deployment
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs -f artemis-api

# Test HTTP endpoint
curl http://localhost:5000/api/invoices

# Test HTTPS endpoint
curl -k https://localhost:5001/api/invoices

# Verify certificates installed
docker exec artemis-invoicing-api pwsh -Command \
  '$store = [System.Security.Cryptography.X509Certificates.X509Store]::new("My", "CurrentUser"); \
   $store.Open("ReadOnly"); \
   Write-Host "Certificates: $($store.Certificates.Count)"; \
   $store.Close()'
```

### 5. Stop Application
```bash
docker-compose down
```

**That's it!** Your ASP.NET Core API is now running with SSL/TLS certificates in Docker. 🎉

For detailed explanations and troubleshooting, see the sections below.

## Why This Project?

Configuring SSL/TLS certificates for ASP.NET Core in Docker on Linux is **non-trivial**:

- Windows Certificate Store doesn't exist on Linux
- .NET uses a different certificate store structure on Linux (`~/.dotnet/corefx/cryptography/x509stores/`)
- Simply copying certificate files is insufficient - certificates must be registered via X509Store API
- Docker containers require special handling for certificate mounting and installation
- Cross-platform certificate management requires PowerShell Core (pwsh)
- Certificate chain validation works differently on Linux vs Windows

This project solves these challenges with a complete, working implementation that you can use as a reference for your own projects.

## What You'll Learn

This project demonstrates:

### 1. Certificate Generation
- Creating self-signed CA certificates with OpenSSL
- Generating server certificates signed by custom CA
- Exporting certificates in multiple formats (PFX, CRT)
- Proper Subject Alternative Names (SAN) configuration

### 2. Linux Certificate Management
- Understanding .NET certificate store structure on Linux
- Using X509Store API for certificate installation
- Certificate chain validation on Linux
- Proper file permissions and ownership

### 3. Cross-Platform Scripting
- PowerShell Core (pwsh) for Linux/Docker
- Automated certificate deployment scripts
- Certificate verification and testing utilities
- Platform-agnostic certificate management

### 4. Docker SSL Configuration
- Certificate volume mounts in Docker
- Runtime certificate installation patterns
- Non-root container security considerations
- Docker Compose for development workflows

### 5. ASP.NET Core HTTPS
- Kestrel certificate configuration
- Certificate thumbprint-based loading
- Fallback to development certificates
- appsettings.json certificate configuration

## Key Features

### Certificate Management
- ✅ Self-signed CA and server certificate generation
- ✅ Automated installation to .NET X509Store (Root and My stores)
- ✅ Cross-platform PowerShell scripts (pwsh)
- ✅ Docker container certificate mounting
- ✅ Certificate chain validation
- ✅ Automated thumbprint configuration

### Docker Integration
- ✅ Multi-stage Dockerfile optimized for Linux
- ✅ Certificate installation during container startup
- ✅ Non-root container execution (app user)
- ✅ Docker Compose configuration
- ✅ Health checks and monitoring

### Demo Application
- ✅ Simple REST API (invoice management)
- ✅ Kestrel with custom certificate configuration
- ✅ Swagger/OpenAPI documentation
- ✅ Proper HTTPS endpoint configuration

## Detailed Setup Guide

### Prerequisites

- Docker and Docker Compose
- PowerShell Core (pwsh) 7.0 or later
- .NET 9.0 SDK (for local development)
- Linux, WSL, or macOS (Windows support limited to local development)
- Access to Red Hat UBI registry (registry.access.redhat.com - publicly available)

### 1. Build Red Hat UBI Base Images

**Important:** Build the custom UBI base images first (required one-time step):

```bash
pwsh ./build-base-images.ps1
```

This creates:
- `artemis/ubi8-dotnet-sdk:9.0` - Build environment with .NET 9.0 SDK
- `artemis/ubi8-aspnet-runtime:9.0` - Runtime environment with ASP.NET Core 9.0 and PowerShell

### 2. Generate Certificates

Run the certificate setup script to generate CA and server certificates:

```bash
pwsh ./Setup-Certificates.ps1
```

This creates:
- **Artemis Root CA** certificate (self-signed)
- **artemis-api.local** server certificate (signed by CA)
- Certificate files in `~/certs/`
- Automatic installation to .NET X509Store

### 3. Run with Docker Compose

Start the application with Docker:

```powershell
# Using PowerShell wrapper (recommended)
pwsh ./Start-DockerCompose.ps1

# Or using docker-compose directly
docker-compose up --build
```

The application will be available at:
- **HTTPS**: `https://localhost:5001`
- **HTTP**: `http://localhost:5000`
- **Swagger UI**: `https://localhost:5001/`

### 4. Verify Certificate Configuration

Test that the custom certificate is working:

```bash
# Verify HTTPS connection with custom certificate
curl -v https://artemis-api.local:5001/api/invoices

# Run certificate validation tests
pwsh ./Test-CertificateSetup.ps1
```

### 5. Inspect Docker Container Certificates

View certificates inside the running container:

```bash
# List certificates in CurrentUser\My store
docker exec artemis-api pwsh -Command "Get-ChildItem Cert:\\CurrentUser\\My"

# List certificates in CurrentUser\Root store
docker exec artemis-api pwsh -Command "Get-ChildItem Cert:\\CurrentUser\\Root"

# View .NET certificate store directory structure
docker exec artemis-api ls -la /home/artemis/.dotnet/corefx/cryptography/x509stores/
```

## PowerShell Scripts (Cross-Platform)

All automation scripts use **PowerShell Core (pwsh)** for cross-platform compatibility:

### Start-DockerCompose.ps1
Wrapper script for Docker Compose with automatic certificate management:
```powershell
# Start containers (reads certificate files automatically)
pwsh ./Start-DockerCompose.ps1

# Build images
pwsh ./Start-DockerCompose.ps1 -Command build

# View logs
pwsh ./Start-DockerCompose.ps1 -Command logs

# Stop containers
pwsh ./Start-DockerCompose.ps1 -Command down
```

### docker-entrypoint.ps1
Container startup script that:
- Validates PowerShell availability
- Runs Install-DockerCertificates.ps1
- Starts the .NET application

**Platform Support:**
- ✅ Windows (PowerShell 7+)
- ✅ Linux (PowerShell 7+)
- ✅ macOS (PowerShell 7+)
- ✅ Docker (Debian with PowerShell)

## Certificate Architecture on Linux

### .NET Certificate Store Structure

On Linux, .NET Core uses a file-based certificate store located at:

```
$HOME/.dotnet/corefx/cryptography/x509stores/
├── root/          # Trusted Root CA certificates
│   └── <hash>.pfx
├── my/            # Personal certificates (with private keys)
│   ├── <thumbprint>.pfx
│   └── <thumbprint>.crt
└── ca/            # Intermediate CA certificates
```

For the Docker container (running as `artemis` user):
- Store path: `/home/artemis/.dotnet/corefx/cryptography/x509stores/`

For WSL/Linux development:
- Store path: `~/.dotnet/corefx/cryptography/x509stores/`

### Why X509Store API is Required

Simply copying certificate files to these directories is **insufficient**. Certificates must be:

1. **Loaded into memory** as X509Certificate2 objects with proper flags
2. **Added to the appropriate X509Store** via the .NET API
3. **Properly indexed** by thumbprint and hash
4. **Validated and trusted** by the certificate chain

The PowerShell scripts in this project use the X509Store API to ensure certificates are correctly installed:

```powershell
# Install certificate to CurrentUser\My store
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$store.Add($cert)
$store.Close()
```

### Certificate Chain

```
[Artemis Root CA]  (CurrentUser\Root)
        ↓
[artemis-api.local]  (CurrentUser\My)
```

The application loads the server certificate from `CurrentUser\My`, and the .NET framework validates it against the CA certificate in `CurrentUser\Root`.

### Docker Considerations

Docker containers require special handling:

1. **Certificate files mounted as volumes**
   - Source: `~/projs/dotnet/artemis.svc/certs/`
   - Target: `/certs/` (inside container)

2. **Installation script run during container startup**
   - `docker-entrypoint.ps1` executed as ENTRYPOINT
   - Calls `Install-DockerCertificates.ps1` for certificate installation
   - Installs CA to Root store
   - Installs server certificate to My store
   - Starts the .NET application

3. **Proper file permissions**
   - PFX files: 600 (read/write for owner only)
   - CRT files: 644 (read for all)
   - Owner: `artemis` user (non-root)

4. **Non-root user access**
   - Container runs as `artemis` user (UID 1000)
   - Certificate store: `/home/artemis/.dotnet/corefx/cryptography/x509stores/`
   - PowerShell scripts run as `artemis` user

## Docker Deployment Guide

### Overview

This project demonstrates **runtime certificate installation** with **Red Hat Universal Base Images (UBI)** as the recommended approach for Docker deployments.

**Advantages:**
- Certificates not baked into image (security)
- Easy certificate rotation without rebuild
- Same image works across environments
- Supports certificate updates without image changes
- Clear separation of concerns
- Enterprise-grade UBI base images with RHEL security updates

### Step-by-Step Deployment

#### 1. Build Red Hat UBI Base Images

**First-time setup:** Build custom UBI base images:

```bash
pwsh ./build-base-images.ps1
```

This creates:
- `artemis/ubi8-dotnet-sdk:9.0` - UBI8 with .NET 9.0 SDK
- `artemis/ubi8-aspnet-runtime:9.0` - UBI8-minimal with ASP.NET Core 9.0 runtime and PowerShell

**Note:** This step is only required once (or when base images need updating).

#### 2. Generate Certificates on Host

Run the setup script to create certificates:

```bash
pwsh ./Setup-Certificates.ps1
```

**Output:**
- `~/certs/artemis-ca.pfx` - CA certificate (Root)
- `~/certs/artemis-ca.crt` - CA certificate (public)
- `~/certs/artemis-api.pfx` - Server certificate (My)
- `~/certs/artemis-api.crt` - Server certificate (public)
- Certificate thumbprint written to `appsettings.json`

#### 3. Build Docker Image

Build the multi-stage Docker image (uses custom UBI base images):

```bash
docker build -t artemis-api:latest .
```

**Dockerfile stages (UBI-based):**
- **build**: Build environment (artemis/ubi8-dotnet-sdk:9.0)
- **publish**: Published application
- **final**: Runtime image (artemis/ubi8-aspnet-runtime:9.0) with entrypoint script

#### 4. Run Docker Container

**Option A: Using Docker Compose (Recommended)**

```powershell
# Using PowerShell wrapper
pwsh ./Start-DockerCompose.ps1

# Or using docker-compose directly
docker-compose up -d
```

**Option B: Using Docker CLI**

```bash
docker run -d \
  --name artemis-api \
  -p 5000:5000 \
  -p 5001:5001 \
  -v ~/certs:/certs:ro \
  -e ASPNETCORE_ENVIRONMENT=Development \
  artemis-api:latest
```

#### 5. Verify Deployment

Check application logs:

```bash
docker logs artemis-api
```

Expected output:
```
Installing certificates for Docker container...
Installing CA certificate to Root store...
Installing server certificate to My store...
Certificate installation completed successfully.
Starting application...
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: https://0.0.0.0:5001
```

Test HTTPS endpoint:

```bash
curl -k https://localhost:5001/api/invoices
```

### Docker Compose Configuration

The `docker-compose.yml` demonstrates volume mounting for certificates:

```yaml
services:
  artemis-api:
    build: .
    ports:
      - "5000:5000"
      - "5001:5001"
    volumes:
      - ./certs:/certs:ro  # Mount certificates read-only
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=https://+:5001;http://+:5000
```

**Volume mount details:**
- **Source**: `./certs` (relative to docker-compose.yml)
- **Target**: `/certs` (inside container)
- **Mode**: `ro` (read-only for security)

### Dockerfile Architecture (Red Hat UBI)

The Dockerfile uses Red Hat UBI custom base images with runtime certificate installation:

```dockerfile
# Corporate requirement: Using Red Hat Universal Base Images (UBI)
# Base images built from Dockerfile.ubi8-dotnet-sdk and Dockerfile.ubi8-aspnet-runtime

# Stage 1: Build using UBI with .NET SDK
FROM artemis/ubi8-dotnet-sdk:9.0 AS build
WORKDIR /src
COPY ["artemis.svc.csproj", "./"]
RUN dotnet restore "artemis.svc.csproj"
COPY . .
RUN dotnet build "artemis.svc.csproj" -c Release -o /app/build

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish "artemis.svc.csproj" -c Release -o /app/publish

# Stage 3: Runtime using UBI with ASP.NET Core and PowerShell
FROM artemis/ubi8-aspnet-runtime:9.0 AS final
WORKDIR /app
COPY --from=publish --chown=artemis:artemis /app/publish .
COPY --chown=artemis:artemis Install-DockerCertificates.ps1 /app/
COPY --chown=artemis:artemis docker-entrypoint.ps1 /app/
USER artemis
EXPOSE 5000 5001
ENTRYPOINT ["pwsh", "-File", "/app/docker-entrypoint.ps1"]
```

**Key components:**
1. Red Hat UBI8 base images for enterprise compliance
2. .NET 9.0 SDK and runtime from Microsoft RHEL repositories
3. PowerShell Core 7+ included in base image
4. Certificate installation scripts for runtime deployment
5. Non-root user (`artemis` UID 1000) pre-configured
6. Multi-stage build for optimized image size

**Image Size Comparison:**
- Microsoft mcr.microsoft.com/dotnet/aspnet:9.0 - ~220MB
- Red Hat artemis/ubi8-aspnet-runtime:9.0 - ~145MB (35% smaller)

### Certificate Rotation

To rotate certificates without rebuilding the image:

1. Generate new certificates: `pwsh ./Setup-Certificates.ps1`
2. Update `appsettings.json` with new thumbprint
3. Restart container: `docker-compose restart`

The container will pick up the new certificates from the mounted volume and install them on startup.

### UBI Base Image Updates

To update the Red Hat UBI base images (e.g., for security patches):

```bash
# Rebuild base images without cache
pwsh ./build-base-images.ps1 -NoBuildCache

# Rebuild application image
docker-compose build --no-cache

# Restart containers
docker-compose up -d
```

### Verification Commands

Verify certificate installation inside container:

```bash
# Check CurrentUser\My store (server certificate)
docker exec artemis-api pwsh -Command "Get-ChildItem Cert:\\CurrentUser\\My | Format-List Subject, Thumbprint, NotAfter"

# Check CurrentUser\Root store (CA certificate)
docker exec artemis-api pwsh -Command "Get-ChildItem Cert:\\CurrentUser\\Root | Format-List Subject, Thumbprint, NotAfter"

# Verify certificate chain
docker exec artemis-api pwsh ./Test-CertificateSetup.ps1

# Check certificate files
docker exec artemis-api ls -la /certs

# View certificate store directory
docker exec artemis-api ls -la /home/artemis/.dotnet/corefx/cryptography/x509stores/
```

## Scripts

This project includes three PowerShell Core scripts for certificate management:

### Setup-Certificates.ps1

**Purpose:** Generate self-signed CA and server certificates for development

**What it does:**
1. Creates a self-signed CA certificate (Artemis Root CA)
2. Generates a server certificate signed by the CA (artemis-api.local)
3. Exports certificates in PFX and CRT formats
4. Installs certificates to .NET X509Store (Root and My stores)
5. Updates `appsettings.json` with certificate thumbprint
6. Sets proper file permissions (600 for PFX, 644 for CRT)

**Usage:**
```bash
pwsh ./Setup-Certificates.ps1
```

**Output:**
- Certificates created in `~/projs/dotnet/artemis.svc/certs/`
- Certificates installed to `~/.dotnet/corefx/cryptography/x509stores/`
- `appsettings.json` updated with thumbprint

### Install-DockerCertificates.ps1

**Purpose:** Install certificates inside Docker containers at runtime

**What it does:**
1. Loads CA certificate from `/certs/artemis-ca.pfx`
2. Installs CA to CurrentUser\Root store
3. Loads server certificate from `/certs/artemis-api.pfx`
4. Installs server certificate to CurrentUser\My store
5. Verifies installation and displays certificate details

**Usage:**
```bash
# Inside Docker container (automatic via ENTRYPOINT)
pwsh ./Install-DockerCertificates.ps1

# Manual execution in running container
docker exec artemis-api pwsh ./Install-DockerCertificates.ps1
```

**Prerequisites:**
- Certificate files mounted at `/certs/`
- PowerShell Core (pwsh) installed in container
- Running as user with access to home directory

### Test-CertificateSetup.ps1

**Purpose:** Verify certificate installation and chain validation

**What it does:**
1. Lists certificates in CurrentUser\My store
2. Lists certificates in CurrentUser\Root store
3. Verifies certificate chain for server certificate
4. Displays certificate expiration dates
5. Checks for certificate configuration in appsettings.json

**Usage:**
```bash
# On host (WSL/Linux)
pwsh ./Test-CertificateSetup.ps1

# Inside Docker container
docker exec artemis-api pwsh ./Test-CertificateSetup.ps1
```

**Sample output:**
```
Testing Certificate Setup...

Certificates in CurrentUser\My:
Subject: CN=artemis-api.local
Thumbprint: A1B2C3D4E5F6...
NotAfter: 2027-10-03

Certificates in CurrentUser\Root:
Subject: CN=Artemis Root CA
Thumbprint: B2C3D4E5F6G7...
NotAfter: 2030-10-03

Certificate chain validation: PASSED
```

## Project Structure

```
artemis.svc/
├── Controllers/
│   └── InvoicesController.cs      # REST API endpoints (demo)
├── Models/
│   └── Invoice.cs                 # Invoice entity (demo)
├── Services/
│   ├── IInvoiceService.cs         # Service interface (demo)
│   └── InMemoryInvoiceService.cs  # In-memory storage (demo)
├── certs/                          # Certificate files (generated, not in repo)
│   ├── artemis-ca.pfx             # CA certificate with private key
│   ├── artemis-ca.crt             # CA certificate (public)
│   ├── artemis-api.pfx            # Server certificate with private key
│   └── artemis-api.crt            # Server certificate (public)
├── Setup-Certificates.ps1          # Certificate generation script
├── Install-DockerCertificates.ps1  # Docker certificate installer
├── docker-entrypoint.ps1           # Container entrypoint (PowerShell)
├── Start-DockerCompose.ps1         # Docker Compose wrapper (PowerShell)
├── Test-CertificateSetup.ps1       # Certificate verification script
├── build-base-images.ps1           # Red Hat UBI base image builder
├── validate-scripts-ubi.ps1        # UBI compatibility validation script
├── DOCKER_CERTIFICATE_INTEGRATION.md  # Implementation details
├── POWERSHELL_QUICK_REFERENCE.md   # PowerShell commands reference
├── UBI_MIGRATION_GUIDE.md          # Red Hat UBI migration guide
├── UBI-VALIDATION-INDEX.md         # UBI validation documentation index
├── POWERSHELL-UBI-SUMMARY.md       # PowerShell UBI compatibility summary
├── UBI-POWERSHELL-COMPATIBILITY-REPORT.md  # Detailed compatibility report
├── UBI-VALIDATION-QUICKSTART.md    # Quick validation guide
├── Program.cs                      # Application entry point & Kestrel config
├── Dockerfile                      # Multi-stage Docker build (UBI-based)
├── Dockerfile.ubi8-dotnet-sdk      # Red Hat UBI8 with .NET 9.0 SDK
├── Dockerfile.ubi8-aspnet-runtime  # Red Hat UBI8-minimal with ASP.NET Core
├── docker-compose.yml              # Docker Compose configuration
├── appsettings.json                # Certificate thumbprint configuration
└── artemis.svc.csproj             # Project file
```

## Demo Application: Invoice API

The project includes a minimal REST API for invoice management to demonstrate the certificate configuration in a real-world application context.

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/invoices` | List all invoices |
| GET | `/api/invoices/{id}` | Get invoice by ID |
| POST | `/api/invoices` | Create new invoice |
| PUT | `/api/invoices/{id}` | Update invoice |
| DELETE | `/api/invoices/{id}` | Delete invoice |

### Invoice Model

```json
{
  "id": 1,
  "invoiceNumber": "INV-2025-001",
  "date": "2025-10-03T10:30:00Z",
  "customerName": "Acme Corporation",
  "amount": 1500.00,
  "status": 1
}
```

**Invoice Status Values:**
- `0` - Draft
- `1` - Sent
- `2` - Paid
- `3` - Overdue
- `4` - Cancelled

### Testing the API

```bash
# Verify HTTPS is working with custom certificate
curl -k https://localhost:5001/api/invoices

# Access Swagger UI
open https://localhost:5001

# Create a test invoice
curl -k -X POST https://localhost:5001/api/invoices \
  -H "Content-Type: application/json" \
  -d '{
    "invoiceNumber": "INV-2025-999",
    "date": "2025-10-04T00:00:00Z",
    "customerName": "Test Customer",
    "amount": 1000.00,
    "status": 0
  }'
```

**Note:** The invoice API uses in-memory storage and is for demonstration purposes only. Data is lost when the container restarts.

## Technology Stack

- **.NET 9.0**: ASP.NET Core Web API
- **Kestrel**: High-performance web server with custom certificate support
- **X509Store API**: Cross-platform certificate management
- **PowerShell Core (pwsh)**: Certificate automation scripts
- **Red Hat UBI 8**: Enterprise-grade base images (UBI8 and UBI8-minimal)
- **Docker**: Container runtime for Linux deployment
- **OpenSSL**: Certificate generation (via PowerShell)
- **Swagger/OpenAPI**: API documentation

## Configuration

### appsettings.json

The application loads certificates based on thumbprint configuration:

```json
{
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://0.0.0.0:5001"
      },
      "Http": {
        "Url": "http://0.0.0.0:5000"
      }
    }
  },
  "CertificateSettings": {
    "Thumbprint": "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0",
    "StoreName": "My",
    "StoreLocation": "CurrentUser"
  }
}
```

**Configuration options:**
- `Thumbprint`: Certificate thumbprint (no spaces or colons)
- `StoreName`: Certificate store name (`My`, `Root`, `CA`)
- `StoreLocation`: Store location (`CurrentUser`, `LocalMachine`)

### Program.cs Certificate Loading

The application loads certificates using the X509Store API:

```csharp
using (var store = new X509Store(StoreName.My, StoreLocation.CurrentUser))
{
    store.Open(OpenFlags.ReadOnly);
    var certs = store.Certificates.Find(
        X509FindType.FindByThumbprint,
        thumbprint,
        validOnly: false
    );

    if (certs.Count > 0)
    {
        options.ServerCertificate = certs[0];
    }
}
```

### Environment Variables

Override configuration using environment variables:

```bash
# Override certificate thumbprint
export CertificateSettings__Thumbprint="YOUR_THUMBPRINT_HERE"

# Override Kestrel endpoints
export Kestrel__Endpoints__Https__Url="https://0.0.0.0:5001"

# Set ASP.NET Core environment
export ASPNETCORE_ENVIRONMENT=Production
```

## Troubleshooting

### Certificate Not Trusted in Docker

**Symptom:** Certificate chain validation fails in Docker container

**Diagnostic commands:**
```bash
# Verify CA certificate installed in Root store
docker exec artemis-api pwsh -Command "Get-ChildItem Cert:\\CurrentUser\\Root"

# Check certificate chain
docker exec artemis-api pwsh ./Test-CertificateSetup.ps1

# View application logs
docker logs artemis-api
```

**Solutions:**
1. Ensure `Install-DockerCertificates.ps1` ran during startup (check logs)
2. Verify certificate files mounted correctly: `docker exec artemis-api ls -la /certs`
3. Check file permissions on PFX files (should be 600)
4. Ensure CA certificate is in Root store, not just My store

### Application Won't Start in Docker

**Symptom:** Container exits immediately or fails to start

**Diagnostic commands:**
```bash
# Check container logs
docker logs artemis-api

# Check if container is running
docker ps -a

# Run container interactively to debug
docker run -it --rm \
  -v ~/projs/dotnet/artemis.svc/certs:/certs:ro \
  artemis-api:latest \
  /bin/bash
```

**Solutions:**
1. Verify certificate thumbprint in appsettings.json matches generated certificate
2. Check PowerShell is installed: `docker exec artemis-api which pwsh`
3. Verify entrypoint script permissions: `docker exec artemis-api ls -la Install-DockerCertificates.ps1`
4. Ensure certificate files exist in `/certs/` inside container

### Certificate Thumbprint Mismatch

**Symptom:** "Certificate with thumbprint ... not found in store"

**Diagnostic commands:**
```bash
# List certificates in My store with thumbprints
docker exec artemis-api pwsh -Command "Get-ChildItem Cert:\\CurrentUser\\My | Format-List Subject, Thumbprint"

# Check appsettings.json
docker exec artemis-api cat appsettings.json
```

**Solutions:**
1. Run `Setup-Certificates.ps1` to regenerate certificates and update appsettings.json
2. Manually update thumbprint in appsettings.json (remove spaces and colons)
3. Restart container after updating configuration: `docker-compose restart`

### PowerShell Scripts Won't Run in Docker

**Symptom:** "pwsh: command not found" or script execution errors

**Diagnostic commands:**
```bash
# Check if PowerShell is installed
docker exec artemis-api which pwsh

# Check PowerShell version
docker exec artemis-api pwsh -Version

# Test script execution manually
docker exec artemis-api pwsh -File ./Install-DockerCertificates.ps1
```

**Solutions:**
1. Ensure base images are built: `pwsh ./build-base-images.ps1`
2. Verify PowerShell in base image: `docker run --rm artemis/ubi8-aspnet-runtime:9.0 pwsh --version`
3. Check script file permissions: `chmod +x *.ps1`
4. Ensure script paths are correct in ENTRYPOINT
5. Run container with `--entrypoint /bin/bash` to debug

### UBI Base Images Not Found

**Symptom:** "Error response from daemon: pull access denied for artemis/ubi8-dotnet-sdk"

**Diagnostic commands:**
```bash
# Check if base images exist
docker images | grep artemis/ubi8

# Verify base image tags
docker images artemis/ubi8-dotnet-sdk:9.0
docker images artemis/ubi8-aspnet-runtime:9.0
```

**Solutions:**
1. Build base images first: `pwsh ./build-base-images.ps1`
2. Verify build completed successfully
3. Check for build errors in output
4. Ensure Red Hat UBI registry is accessible: `docker pull registry.access.redhat.com/ubi8/ubi-minimal:latest`

### Certificate Files Not Found

**Symptom:** "Cannot find path '/certs/artemis-api.pfx'"

**Diagnostic commands:**
```bash
# Check certificate files on host
ls -la ~/projs/dotnet/artemis.svc/certs/

# Check mounted files in container
docker exec artemis-api ls -la /certs/

# Verify volume mounts
docker inspect artemis-api | grep -A 10 Mounts
```

**Solutions:**
1. Generate certificates on host: `pwsh ./Setup-Certificates.ps1`
2. Verify volume mount in docker-compose.yml or docker run command
3. Ensure absolute paths used in volume mounts
4. Check file permissions allow read access

### SSL Connection Fails from Client

**Symptom:** "SSL connection could not be established" or "certificate verify failed"

**Diagnostic commands:**
```bash
# Test with curl (skip validation)
curl -k -v https://localhost:5001/api/invoices

# Test certificate chain
openssl s_client -connect localhost:5001 -showcerts

# Check if application is listening on HTTPS
docker exec artemis-api netstat -tlnp | grep 5001
```

**Solutions:**
1. Use `-k` flag with curl to skip certificate validation for self-signed certs
2. Install CA certificate (`artemis-ca.crt`) in client's trusted root store
3. Add `artemis-api.local` to `/etc/hosts`: `127.0.0.1 artemis-api.local`
4. Verify Kestrel is listening on HTTPS port (check logs)

### Certificate Store Directory Not Created

**Symptom:** X509Store operations fail, certificate directory missing

**Diagnostic commands:**
```bash
# Check if certificate store directory exists
docker exec artemis-api ls -la /home/artemis/.dotnet/corefx/cryptography/

# Check user permissions
docker exec artemis-api whoami
docker exec artemis-api ls -ld /home/artemis/.dotnet
```

**Solutions:**
1. Ensure container runs as user with home directory (`artemis` user)
2. Create directory manually if needed (X509Store should create it)
3. Check user has write permissions to home directory
4. Verify .NET runtime is properly installed

## Security Considerations

1. **Certificate Storage**
   - Private keys stored in PFX files with proper permissions (600)
   - Certificate directory mounted read-only in Docker (`:ro`)
   - Certificates not embedded in Docker images

2. **Certificate Expiration**
   - Monitor certificate expiration dates
   - Setup: 2-year server certificate, 5-year CA certificate
   - Use `Test-CertificateSetup.ps1` to check expiration

3. **Private Key Protection**
   - PFX files contain private keys (keep secure)
   - Never commit PFX files to version control (add to `.gitignore`)
   - Use proper file permissions (600 on Linux)

4. **Container Security**
   - Container runs as non-root user (`artemis`, UID 1000)
   - Certificates installed to user store, not system store
   - Read-only volume mounts for certificates

5. **Development vs. Production**
   - This setup is for **development only**
   - Production should use certificates from trusted CA
   - Consider using Let's Encrypt or Azure Key Vault for production

6. **Input Validation**
   - API includes basic input validation
   - Error responses don't expose sensitive information
   - HTTPS redirection enabled in production

## Local Development (Without Docker)

You can also run the application locally for development:

### Prerequisites
- .NET 9.0 SDK
- PowerShell Core (pwsh)
- Linux, WSL, or macOS

### Steps

1. **Generate certificates:**
   ```bash
   pwsh ./Setup-Certificates.ps1
   ```

2. **Build the application:**
   ```bash
   dotnet build
   ```

3. **Run the application:**
   ```bash
   dotnet run
   ```

4. **Access the application:**
   - HTTPS: `https://localhost:5001`
   - HTTP: `http://localhost:5000`
   - Swagger: `https://localhost:5001/`

### Certificate Location (Local Development)

Certificates are installed to:
- `~/.dotnet/corefx/cryptography/x509stores/my/` (server certificate)
- `~/.dotnet/corefx/cryptography/x509stores/root/` (CA certificate)

## Production Deployment Considerations

This reference implementation focuses on **development environments**. For production:

### Use Trusted CA Certificates
- Obtain certificates from trusted CA (Let's Encrypt, DigiCert, etc.)
- Avoid self-signed certificates in production
- Ensure proper certificate chain validation

### Externalize Certificate Management
- Use Azure Key Vault, AWS Secrets Manager, or HashiCorp Vault
- Implement certificate rotation policies
- Monitor certificate expiration with alerting

### Kubernetes Deployment
- Use cert-manager for automated certificate management
- Store certificates in Kubernetes Secrets
- Use Ingress controllers for TLS termination

### Security Hardening
- Implement proper authentication and authorization
- Use HTTPS redirection (enabled by default)
- Enable HSTS (HTTP Strict Transport Security)
- Configure proper CORS policies
- Implement rate limiting and DDoS protection

### Monitoring and Logging
- Implement structured logging
- Monitor certificate expiration dates
- Track SSL/TLS handshake failures
- Set up health checks and readiness probes

## Reference Documentation

### Microsoft Documentation
- [ASP.NET Core HTTPS Configuration](https://docs.microsoft.com/en-us/aspnet/core/security/enforcing-ssl)
- [Kestrel Web Server Configuration](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel)
- [X509Store Class Documentation](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509store)
- [PowerShell Core Documentation](https://docs.microsoft.com/en-us/powershell/scripting/overview)
- [.NET on RHEL Documentation](https://learn.microsoft.com/en-us/dotnet/core/install/linux-rhel)

### Red Hat Documentation
- [Red Hat Universal Base Images (UBI)](https://developers.redhat.com/products/rhel/ubi)
- [UBI 8 Container Images](https://catalog.redhat.com/software/containers/ubi8/ubi/5c359854d70cc534b3a3784e)
- [UBI 8 Minimal](https://catalog.redhat.com/software/containers/ubi8/ubi-minimal/5c359a62bed8bd75a2c3fba8)
- [Red Hat Container Security](https://www.redhat.com/en/topics/security/container-security)

### Docker Documentation
- [Docker Volumes](https://docs.docker.com/storage/volumes/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)

### Project-Specific Documentation
- [UBI Migration Guide](./UBI_MIGRATION_GUIDE.md) - Comprehensive guide to the Red Hat UBI migration
- [Docker Certificate Integration](./DOCKER_CERTIFICATE_INTEGRATION.md) - Certificate implementation details
- [PowerShell UBI Compatibility](./POWERSHELL-UBI-SUMMARY.md) - PowerShell validation summary
- [UBI Validation Index](./UBI-VALIDATION-INDEX.md) - Complete validation documentation index

## Contributing

This is a reference implementation project. If you find issues or have improvements:

1. Test your changes with the provided scripts
2. Ensure Docker deployment works end-to-end
3. Update documentation to reflect changes
4. Test on Linux/WSL environment

## License

This is a demonstration project for educational purposes.

## Support

For issues and questions:
- Check the Troubleshooting section above
- Review application logs: `docker logs artemis-api`
- Run certificate tests: `pwsh ./Test-CertificateSetup.ps1`
- Consult the reference documentation links

---

**Remember:** This project demonstrates SSL/TLS certificate configuration for Docker deployments. The invoice API is just a minimal example application to demonstrate the certificate setup in a real-world context.

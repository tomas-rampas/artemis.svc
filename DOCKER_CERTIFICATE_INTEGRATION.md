# Docker Certificate Integration - Reference Guide

## Overview

This reference guide documents the SSL/TLS certificate integration for containerized deployment of the Artemis API using **Red Hat Universal Base Images (UBI)**. It covers certificate generation, UBI-based Docker configuration, container-side installation, and security best practices for development and production environments.

**Audience:** DevOps engineers, developers deploying containerized services, and system administrators managing SSL/TLS certificates in Docker environments.

**Key Features:**
- Automated certificate generation and PFX password management
- X509Store-based certificate installation in containers
- Thumbprint-based certificate selection for security
- Cross-platform PowerShell scripts for consistent workflow
- Red Hat UBI base images for enterprise compliance
- Development-ready configuration with production security guidance

## Why Red Hat UBI?

This project uses **Red Hat Universal Base Images (UBI)** instead of Microsoft's official .NET container images due to corporate requirements.

**Benefits:**
- Enterprise support and compliance with corporate policies
- Security updates through Red Hat RHEL repositories
- Smaller image sizes (~35% reduction with UBI8-minimal)
- Production-ready for regulated environments
- 100% .NET feature parity using Microsoft RHEL packages

**Base Images:**
- `artemis/ubi8-dotnet-sdk:9.0` - UBI8 with .NET 9.0 SDK (for building)
- `artemis/ubi8-aspnet-runtime:9.0` - UBI8-minimal with ASP.NET Core 9.0 and PowerShell (for runtime)

---

## Architecture

### Certificate Flow

```
[Setup-Certificates.ps1]
    │
    ├─> Generates CA and Server certificates
    ├─> Creates PFX with password
    ├─> Saves password to pfx-password.txt
    └─> Exports thumbprint to thumbprint.txt
         │
         ├─> [docker-compose.yml]
         │       │
         │       └─> Mounts certificate directories
         │       └─> Passes CERT_THUMBPRINT environment variable
         │       └─> Passes CERT_PFX_PASSWORD environment variable
         │            │
         │            └─> [Container Runtime]
         │                    │
         │                    └─> [docker-entrypoint.ps1]
         │                            │
         │                            └─> [Install-DockerCertificates.ps1]
         │                                    │
         │                                    ├─> Installs CA certs to CurrentUser\Root
         │                                    ├─> Installs Server cert to CurrentUser\My
         │                                    └─> Validates certificate chain
         │                                         │
         │                                         └─> [ASP.NET Core App]
         │                                                 │
         │                                                 └─> Loads cert from X509Store
         │                                                 └─> Binds to HTTPS endpoint
```

### Component Interaction

**Host System:**
- `Setup-Certificates.ps1`: Generates certificates and credentials
- `Start-DockerCompose.ps1`: Orchestrates container startup with environment variables
- `docker-compose.yml`: Defines service configuration and mounts

**Container Runtime:**
- `docker-entrypoint.ps1`: PowerShell entrypoint for initialization
- `Install-DockerCertificates.ps1`: X509Store certificate installation
- ASP.NET Core Kestrel: Consumes certificates from X509Store

### Security Model

1. **Password Generation:** PFX password created as SecureString, converted to plain text only for file export
2. **File Permissions:** Password file restricted to 600 (owner read/write only)
3. **Version Control:** Password and certificate files explicitly excluded via .gitignore
4. **Thumbprint Validation:** Only certificates matching expected thumbprint are installed
5. **Store-Based Access:** Application loads certificates from X509Store, not from files

---

## Prerequisites

### Required Tools
- PowerShell 7.0 or later (cross-platform)
- Docker Engine 20.10 or later
- Docker Compose 2.0 or later
- .NET 9.0 SDK (for building)
- Access to Red Hat UBI registry (registry.access.redhat.com - publicly available)

### File System Requirements
- Write access to project directory for certificate generation
- Ability to set Unix file permissions (chmod 600)
- Minimum 10MB free space for certificates

### Network Requirements
- Ports 5000 (HTTP) and 5001 (HTTPS) available on host
- Network connectivity for Docker image pulls (Red Hat UBI and Microsoft package repositories)

### UBI Base Image Requirements
- **First-time setup:** Build custom UBI base images using `build-base-images.ps1`
- Base images must exist before building application Docker image
- Base images only need to be built once (or when updating for security patches)

---

## Configuration

### Setup-Certificates.ps1

**Purpose:** Generates CA and server certificates, creates PFX files with passwords, and prepares certificate artifacts for Docker deployment.

**Key Parameters:**
- `-Force`: Regenerate certificates even if they exist
- `-Verbose`: Display detailed progress information
- `-PasswordLength <int>`: Specify PFX password length (default: 32)

**Output Files:**

| File | Location | Purpose |
|------|----------|---------|
| `artemis-ca.crt` | `~/certs/ca/` | CA public certificate |
| `artemis-ca.key` | `~/certs/ca/` | CA private key |
| `artemis-server.pfx` | `~/certs/server/` | Server certificate with private key |
| `pfx-password.txt` | `~/certs/server/` | PFX password in plain text |
| `thumbprint.txt` | `~/certs/server/` | Certificate thumbprint |
| `{thumbprint}.pfx` | `~/certs/docker/my/` | Server certificate for container |
| `*.0` files | `~/certs/docker/root/` | CA certificates (OpenSSL hash format) |

**Note:** `~` expands to your home directory (e.g., `/home/username`).

**Security Considerations:**
- PFX password generated with cryptographically secure random generation
- Password file created with 600 permissions (owner-only access)
- Sensitive variables cleared from memory after file operations
- Security warnings displayed when creating plain text password file

**Example Usage:**
```powershell
# Generate certificates with default settings
pwsh ~/Setup-Certificates.ps1

# Regenerate certificates with verbose output
pwsh ~/Setup-Certificates.ps1 -Force -Verbose
```

**Output Example:**
```
→ Saving PFX password for Docker integration
✓ PFX password saved to: ~/certs/server/pfx-password.txt (permissions: 600)
WARNING: SECURITY: Password file contains plain text password - ensure it is not committed to version control
```

---

### docker-compose.yml

**Purpose:** Defines the Artemis API service configuration, including environment variables, volume mounts, and health checks.

**Environment Variables:**

```yaml
environment:
  - ASPNETCORE_ENVIRONMENT=Development
  - ASPNETCORE_URLS=http://+:5000;https://+:5001
  - CertificateSettings__Thumbprint=${CERT_THUMBPRINT:-}
  - CertificateSettings__StoreName=My
  - CertificateSettings__StoreLocation=CurrentUser
  - CERT_PFX_PASSWORD=${CERT_PFX_PASSWORD:-}
```

**Environment Variable Reference:**

| Variable | Source | Purpose | Required |
|----------|--------|---------|----------|
| `CERT_THUMBPRINT` | `~/certs/server/thumbprint.txt` | Identifies certificate to install and use | Yes |
| `CERT_PFX_PASSWORD` | `~/certs/server/pfx-password.txt` | Password for PFX file decryption | Yes |
| `CertificateSettings__Thumbprint` | Passed from `CERT_THUMBPRINT` | ASP.NET Core configuration | Yes |
| `CertificateSettings__StoreName` | Hardcoded | X509Store name (My = Personal) | Yes |
| `CertificateSettings__StoreLocation` | Hardcoded | X509Store location | Yes |

**Volume Mounts:**

```yaml
volumes:
  - ./certs/docker/my:/app/certs/docker/my:ro
  - ./certs/docker/root:/app/certs/docker/root:ro
```

**Mount Reference:**

| Host Path | Container Path | Purpose | Mode |
|-----------|----------------|---------|------|
| `./certs/docker/my` | `/app/certs/docker/my` | Server certificates | Read-only |
| `./certs/docker/root` | `/app/certs/docker/root` | CA certificates | Read-only |

**Health Check:**

```yaml
healthcheck:
  test: ["CMD-SHELL", "pwsh -Command 'try { (Invoke-WebRequest -Uri http://localhost:5000/api/invoices -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200 } catch { exit 1 }'"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**Health Check Parameters:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `interval` | 30s | Check every 30 seconds |
| `timeout` | 10s | Allow 10 seconds for response |
| `retries` | 3 | Consider unhealthy after 3 failures |
| `start_period` | 40s | Allow 40 seconds for initialization |

---

### Install-DockerCertificates.ps1

**Purpose:** Container-side script that installs certificates into the X509Store, enabling ASP.NET Core to load certificates by thumbprint.

**Function Signature:**
```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$PfxPassword,

    [Parameter(Mandatory=$false)]
    [string]$Thumbprint
)
```

**Parameters:**

| Parameter | Type | Required | Source | Purpose |
|-----------|------|----------|--------|---------|
| `PfxPassword` | string | Yes | `$env:CERT_PFX_PASSWORD` | Decrypt PFX files |
| `Thumbprint` | string | No | `$env:CERT_THUMBPRINT` | Install only matching certificate |

**Installation Process:**

1. **CA Certificate Installation:**
   - Scans `/app/certs/docker/root/` for CA certificates
   - Installs to `CurrentUser\Root` store
   - Validates installation success

2. **Server Certificate Installation:**
   - If thumbprint specified: Installs only `/app/certs/docker/my/{thumbprint}.pfx`
   - If no thumbprint: Installs all PFX files in `/app/certs/docker/my/`
   - Installs to `CurrentUser\My` store
   - Validates installation success

3. **Certificate Chain Validation:**
   - Verifies certificate chain from server cert to CA
   - Ensures trust relationship is established
   - Reports validation status

**Thumbprint-Based Selection:**

```powershell
if ($thumbprint) {
    $serverCertFile = Join-Path $DockerMyDir "$thumbprint.pfx"
    if (-not (Test-Path $serverCertFile)) {
        throw "Server certificate not found: $serverCertFile"
    }

    Install-CertificateToStore `
        -CertificatePath $serverCertFile `
        -StoreName "My" `
        -StoreLocation "CurrentUser" `
        -Password $PfxPassword | Out-Null
}
```

**Benefits of Thumbprint Selection:**
- Prevents password mismatch errors from old certificates
- Ensures only intended certificate is installed
- Enables certificate rotation without removing old certificates
- Provides explicit validation of certificate identity

**Error Handling:**
- Password mismatch: Throws detailed error with file path
- Missing file: Throws file not found error
- Installation failure: Throws X509Store operation error
- Chain validation failure: Warns but continues (allows self-signed)

**Output Example:**
```
═══════════════════════════════════════════════════════════════
  Docker Certificate Installation - X509Store Registration
═══════════════════════════════════════════════════════════════

Expected thumbprint: FE784CC835B8095C23F7C33CC1405366CE47D66B
[>>] Installing CA certificates from: /app/certs/docker/root
[OK] Certificate installed: B1C52756C559DD2EAC19DA741277031BF938EAFC
[>>] Installing server certificates from: /app/certs/docker/my
[OK] Certificate installed: FE784CC835B8095C23F7C33CC1405366CE47D66B
[OK] Certificate chain is valid

╔════════════════════════════════════════════════════════════════╗
║  DOCKER CERTIFICATE INSTALLATION COMPLETED                     ║
╚════════════════════════════════════════════════════════════════╝
```

---

### Start-DockerCompose.ps1

**Purpose:** Helper script that orchestrates Docker Compose operations with automatic environment variable configuration from certificate files.

**Function Signature:**
```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('build', 'up', 'down', 'restart', 'logs', 'status', 'start')]
    [string]$Command = 'start'
)
```

**Supported Commands:**

| Command | Docker Compose Equivalent | Description |
|---------|---------------------------|-------------|
| `build` | `docker-compose build` | Build container images |
| `up` | `docker-compose up` | Start in foreground |
| `start` | `docker-compose up -d` | Start in detached mode (default) |
| `down` | `docker-compose down` | Stop and remove containers |
| `restart` | `docker-compose restart` | Restart running containers |
| `logs` | `docker-compose logs -f` | Follow container logs |
| `status` | `docker-compose ps` | Show container status |

**Environment Variable Handling:**

1. Reads `~/certs/server/thumbprint.txt`
2. Reads `~/certs/server/pfx-password.txt`
3. Validates files exist and are non-empty
4. Exports `CERT_THUMBPRINT` and `CERT_PFX_PASSWORD` to environment
5. Executes Docker Compose command with environment variables

**Usage Examples:**

```powershell
# Start containers in detached mode (default)
pwsh ~/Start-DockerCompose.ps1

# Build images
pwsh ~/Start-DockerCompose.ps1 -Command build

# Start in foreground
pwsh ~/Start-DockerCompose.ps1 -Command up

# View logs
pwsh ~/Start-DockerCompose.ps1 -Command logs

# Stop containers
pwsh ~/Start-DockerCompose.ps1 -Command down

# Restart containers
pwsh ~/Start-DockerCompose.ps1 -Command restart

# Check status
pwsh ~/Start-DockerCompose.ps1 -Command status
```

**Error Handling:**
- Missing thumbprint file: Displays error and setup instructions
- Missing password file: Displays error and setup instructions
- Empty files: Warns and prompts to regenerate certificates
- Docker Compose errors: Passes through Docker error messages

---

### appsettings.json

**Purpose:** ASP.NET Core application configuration, including Kestrel endpoint binding and certificate settings.

**Kestrel Endpoint Configuration:**

```json
"Kestrel": {
  "Endpoints": {
    "Https": {
      "Url": "https://0.0.0.0:5001"
    },
    "Http": {
      "Url": "http://0.0.0.0:5000"
    }
  }
}
```

**Binding Configuration:**

| Endpoint | URL | Purpose | Network Access |
|----------|-----|---------|----------------|
| HTTPS | `https://0.0.0.0:5001` | Secure API access | All interfaces |
| HTTP | `http://0.0.0.0:5000` | Unsecured API access | All interfaces |

**Important:** Using `0.0.0.0` instead of `localhost` is critical for Docker deployments, as it binds to all network interfaces, allowing external access from the host system.

**Certificate Configuration:**

```json
"CertificateSettings": {
  "Thumbprint": "FE784CC835B8095C23F7C33CC1405366CE47D66B",
  "StoreName": "My",
  "StoreLocation": "CurrentUser"
}
```

**Certificate Settings Reference:**

| Setting | Value | Source | Purpose |
|---------|-------|--------|---------|
| `Thumbprint` | SHA-1 hash | Updated by `Setup-Certificates.ps1` | Identifies certificate in store |
| `StoreName` | `My` | Static | Personal certificate store |
| `StoreLocation` | `CurrentUser` | Static | Current user's certificate store |

---

## Usage Guide

### Quick Start

**Step 1: Build UBI Base Images (First-time only)**
```powershell
pwsh ./build-base-images.ps1 -Verbose
```

**Step 2: Generate Certificates**
```powershell
pwsh ./Setup-Certificates.ps1 -Verbose
```

**Step 3: Build Docker Image**
```powershell
docker-compose build
```

**Step 4: Start Container**
```powershell
pwsh ./Start-DockerCompose.ps1
```

**Step 5: Verify**
```bash
curl http://localhost:5000/api/invoices
```

**Expected Response:**
```json
[
  {
    "id": 1,
    "invoiceNumber": "INV-2025-001",
    "date": "2025-09-24T15:21:22.3440016Z",
    "customerName": "Acme Corporation",
    "amount": 1500.00,
    "status": 2
  }
]
```

---

### Standard Workflow

#### 0. Build UBI Base Images (First-time setup)

```powershell
# Build both SDK and runtime base images
pwsh ./build-base-images.ps1 -Verbose

# Or build without cache (clean build)
pwsh ./build-base-images.ps1 -NoBuildCache

# Verify base images
docker images | grep artemis/ubi8
```

**Base Image Build Process:**
- `artemis/ubi8-dotnet-sdk:9.0` - UBI8 + .NET 9.0 SDK + build tools
- `artemis/ubi8-aspnet-runtime:9.0` - UBI8-minimal + ASP.NET Core 9.0 + PowerShell 7+
- Both use Microsoft RHEL packages for .NET
- Pre-configured non-root `artemis` user (UID 1000)
- Certificate directories pre-created

#### 1. Certificate Generation

```powershell
# Generate certificates with verbose output
pwsh ./Setup-Certificates.ps1 -Verbose -Force
```

**Output Artifacts:**
- CA certificate: `~/certs/ca/artemis-ca.crt`
- Server certificate: `~/certs/server/artemis-server.pfx`
- PFX password: `~/certs/server/pfx-password.txt` (600 permissions)
- Thumbprint: `~/certs/server/thumbprint.txt`
- Docker certificates: `~/certs/docker/my/` and `~/certs/docker/root/`
- WSL X509Store installation complete
- `appsettings.json` updated with thumbprint

#### 2. Docker Image Build

```bash
docker-compose build
```

**Build Process (UBI-based):**
- Multi-stage build uses `artemis/ubi8-dotnet-sdk:9.0` for compilation
- Runtime image uses `artemis/ubi8-aspnet-runtime:9.0` (includes PowerShell)
- `Install-DockerCertificates.ps1` and `docker-entrypoint.ps1` copied
- PowerShell entrypoint configured
- Non-root `artemis` user pre-configured in base image

#### 3. Container Startup

**Option A: Using Start-DockerCompose.ps1 (Recommended)**
```powershell
pwsh ./Start-DockerCompose.ps1
```

**Option B: Manual with docker-compose (PowerShell)**
```powershell
$env:CERT_THUMBPRINT = (Get-Content ~/certs/server/thumbprint.txt -Raw).Trim()
$env:CERT_PFX_PASSWORD = (Get-Content ~/certs/server/pfx-password.txt -Raw).Trim()
docker-compose up -d
```

**Option C: Manual with docker-compose (Bash)**
```bash
export CERT_THUMBPRINT=$(cat ~/certs/server/thumbprint.txt)
export CERT_PFX_PASSWORD=$(cat ~/certs/server/pfx-password.txt)
docker-compose up -d
```

**Startup Process:**
1. `docker-entrypoint.ps1` executes (PowerShell entrypoint)
2. `Install-DockerCertificates.ps1` runs with environment variables
3. CA certificates installed to `CurrentUser\Root`
4. Server certificate installed to `CurrentUser\My`
5. Certificate chain validated
6. ASP.NET Core application starts
7. Kestrel loads certificate from X509Store by thumbprint

#### 4. Verification

**Check Container Logs:**
```bash
docker logs artemis-invoicing-api
```

**Expected Certificate Installation Output:**
```
✓ SSL Certificate loaded successfully from CurrentUser\My
  Subject: CN=artemis-api.local, OU=IT, O=Artemis, L=City, S=State, C=US
  Thumbprint: FE784CC835B8095C23F7C33CC1405366CE47D66B
  Expires: 2026-10-04
```

**Test HTTP Endpoint:**
```bash
curl -s http://localhost:5000/api/invoices
```

**Test HTTPS Endpoint:**
```bash
curl -sk https://localhost:5001/api/invoices
```

---

### Advanced Usage

#### Manual docker-compose with Custom Paths

If certificate files are in non-standard locations:

```powershell
# PowerShell
$env:CERT_THUMBPRINT = (Get-Content /path/to/thumbprint.txt -Raw).Trim()
$env:CERT_PFX_PASSWORD = (Get-Content /path/to/pfx-password.txt -Raw).Trim()
docker-compose -f /path/to/docker-compose.yml up -d
```

```bash
# Bash
export CERT_THUMBPRINT=$(cat /path/to/thumbprint.txt)
export CERT_PFX_PASSWORD=$(cat /path/to/pfx-password.txt)
docker-compose -f /path/to/docker-compose.yml up -d
```

#### Certificate Rotation

When rotating certificates (e.g., approaching expiration):

```powershell
# 1. Generate new certificates
pwsh ./Setup-Certificates.ps1 -Force -Verbose

# 2. Rebuild Docker image (if needed)
docker-compose build

# 3. Restart containers with new certificates
pwsh ./Start-DockerCompose.ps1 -Command restart
```

**Note:** Thumbprint-based installation ensures only the current certificate is used, preventing conflicts with old certificates.

#### UBI Base Image Updates

When updating UBI base images for security patches:

```powershell
# 1. Rebuild UBI base images without cache
pwsh ./build-base-images.ps1 -NoBuildCache

# 2. Rebuild application image
docker-compose build --no-cache

# 3. Restart containers
pwsh ./Start-DockerCompose.ps1 -Command restart

# 4. Verify .NET and PowerShell versions
docker exec artemis-invoicing-api dotnet --version
docker exec artemis-invoicing-api pwsh --version
```

**Benefits of Regular Updates:**
- Latest RHEL security patches
- Updated .NET runtime security fixes
- PowerShell Core updates
- Compliance with corporate security policies

#### Debugging Certificate Issues

**Enable verbose logging:**
```bash
docker-compose up
```

**Inspect certificate store inside container:**
```bash
docker exec -it artemis-invoicing-api pwsh -Command "Get-ChildItem Cert:\CurrentUser\My"
```

**View environment variables in container:**
```bash
docker exec -it artemis-invoicing-api pwsh -Command "Get-ChildItem env: | Where-Object Name -like 'CERT_*'"
```

---

## Security Best Practices

### Development Environment

#### Password File Handling
- **File Permissions:** Always verify 600 permissions on `pfx-password.txt`
  ```bash
  ls -la ~/certs/server/pfx-password.txt
  # Expected: -rw------- (600)
  ```
- **Version Control:** Confirm `.gitignore` excludes password files
  ```bash
  git check-ignore ~/certs/server/pfx-password.txt
  # Expected: ~/certs/server/pfx-password.txt
  ```
- **File Storage:** Store password files on encrypted file systems
- **Access Control:** Limit shell access to systems containing password files

#### Certificate Management
- **Regular Rotation:** Regenerate certificates quarterly (minimum annually)
- **Expiration Monitoring:** Track certificate expiration dates
- **Cleanup:** Remove old certificate files after rotation
- **Backup:** Backup CA private key securely (offline storage)

#### Git Security
Verify all certificate files are ignored:
```bash
git status --ignored
```

Expected ignored files:
- `certs/server/pfx-password.txt`
- `certs/server/artemis-server.pfx`
- `certs/server/thumbprint.txt`
- `certs/docker/my/*.pfx`
- `certs/docker/root/*.0`

---

### Production Environment

**Critical:** The plain-text password file approach is **NOT recommended for production**. Implement enterprise-grade secret management.

#### Secret Management Services

**Option 1: Azure Key Vault**
```csharp
// Load certificate from Key Vault
var certificateClient = new CertificateClient(
    new Uri("https://your-vault.vault.azure.net/"),
    new DefaultAzureCredential()
);
var certificate = await certificateClient.GetCertificateAsync("artemis-cert");
```

**Option 2: AWS Secrets Manager**
```csharp
// Load certificate from Secrets Manager
var client = new AmazonSecretsManagerClient();
var request = new GetSecretValueRequest
{
    SecretId = "artemis/certificate"
};
var response = await client.GetSecretValueAsync(request);
```

**Option 3: HashiCorp Vault**
```bash
# Inject secret at runtime
docker run -e CERT_PFX_PASSWORD=$(vault kv get -field=password secret/artemis/cert) \
    artemis-invoicing-api
```

**Option 4: Kubernetes Secrets**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: artemis-cert-secret
type: Opaque
stringData:
  pfx-password: <encrypted-value>
```

#### Certificate Acquisition

**Trusted Certificate Authorities:**
- **Let's Encrypt:** Free, automated certificate management
- **DigiCert:** Enterprise-grade certificates with EV options
- **AWS Certificate Manager:** Free certificates for AWS resources
- **Azure App Service Certificates:** Managed certificates for Azure

**Implementation Example (Let's Encrypt with Certbot):**
```bash
certbot certonly --standalone -d artemis-api.yourdomain.com
# Certificate saved to: /etc/letsencrypt/live/artemis-api.yourdomain.com/
```

#### Automated Certificate Rotation

**Let's Encrypt Renewal:**
```bash
# Automated renewal (cron job)
0 0 * * * certbot renew --post-hook "docker-compose restart"
```

**Custom Rotation Script:**
```powershell
# Monitor certificate expiration
$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object Thumbprint -eq $thumbprint
$daysToExpiry = ($cert.NotAfter - (Get-Date)).Days

if ($daysToExpiry -lt 30) {
    # Regenerate certificate
    & ~/Setup-Certificates.ps1 -Force

    # Restart containers
    & ~/Start-DockerCompose.ps1 -Command restart

    # Send notification
    Send-AlertNotification "Certificate rotated: $daysToExpiry days remaining"
}
```

#### Production Configuration

**Environment Variable Encryption:**
- Use Docker secrets (Swarm mode)
- Use Kubernetes secrets with encryption at rest
- Implement secret rotation policies

**Network Security:**
- Enable TLS 1.2+ only
- Disable weak cipher suites
- Implement certificate pinning for client applications
- Use HSTS headers

**Monitoring:**
- Certificate expiration alerts (30/14/7 days before)
- Failed certificate installation alerts
- Anomalous certificate access patterns
- Certificate chain validation failures

---

## PowerShell Core on RHEL/UBI Compatibility

### Overview

All PowerShell scripts in this project have been validated for 100% compatibility with Red Hat UBI and PowerShell Core 7+ on RHEL.

**Validation Status:** ✅ **NO MODIFICATIONS REQUIRED**

### Key Compatibility Points

**X509Store Paths:**
```powershell
# Script uses $env:HOME for cross-platform compatibility
$X509StoreBasePath = Join-Path $env:HOME ".dotnet/corefx/cryptography/x509stores"
```

**UBI Runtime Paths:**
- `/home/artemis/.dotnet/corefx/cryptography/x509stores/my` - Server certificates
- `/home/artemis/.dotnet/corefx/cryptography/x509stores/root` - CA certificates
- `/home/artemis/.dotnet/corefx/cryptography/x509stores/ca` - Intermediate CAs

**PowerShell Features Used:**
- All cmdlets are cross-platform compatible
- No Windows-specific APIs used
- .NET X509Store API works identically on RHEL
- File operations use cross-platform PowerShell methods

### Validation Documentation

For detailed PowerShell UBI compatibility information, see:
- [POWERSHELL-UBI-SUMMARY.md](./POWERSHELL-UBI-SUMMARY.md) - Executive summary
- [UBI-POWERSHELL-COMPATIBILITY-REPORT.md](./UBI-POWERSHELL-COMPATIBILITY-REPORT.md) - Detailed report
- [UBI-VALIDATION-QUICKSTART.md](./UBI-VALIDATION-QUICKSTART.md) - Quick testing guide
- [UBI-VALIDATION-INDEX.md](./UBI-VALIDATION-INDEX.md) - Complete documentation index

### Testing PowerShell Compatibility

Run the validation script to verify compatibility:

```bash
# Host validation
./validate-scripts-ubi.ps1 -Detailed

# Container validation
docker exec artemis-invoicing-api pwsh -File /app/validate-scripts-ubi.ps1 -RunInContainer -Detailed
```

**Exit Codes:**
- `0` - All validation passed ✅
- `1` - Critical compatibility issues ❌
- `2` - Warnings detected ⚠️

---

## Troubleshooting

### UBI Base Images Not Found

**Error:**
```
Error response from daemon: pull access denied for artemis/ubi8-dotnet-sdk
ERROR: Service 'artemis-api' failed to build: failed to fetch metadata
```

**Cause:** Custom UBI base images not built.

**Solution:**
```powershell
# Build base images first
pwsh ./build-base-images.ps1 -Verbose

# Verify images were created
docker images | grep artemis/ubi8

# Then build application image
docker-compose build
```

**Expected Output:**
```
artemis/ubi8-dotnet-sdk       9.0    [image-id]   [timestamp]   [size]
artemis/ubi8-aspnet-runtime   9.0    [image-id]   [timestamp]   [size]
```

---

### Password File Not Found

**Error:**
```
ERROR: PFX password file not found at ~/certs/server/pfx-password.txt
```

**Cause:** Certificates not generated or password file deleted.

**Solution:**
```powershell
# Generate certificates
pwsh ./Setup-Certificates.ps1 -Verbose
```

**Verification:**
```bash
ls -la ~/certs/server/pfx-password.txt
# Expected: -rw------- 1 user user 32 Oct 04 12:34 ~/certs/server/pfx-password.txt
```

---

### Certificate Installation Fails with Password Error

**Error:**
```
The certificate data cannot be read with the provided password
Exception: System.Security.Cryptography.CryptographicException
```

**Cause:** Password file does not match current certificate PFX password.

**Solution 1: Regenerate Certificates**
```powershell
pwsh ~/Setup-Certificates.ps1 -Force
```

**Solution 2: Verify Environment Variable**

PowerShell:
```powershell
Write-Host $env:CERT_PFX_PASSWORD
# Should output password, not empty
```

Bash:
```bash
echo $CERT_PFX_PASSWORD
# Should output password, not empty
```

**Solution 3: Check File Content**
```bash
cat ~/certs/server/pfx-password.txt
# Should output password string
```

**Solution 4: Verify File Permissions**
```bash
ls -la ~/certs/server/pfx-password.txt
# Should be -rw------- (600)
# If not:
chmod 600 ~/certs/server/pfx-password.txt
```

**Solution 5: UBI-Specific Check**
```bash
# Verify PowerShell can read environment variable in UBI container
docker exec artemis-invoicing-api pwsh -Command 'Write-Host $env:CERT_PFX_PASSWORD'
# Should output password (not empty)
```

---

### Container Fails to Start

**Error:**
```
Certificate installation failed
Error: Exit code 1
```

**Diagnostic Steps:**

**1. Check Container Logs**
```bash
docker logs artemis-invoicing-api
```

**2. Verify Certificate Files Exist**
```bash
ls -la ~/certs/server/
# Expected files:
# - artemis-server.pfx
# - pfx-password.txt
# - thumbprint.txt

ls -la ~/certs/docker/my/
# Expected: {thumbprint}.pfx

ls -la ~/certs/docker/root/
# Expected: *.0 files (CA certificates)
```

**3. Verify Thumbprint Matches**
```bash
# Get expected thumbprint
cat ~/certs/server/thumbprint.txt

# Get PFX filename
ls ~/certs/docker/my/*.pfx
# Filename should match thumbprint
```

**4. Validate Environment Variables**
```bash
docker exec artemis-invoicing-api pwsh -Command 'Write-Host $env:CERT_THUMBPRINT'
docker exec artemis-invoicing-api pwsh -Command 'Write-Host $env:CERT_PFX_PASSWORD'
```

**5. Rebuild UBI Base Images**
```powershell
# If base images are corrupted or outdated
pwsh ./build-base-images.ps1 -NoBuildCache
docker-compose down
docker-compose build --no-cache
pwsh ./Start-DockerCompose.ps1
```

**6. Regenerate Certificates**
```powershell
# Last resort: full regeneration
pwsh ./Setup-Certificates.ps1 -Force -Verbose
docker-compose down
docker-compose build
pwsh ./Start-DockerCompose.ps1
```

---

### API Not Accessible from Host

**Error:**
```bash
curl: (7) Failed to connect to localhost port 5000: Connection refused
```

**Diagnostic Steps:**

**1. Verify Container is Running**
```bash
docker ps
# Should show artemis-invoicing-api with status "Up"
```

**2. Check Port Mapping**
```bash
docker port artemis-invoicing-api
# Expected:
# 5000/tcp -> 0.0.0.0:5000
# 5001/tcp -> 0.0.0.0:5001
```

**3. Verify Kestrel Binding**
```bash
docker logs artemis-invoicing-api | grep "Now listening on"
# Expected:
# Now listening on: http://0.0.0.0:5000
# Now listening on: https://0.0.0.0:5001
```

**4. Check appsettings.json**
```bash
cat ~/appsettings.json | grep -A 10 Kestrel
# Verify URLs use 0.0.0.0, not localhost
```

**5. Test from Inside Container**
```bash
docker exec artemis-invoicing-api pwsh -Command "Invoke-WebRequest -Uri http://localhost:5000/api/invoices -UseBasicParsing"
# If this works, issue is port mapping; if not, application issue
```

**Solution:**
Update `appsettings.json` Kestrel endpoints to use `0.0.0.0`:
```json
"Kestrel": {
  "Endpoints": {
    "Https": {
      "Url": "https://0.0.0.0:5001"
    },
    "Http": {
      "Url": "http://0.0.0.0:5000"
    }
  }
}
```

---

### Health Check Fails

**Error:**
```
Status: unhealthy
Health: starting
```

**Diagnostic Steps:**

**1. View Health Check Logs**
```bash
docker inspect artemis-invoicing-api --format='{{json .State.Health}}' | jq
```

**2. Test Health Check Manually**
```bash
docker exec artemis-invoicing-api pwsh -Command "Invoke-WebRequest -Uri http://localhost:5000/api/invoices -UseBasicParsing -TimeoutSec 5"
```

**3. Increase Start Period**
```yaml
healthcheck:
  start_period: 60s  # Increase from 40s
```

**4. Check Application Logs**
```bash
docker logs artemis-invoicing-api | grep -i error
```

**Common Causes:**
- Application startup time exceeds `start_period`
- Certificate installation failure preventing app start
- Database connection issues
- API endpoint changed or removed

---

## File Reference

### Certificate Files

| File | Location | Purpose | Permissions | Version Control |
|------|----------|---------|-------------|-----------------|
| `artemis-ca.crt` | `~/certs/ca/` | CA public certificate (PEM) | 644 | Ignored |
| `artemis-ca.key` | `~/certs/ca/` | CA private key (PEM) | 600 | Ignored |
| `artemis-server.crt` | `~/certs/server/` | Server public certificate (PEM) | 644 | Ignored |
| `artemis-server.key` | `~/certs/server/` | Server private key (PEM) | 600 | Ignored |
| `artemis-server.pfx` | `~/certs/server/` | Server certificate with private key (PKCS#12) | 600 | Ignored |
| `pfx-password.txt` | `~/certs/server/` | PFX password in plain text | 600 | Ignored |
| `thumbprint.txt` | `~/certs/server/` | Certificate SHA-1 thumbprint | 644 | Ignored |
| `{thumbprint}.pfx` | `~/certs/docker/my/` | Server certificate for container (PKCS#12) | 644 | Ignored |
| `*.0` | `~/certs/docker/root/` | CA certificates in OpenSSL hash format | 644 | Ignored |

**Note:** `~` expands to your home directory (e.g., `/home/username`).

### Script Files

| File | Location | Purpose | Platform | Version Control |
|------|----------|---------|----------|-----------------|
| `Setup-Certificates.ps1` | Project root | Generate certificates and prepare Docker artifacts | Cross-platform | Tracked |
| `Install-DockerCertificates.ps1` | Project root | Install certificates to X509Store in container | Cross-platform | Tracked |
| `Start-DockerCompose.ps1` | Project root | Orchestrate Docker Compose with environment variables | Cross-platform | Tracked |
| `docker-entrypoint.ps1` | Project root | Container entrypoint script | Cross-platform | Tracked |
| `build-base-images.ps1` | Project root | Build Red Hat UBI base Docker images | Cross-platform | Tracked |
| `validate-scripts-ubi.ps1` | Project root | Validate PowerShell UBI compatibility | Cross-platform | Tracked |

### Configuration Files

| File | Location | Purpose | Version Control |
|------|----------|---------|-----------------|
| `docker-compose.yml` | Project root | Docker Compose service definition | Tracked |
| `Dockerfile` | Project root | Application multi-stage build (UBI-based) | Tracked |
| `Dockerfile.ubi8-dotnet-sdk` | Project root | Red Hat UBI8 with .NET 9.0 SDK base image | Tracked |
| `Dockerfile.ubi8-aspnet-runtime` | Project root | Red Hat UBI8-minimal with ASP.NET Core runtime | Tracked |
| `appsettings.json` | Project root | ASP.NET Core application configuration | Tracked |
| `.gitignore` | Project root | Git ignore rules | Tracked |

---

## PowerShell Script API Reference

### Setup-Certificates.ps1

**Synopsis:** Generate CA and server certificates for development and Docker deployment.

**Syntax:**
```powershell
Setup-Certificates.ps1
    [-Force]
    [-Verbose]
    [-PasswordLength <int>]
    [<CommonParameters>]
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Force` | Switch | `$false` | Overwrite existing certificates |
| `-Verbose` | Switch | `$false` | Display detailed progress |
| `-PasswordLength` | Int | `32` | PFX password character length |

**Return Value:** None (exit code 0 on success)

**Example 1: Basic Certificate Generation**
```powershell
pwsh ~/Setup-Certificates.ps1
```

**Example 2: Force Regeneration with Verbose Output**
```powershell
pwsh ~/Setup-Certificates.ps1 -Force -Verbose
```

---

### Install-DockerCertificates.ps1

**Synopsis:** Install certificates to X509Store in Docker container.

**Syntax:**
```powershell
Install-DockerCertificates.ps1
    -PfxPassword <string>
    [-Thumbprint <string>]
    [-Verbose]
    [<CommonParameters>]
```

**Parameters:**

| Parameter | Type | Required | Source | Description |
|-----------|------|----------|--------|-------------|
| `-PfxPassword` | String | Yes | `$env:CERT_PFX_PASSWORD` | PFX decryption password |
| `-Thumbprint` | String | No | `$env:CERT_THUMBPRINT` | Install only matching certificate |
| `-Verbose` | Switch | No | N/A | Display detailed installation steps |

**Return Value:** None (throws exception on failure)

**Example 1: Install Specific Certificate**
```powershell
# Typically called from docker-entrypoint.ps1
pwsh ~/Install-DockerCertificates.ps1 `
    -PfxPassword $env:CERT_PFX_PASSWORD `
    -Thumbprint $env:CERT_THUMBPRINT `
    -Verbose
```

**Example 2: Install All Certificates**
```powershell
pwsh ~/Install-DockerCertificates.ps1 `
    -PfxPassword $env:CERT_PFX_PASSWORD
```

---

### Start-DockerCompose.ps1

**Synopsis:** Orchestrate Docker Compose operations with automatic certificate environment variables.

**Syntax:**
```powershell
Start-DockerCompose.ps1
    [-Command <string>]
    [-Verbose]
    [<CommonParameters>]
```

**Parameters:**

| Parameter | Type | Default | Allowed Values | Description |
|-----------|------|---------|----------------|-------------|
| `-Command` | String | `start` | `build`, `up`, `start`, `down`, `restart`, `logs`, `status` | Docker Compose command |
| `-Verbose` | Switch | `$false` | N/A | Display verbose output |

**Return Value:** None (exit code matches docker-compose exit code)

**Example 1: Start Containers (Detached)**
```powershell
pwsh ~/Start-DockerCompose.ps1
```

**Example 2: Build Images**
```powershell
pwsh ~/Start-DockerCompose.ps1 -Command build
```

**Example 3: View Logs**
```powershell
pwsh ~/Start-DockerCompose.ps1 -Command logs
```

---

## Appendix

### Cross-Platform PowerShell Notes

All scripts require **PowerShell 7.0 or later** (PowerShell Core), which runs on:
- **Windows:** Windows 10/11, Windows Server 2016+
- **Linux:** Ubuntu, Debian, RHEL, CentOS, Alpine, Fedora, openSUSE
- **macOS:** macOS 10.13+

**Installation:**
- Windows: `winget install Microsoft.PowerShell`
- Linux: `wget https://aka.ms/install-powershell.sh && bash install-powershell.sh`
- macOS: `brew install powershell/tap/powershell`

**Verification:**
```bash
pwsh --version
# Expected: PowerShell 7.0.0 or later
```

### Docker Compose Version Notes

This configuration requires **Docker Compose V2** (2.0+), which uses the `docker compose` command (space, not hyphen).

**Check Version:**
```bash
docker compose version
# Expected: Docker Compose version v2.0.0 or later
```

**Migration from V1:**
If using Docker Compose V1 (`docker-compose`), update scripts to use `docker-compose` instead of `docker compose`.

### Certificate Format Reference

| Format | Extension | Description | Use Case |
|--------|-----------|-------------|----------|
| PEM | `.crt`, `.pem` | Base64 ASCII encoding | Public certificates, CA certificates |
| PEM | `.key` | Base64 ASCII encoding | Private keys |
| PKCS#12 | `.pfx`, `.p12` | Binary format with password | Combined certificate + private key |
| OpenSSL Hash | `.0` | PEM with hash filename | OpenSSL certificate directory format |

### Thumbprint Calculation

Certificate thumbprints are SHA-1 hashes of the DER-encoded certificate.

**Calculate Thumbprint (OpenSSL):**
```bash
openssl x509 -in artemis-server.crt -fingerprint -sha1 -noout | sed 's/SHA1 Fingerprint=//' | tr -d ':'
```

**Calculate Thumbprint (PowerShell):**
```powershell
(Get-PfxCertificate -FilePath artemis-server.pfx).Thumbprint
```

---

**Document Version:** 2.0
**Last Updated:** 2025-10-04
**Maintainer:** Artemis Development Team

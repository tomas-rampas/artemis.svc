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

**Key Benefits:**
- Enterprise support and long-term maintenance from Red Hat
- Security-focused updates through Red Hat's RHEL repositories
- Compliance with corporate container image policies
- Production-ready for regulated environments

**Custom Base Images:**
This project builds two custom base images from Red Hat UBI8:
- `artemis/ubi8-dotnet-sdk:9.0` - Build environment with .NET 9.0 SDK (~680MB)
- `artemis/ubi8-aspnet-runtime:9.0` - Runtime with ASP.NET Core 9.0 and PowerShell Core 7+ (~440MB)

Both images include .NET 9.0 and PowerShell Core 7+ from Microsoft's official RHEL repositories, ensuring feature parity with Microsoft images.

**Image Size Tradeoff:**
The UBI8-minimal base (~96MB) is smaller than Microsoft's aspnet base (~220MB), but the final artemis runtime image is ~440MB due to PowerShell Core 7+ requirement for cross-platform certificate automation. This is approximately double Microsoft's .NET image size (~220MB), but necessary for automated X509Store certificate management in containers.

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

### 1. Generate Certificates

Run the certificate setup script:

```bash
pwsh ./Setup-Certificates.ps1
```

This creates certificates in `~/certs/` and installs them to X509Store.

### 2. Build UBI Base Images (One-time)

Build the custom Red Hat UBI base images:

```bash
pwsh ./build-base-images.ps1
```

### 3. Run with Docker Compose

Start the application:

```bash
pwsh ./Start-DockerCompose.ps1
```

The application will be available at:
- **HTTPS**: `https://localhost:5001`
- **HTTP**: `http://localhost:5000`
- **Swagger UI**: `https://localhost:5001/`

### 4. Verify Certificate Configuration

Test that the custom certificate is working:

```bash
# Verify HTTPS connection
curl -k https://localhost:5001/api/invoices

# Run certificate validation tests
pwsh ./Test-CertificateSetup.ps1

# List certificates in container
docker exec artemis-api pwsh -Command "Get-ChildItem Cert:\\CurrentUser\\My"
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
- ✅ Docker (Red Hat UBI with PowerShell)

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

This project uses **runtime certificate installation** with Red Hat UBI for secure, flexible deployments.

**Key Advantages:**
- Certificates not baked into image
- Easy certificate rotation without rebuild
- Same image works across environments
- Enterprise-grade UBI base with RHEL security updates

### Step-by-Step Deployment

#### 1. Generate Certificates

Run the setup script to create certificates:

```bash
pwsh ./Setup-Certificates.ps1
```

This creates certificates in `~/certs/` and updates `appsettings.json` with the thumbprint.

#### 2. Build UBI Base Images (One-time)

```bash
pwsh ./build-base-images.ps1
```

#### 3. Build Application Image

```bash
docker build -t artemis-api:latest .
```

#### 4. Run Container

```bash
pwsh ./Start-DockerCompose.ps1
```

#### 5. Verify Deployment

```bash
# Check logs
docker logs artemis-api

# Test HTTPS
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

### Dockerfile Architecture

Multi-stage build using Red Hat UBI custom base images:

```dockerfile
# Stage 1: Build
FROM artemis/ubi8-dotnet-sdk:9.0 AS build
WORKDIR /src
COPY ["artemis.svc.csproj", "./"]
RUN dotnet restore
COPY . .
RUN dotnet build -c Release -o /app/build

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish -c Release -o /app/publish

# Stage 3: Runtime
FROM artemis/ubi8-aspnet-runtime:9.0 AS final
WORKDIR /app
COPY --from=publish --chown=artemis:artemis /app/publish .
COPY --chown=artemis:artemis Install-DockerCertificates.ps1 /app/
COPY --chown=artemis:artemis docker-entrypoint.ps1 /app/
USER artemis
EXPOSE 5000 5001
ENTRYPOINT ["pwsh", "-File", "/app/docker-entrypoint.ps1"]
```

**Key Features:**
- Red Hat UBI8 base images (enterprise compliance)
- .NET 9.0 from Microsoft RHEL repositories
- PowerShell Core 7+ for certificate automation
- Non-root user (artemis, UID 1000)
- Runtime certificate installation via entrypoint

### Certificate Rotation

To rotate certificates:

1. Generate new certificates: `pwsh ./Setup-Certificates.ps1`
2. Restart container: `docker-compose restart`

The container picks up new certificates from the mounted volume on startup.

## PowerShell Scripts

### Setup-Certificates.ps1
Generates self-signed CA and server certificates, installs them to X509Store, and updates `appsettings.json`.

```bash
pwsh ./Setup-Certificates.ps1
```

### Install-DockerCertificates.ps1
Installs certificates inside Docker containers at runtime (called automatically by entrypoint).

```bash
docker exec artemis-api pwsh ./Install-DockerCertificates.ps1
```

### Test-CertificateSetup.ps1
Verifies certificate installation and chain validation.

```bash
pwsh ./Test-CertificateSetup.ps1
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
├── certs/                          # Certificate files (generated, gitignored)
│   ├── ca/
│   │   ├── artemis-ca.pfx         # CA certificate with private key
│   │   ├── artemis-ca.crt         # CA certificate (public)
│   │   └── artemis-ca.key         # CA private key
│   └── server/
│       ├── artemis-server.pfx     # Server certificate with private key
│       ├── artemis-server.crt     # Server certificate (public)
│       ├── artemis-server.key     # Server private key
│       └── artemis-server.csr     # Certificate signing request
├── Setup-Certificates.ps1          # Certificate generation script
├── Install-DockerCertificates.ps1  # Docker certificate installer
├── docker-entrypoint.ps1           # Container entrypoint (PowerShell)
├── Start-DockerCompose.ps1         # Docker Compose wrapper (PowerShell)
├── Test-CertificateSetup.ps1       # Certificate verification script
├── build-base-images.ps1           # Red Hat UBI base image builder
├── DOCKER_CERTIFICATE_INTEGRATION.md  # Implementation details
├── POWERSHELL_QUICK_REFERENCE.md   # PowerShell commands reference
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

### Certificate Not Trusted

**Issue:** Certificate chain validation fails

**Solution:**
```bash
# Check logs and verify installation
docker logs artemis-api
docker exec artemis-api pwsh ./Test-CertificateSetup.ps1
```

### Application Won't Start

**Issue:** Container exits immediately

**Solution:**
```bash
# Check logs and certificate thumbprint
docker logs artemis-api
docker exec artemis-api cat appsettings.json
```

### UBI Base Images Not Found

**Issue:** "pull access denied for artemis/ubi8-dotnet-sdk"

**Solution:**
```bash
# Build base images first
pwsh ./build-base-images.ps1
docker images | grep artemis/ubi8
```

### Certificate Files Not Found

**Issue:** "Cannot find path '/certs/artemis-api.pfx'"

**Solution:**
```bash
# Generate certificates and verify mount
pwsh ./Setup-Certificates.ps1
ls -la ~/certs/
docker exec artemis-api ls -la /certs/
```

### SSL Connection Fails

**Issue:** "certificate verify failed"

**Solution:**
```bash
# Use -k flag for self-signed certificates
curl -k https://localhost:5001/api/invoices

# Or install CA certificate in client's trusted store
```

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
- [Docker Certificate Integration](./DOCKER_CERTIFICATE_INTEGRATION.md) - Certificate implementation details

## Contributing

This is a reference implementation project. If you find issues or have improvements:

1. Test your changes with the provided scripts
2. Ensure Docker deployment works end-to-end
3. Update documentation to reflect changes
4. Test on Linux/WSL environment

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

This is an open source educational project designed to help developers understand SSL/TLS certificate configuration for ASP.NET Core applications in Docker containers. You are free to use, modify, and distribute this code for both personal and commercial purposes.

Contributions, improvements, and feedback are welcome and encouraged.

## Support

For issues and questions:
- Check the Troubleshooting section above
- Review application logs: `docker logs artemis-api`
- Run certificate tests: `pwsh ./Test-CertificateSetup.ps1`
- Consult the reference documentation links

---

**Remember:** This project demonstrates SSL/TLS certificate configuration for Docker deployments. The invoice API is just a minimal example application to demonstrate the certificate setup in a real-world context.

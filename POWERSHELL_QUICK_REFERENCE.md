# PowerShell Scripts - Quick Reference Card

## 🚀 Quick Start Commands

### Start Docker Containers (Recommended)
```powershell
pwsh ./Start-DockerCompose.ps1
```

### Build Docker Images
```powershell
pwsh ./Start-DockerCompose.ps1 -Command build
```

### View Container Logs
```powershell
pwsh ./Start-DockerCompose.ps1 -Command logs
```

### Stop Containers
```powershell
pwsh ./Start-DockerCompose.ps1 -Command down
```

### Generate Certificates
```powershell
pwsh ./Setup-Certificates.ps1 -Force -Verbose
```

## 📁 Script Files

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **Setup-Certificates.ps1** | Generate SSL/TLS certificates | First-time setup or certificate renewal |
| **Start-DockerCompose.ps1** | Start Docker with certificates | Every time you start containers |
| **docker-entrypoint.ps1** | Container startup script | Automatically by Docker (don't run manually) |
| **Install-DockerCertificates.ps1** | Install certs in container | Automatically by entrypoint (don't run manually) |

## 🔧 Start-DockerCompose.ps1 Commands

| Command | Action | Usage |
|---------|--------|-------|
| **default** (no args) | Start containers in background | `pwsh ./Start-DockerCompose.ps1` |
| **build** | Build Docker images | `pwsh ./Start-DockerCompose.ps1 -Command build` |
| **up** | Start containers in foreground | `pwsh ./Start-DockerCompose.ps1 -Command up` |
| **down** | Stop and remove containers | `pwsh ./Start-DockerCompose.ps1 -Command down` |
| **restart** | Restart containers | `pwsh ./Start-DockerCompose.ps1 -Command restart` |
| **logs** | Follow container logs | `pwsh ./Start-DockerCompose.ps1 -Command logs` |
| **status** | Show container status | `pwsh ./Start-DockerCompose.ps1 -Command status` |

## 🔐 Certificate Files

| File | Purpose | Location |
|------|---------|----------|
| **thumbprint.txt** | Certificate thumbprint | `./certs/server/thumbprint.txt` |
| **pfx-password.txt** | PFX password (plain text) | `./certs/server/pfx-password.txt` |
| **artemis-server.pfx** | Server certificate | `./certs/server/artemis-server.pfx` |
| **artemis-ca.crt** | CA certificate | `./certs/ca/artemis-ca.crt` |

## 🌐 API Endpoints

| Protocol | URL | Purpose |
|----------|-----|---------|
| HTTP | http://localhost:5000/api/invoices | Unsecured API |
| HTTPS | https://localhost:5001/api/invoices | Secured API |
| Swagger | https://localhost:5001/ | API Documentation |

## ⚙️ Environment Variables

### Set Manually (PowerShell)
```powershell
$env:CERT_THUMBPRINT = (Get-Content ./certs/server/thumbprint.txt -Raw).Trim()
$env:CERT_PFX_PASSWORD = (Get-Content ./certs/server/pfx-password.txt -Raw).Trim()
docker-compose up -d
```

### Set Manually (Bash/Linux)
```bash
export CERT_THUMBPRINT=$(cat ./certs/server/thumbprint.txt)
export CERT_PFX_PASSWORD=$(cat ./certs/server/pfx-password.txt)
docker-compose up -d
```

## 🔍 Verification Commands

### Check Container Status
```bash
docker ps
docker logs artemis-invoicing-api
```

### Test API
```bash
# HTTP
curl http://localhost:5000/api/invoices

# HTTPS
curl -k https://localhost:5001/api/invoices
```

### Verify Certificates
```powershell
pwsh ./Setup-Certificates.ps1 -Verbose
```

## 🛠️ Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs artemis-invoicing-api

# Rebuild image
docker-compose build --no-cache

# Restart containers
pwsh ./Start-DockerCompose.ps1 -Command restart
```

### Certificate Errors
```powershell
# Regenerate certificates
pwsh ./Setup-Certificates.ps1 -Force

# Rebuild and restart
docker-compose build
pwsh ./Start-DockerCompose.ps1
```

### Permission Errors
```bash
# Make scripts executable
chmod +x *.ps1

# Check file permissions
ls -la certs/server/
```

## 📝 Common Workflows

### First Time Setup
```powershell
# 1. Generate certificates
pwsh ./Setup-Certificates.ps1 -Force -Verbose

# 2. Build Docker image
pwsh ./Start-DockerCompose.ps1 -Command build

# 3. Start containers
pwsh ./Start-DockerCompose.ps1

# 4. Test API
curl http://localhost:5000/api/invoices
```

### Daily Development
```powershell
# Start containers
pwsh ./Start-DockerCompose.ps1

# View logs while developing
pwsh ./Start-DockerCompose.ps1 -Command logs

# Stop containers when done
pwsh ./Start-DockerCompose.ps1 -Command down
```

### Certificate Renewal
```powershell
# 1. Stop containers
pwsh ./Start-DockerCompose.ps1 -Command down

# 2. Generate new certificates
pwsh ./Setup-Certificates.ps1 -Force

# 3. Rebuild image (certificates are baked into image)
pwsh ./Start-DockerCompose.ps1 -Command build

# 4. Start containers
pwsh ./Start-DockerCompose.ps1
```

### Debugging
```powershell
# 1. View container logs
docker logs -f artemis-invoicing-api

# 2. Check certificate installation
docker logs artemis-invoicing-api | grep "CERTIFICATE INSTALLATION"

# 3. Verify environment variables
docker exec artemis-invoicing-api pwsh -Command '$env:CERT_THUMBPRINT'

# 4. Check API health
curl -v http://localhost:5000/api/invoices
```

## 🔗 Quick Links

- **Main Documentation:** [DOCKER_CERTIFICATE_INTEGRATION.md](DOCKER_CERTIFICATE_INTEGRATION.md)
- **Migration Guide:** [POWERSHELL_MIGRATION.md](POWERSHELL_MIGRATION.md)
- **Cleanup Guide:** [CLEANUP_OLD_SCRIPTS.md](CLEANUP_OLD_SCRIPTS.md)
- **README:** [README.md](README.md)

## 💡 Tips & Best Practices

1. **Always use Start-DockerCompose.ps1** - Handles environment variables automatically
2. **Regenerate certificates periodically** - Default validity is 365 days
3. **Check logs first** - Most issues visible in `docker logs artemis-invoicing-api`
4. **Use -Verbose flag** - Get detailed output: `pwsh ./Setup-Certificates.ps1 -Verbose`
5. **Secure password file** - Ensure `pfx-password.txt` has 600 permissions
6. **Don't commit secrets** - `.gitignore` already configured

## ⚠️ Security Notes

- Password file contains **plain text** password
- Only for **development/testing** environments
- Use **Azure Key Vault** or **AWS Secrets Manager** for production
- File permissions set to **600** (owner read/write only)
- Password file is **git ignored** (won't be committed)

## 📋 Script Parameters

### Setup-Certificates.ps1
```powershell
-Force          # Skip confirmation prompts
-Verbose        # Show detailed output
-Debug          # Show debug information
```

### Start-DockerCompose.ps1
```powershell
-Command <string>   # Docker command: build, up, down, restart, logs, status
-Detached          # Run in background (for 'up' command)
```

### Install-DockerCertificates.ps1 (Auto-run by entrypoint)
```powershell
-CertificateDirectory <string>  # Base cert directory
-ThumbprintFile <string>        # Thumbprint file path
-PfxPassword <string>           # PFX password (from env)
-Force                          # Skip confirmations
```

## 🎯 Success Indicators

### Container Started Successfully
```
✓ SSL Certificate loaded successfully from CurrentUser\My
╔════════════════════════════════════════════════════════════════╗
║  DOCKER CERTIFICATE INSTALLATION COMPLETED                     ║
╚════════════════════════════════════════════════════════════════╝
```

### Certificate Setup Complete
```
✓ PFX password saved to: ./certs/server/pfx-password.txt (permissions: 600)
✓ Certificates installed to WSL X509Store successfully
✓ Docker certificate export completed
```

### API Working
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

**Quick Help:** Run any script with `-?` to see full help documentation
```powershell
pwsh ./Start-DockerCompose.ps1 -?
pwsh ./Setup-Certificates.ps1 -?
```

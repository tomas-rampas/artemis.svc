# Quick Start Guide - Artemis Invoicing API

## Prerequisites

- .NET 9.0 SDK installed
- Windows OS (for certificate store integration) or Linux/macOS (using development certificate)
- PowerShell 7+ (for certificate setup script)

## 🚀 Quick Start (3 Steps)

### Step 1: Setup SSL Certificate (Windows Only)

```powershell
# Run the certificate setup script
.\setup-certificate.ps1

# Or manually create a certificate
$cert = New-SelfSignedCertificate -Subject "CN=artemis.local" -DnsName "artemis.local","localhost" -CertStoreLocation "Cert:\CurrentUser\My"
```

### Step 2: Update Configuration (Optional)

If you created a certificate manually, update `appsettings.Development.json`:

```json
{
  "CertificateSettings": {
    "Thumbprint": "YOUR_CERTIFICATE_THUMBPRINT",
    "StoreName": "My",
    "StoreLocation": "CurrentUser"
  }
}
```

### Step 3: Run the Application

```bash
# Restore dependencies
dotnet restore

# Run the application
dotnet run
```

The API will start on:
- **HTTPS**: https://localhost:5001
- **HTTP**: http://localhost:5000
- **Swagger UI**: https://localhost:5001/ (served at root)

## 📝 Test the API

### Using Swagger UI (Easiest)

1. Navigate to: https://localhost:5001/
2. Use the interactive Swagger UI to test endpoints
3. Click "Try it out" on any endpoint to send requests

### Using cURL

```bash
# Get all invoices
curl -k https://localhost:5001/api/invoices

# Get specific invoice
curl -k https://localhost:5001/api/invoices/1

# Create new invoice
curl -k -X POST https://localhost:5001/api/invoices \
  -H "Content-Type: application/json" \
  -d '{
    "invoiceNumber": "INV-2025-999",
    "date": "2025-10-03T00:00:00Z",
    "customerName": "Test Customer",
    "amount": 5000.00,
    "status": 0
  }'

# Update invoice
curl -k -X PUT https://localhost:5001/api/invoices/1 \
  -H "Content-Type: application/json" \
  -d '{
    "invoiceNumber": "INV-2025-001",
    "date": "2025-09-23T00:00:00Z",
    "customerName": "Acme Corporation",
    "amount": 1500.00,
    "status": 2
  }'

# Delete invoice
curl -k -X DELETE https://localhost:5001/api/invoices/1
```

### Using PowerShell

```powershell
# Get all invoices
Invoke-RestMethod -Uri "https://localhost:5001/api/invoices" -SkipCertificateCheck

# Create new invoice
$invoice = @{
    invoiceNumber = "INV-2025-100"
    date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    customerName = "PowerShell Test"
    amount = 3000.00
    status = 0
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:5001/api/invoices" `
    -Method Post `
    -ContentType "application/json" `
    -Body $invoice `
    -SkipCertificateCheck
```

## 🐳 Docker Deployment

### Build Docker Image

```bash
# Build the image
docker build -t artemis-invoicing-api:latest .

# Run the container
docker run -d -p 5000:5000 -p 5001:5001 --name artemis-api artemis-invoicing-api:latest

# View logs
docker logs -f artemis-api
```

### Using Docker Compose

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## 📊 Sample Data

The API starts with 3 sample invoices:

1. **INV-2025-001** - Acme Corporation - $1,500.00 - Paid
2. **INV-2025-002** - Tech Solutions Inc - $2,750.50 - Sent
3. **INV-2025-003** - Global Services Ltd - $890.25 - Draft

## 🔍 Invoice Status Values

- `0` - Draft
- `1` - Sent
- `2` - Paid
- `3` - Overdue
- `4` - Cancelled

## ⚙️ Configuration Options

### Environment Variables

```bash
# Override HTTPS URLs
export Kestrel__Endpoints__Https__Url="https://0.0.0.0:5001"

# Change certificate thumbprint
export CertificateSettings__Thumbprint="YOUR_THUMBPRINT"

# Set environment
export ASPNETCORE_ENVIRONMENT=Production
```

### appsettings.json

Key configuration sections:

- `Kestrel:Endpoints` - HTTP/HTTPS URL bindings
- `CertificateSettings` - SSL certificate configuration
- `Logging:LogLevel` - Logging verbosity

## 🛠️ Troubleshooting

### Certificate Not Found

If you see: "Certificate with thumbprint ... not found"

1. Verify certificate exists:
   ```powershell
   Get-ChildItem Cert:\CurrentUser\My
   ```

2. Check thumbprint in appsettings.json (no spaces/colons)

3. Re-run setup script:
   ```powershell
   .\setup-certificate.ps1
   ```

### SSL Certificate Not Trusted

1. Run PowerShell as Administrator
2. Re-run the setup script to install to LocalMachine\Root
3. Or manually trust the certificate in browser

### Port Already in Use

Change ports in `appsettings.json`:

```json
{
  "Kestrel": {
    "Endpoints": {
      "Https": { "Url": "https://localhost:6001" },
      "Http": { "Url": "http://localhost:6000" }
    }
  }
}
```

## 📚 API Endpoints Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/invoices` | List all invoices |
| GET | `/api/invoices/{id}` | Get invoice by ID |
| POST | `/api/invoices` | Create new invoice |
| PUT | `/api/invoices/{id}` | Update invoice |
| DELETE | `/api/invoices/{id}` | Delete invoice |

## 🔗 Useful Links

- **Swagger UI**: https://localhost:5001/
- **API Health**: https://localhost:5001/api/invoices
- **Full Documentation**: See README.md

## 📝 Development Tips

1. **Auto-restart on changes**: Use `dotnet watch run`
2. **View detailed logs**: Set `Logging:LogLevel:Default` to `Debug`
3. **Skip certificate validation**: Use `-k` with curl or `-SkipCertificateCheck` with PowerShell
4. **Test in browser**: Navigate to https://localhost:5001/ for Swagger UI

## 🎯 Next Steps

1. ✅ Run the application
2. ✅ Test endpoints with Swagger UI
3. ✅ Create/update invoices
4. ✅ Review logs for certificate loading
5. ✅ Build Docker image for deployment

For complete documentation, see [README.md](README.md)

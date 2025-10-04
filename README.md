# Artemis Invoicing API

A simple ASP.NET Core Web API for invoice management with SSL/TLS certificate support from Windows Certificate Store.

## Features

- **Full CRUD Operations**: Create, Read, Update, and Delete invoices
- **SSL/TLS Support**: Kestrel configured to load certificates from Windows Certificate Store
- **Swagger/OpenAPI**: Interactive API documentation at the root URL
- **In-Memory Storage**: Simple data store for demonstration purposes
- **Docker-Ready**: Clean architecture suitable for containerization
- **Comprehensive Logging**: Built-in logging for all operations

## Technology Stack

- **.NET 9.0**: Latest LTS version of ASP.NET Core
- **Kestrel**: High-performance web server
- **Swagger/OpenAPI**: API documentation with Swashbuckle
- **In-Memory Data Store**: Thread-safe concurrent dictionary

## Project Structure

```
artemis.svc/
├── Controllers/
│   └── InvoicesController.cs      # REST API endpoints
├── Models/
│   └── Invoice.cs                 # Invoice entity and status enum
├── Services/
│   ├── IInvoiceService.cs         # Service interface
│   └── InMemoryInvoiceService.cs  # In-memory implementation
├── Program.cs                      # Application entry point & configuration
├── appsettings.json               # Production configuration
├── appsettings.Development.json   # Development configuration
└── artemis.svc.csproj            # Project file
```

## Scripts

The project includes PowerShell scripts for certificate management:

- **Setup-Certificates.ps1** - Generate and install CA and server certificates
- **Install-DockerCertificates.ps1** - Install certificates in Docker containers
- **Test-CertificateSetup.ps1** - Verify certificate installation

See [QUICKSTART.md](/home/mcquak/projs/dotnet/artemis.svc/QUICKSTART.md) for usage instructions.

## SSL Certificate Configuration

### Certificate Requirements

The application is configured to load SSL certificates from the Windows Certificate Store:

- **Certificate Location**: `Current User\My` (Personal certificate store)
- **CA Certificate**: Should be installed in `Current User\Root` (Trusted Root Certification Authorities)
- **Configuration**: Certificate thumbprint specified in `appsettings.json`

### Certificate Setup Steps

#### 1. Generate a Self-Signed Certificate (Development)

Using PowerShell (run as Administrator):

```powershell
# Create self-signed certificate
$cert = New-SelfSignedCertificate `
    -Subject "CN=artemis.local" `
    -DnsName "artemis.local", "localhost" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears(2) `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")

# Display certificate thumbprint
Write-Host "Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

# Export and import to Trusted Root (optional for self-signed)
$certPath = "C:\Temp\artemis-cert.cer"
Export-Certificate -Cert $cert -FilePath $certPath
Import-Certificate -FilePath $certPath -CertStoreLocation "Cert:\CurrentUser\Root"
```

#### 2. Using an Existing Certificate

If you have an existing certificate from a CA:

```powershell
# Import certificate with private key (PFX/PKCS12)
$pfxPath = "C:\Path\To\Certificate.pfx"
$pfxPassword = ConvertTo-SecureString -String "YourPassword" -Force -AsPlainText
Import-PfxCertificate -FilePath $pfxPath `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -Password $pfxPassword

# Import CA certificate to Trusted Root
Import-Certificate -FilePath "C:\Path\To\CA-Certificate.cer" `
    -CertStoreLocation "Cert:\CurrentUser\Root"
```

#### 3. Find Certificate Thumbprint

```powershell
# List all certificates in Current User\My store
Get-ChildItem -Path "Cert:\CurrentUser\My" | Format-Table Subject, Thumbprint, NotAfter

# Find specific certificate
Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -like "*artemis*" }
```

#### 4. Configure Application

Update the `CertificateSettings:Thumbprint` value in `appsettings.json` or `appsettings.Development.json`:

```json
{
  "CertificateSettings": {
    "Thumbprint": "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0",
    "StoreName": "My",
    "StoreLocation": "CurrentUser"
  }
}
```

**Note**: Remove any spaces or colons from the thumbprint.

### Certificate Store Locations

- **Current User\My**: `Cert:\CurrentUser\My` (Personal certificates)
- **Current User\Root**: `Cert:\CurrentUser\Root` (Trusted Root CAs)
- **Local Machine\My**: `Cert:\LocalMachine\My` (requires admin privileges)

### Fallback Behavior

If no certificate is configured or the certificate cannot be loaded:
- The application will fall back to the ASP.NET Core development certificate
- A warning message will be displayed in the console
- The application will continue to run on HTTPS using the development certificate

## API Endpoints

### Base URL
- HTTPS: `https://localhost:5001`
- HTTP: `http://localhost:5000`

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/invoices` | Get all invoices |
| GET | `/api/invoices/{id}` | Get invoice by ID |
| POST | `/api/invoices` | Create new invoice |
| PUT | `/api/invoices/{id}` | Update invoice |
| DELETE | `/api/invoices/{id}` | Delete invoice |

### Invoice Model

```json
{
  "id": 1,
  "invoiceNumber": "INV-2025-001",
  "date": "2025-09-23T10:30:00Z",
  "customerName": "Acme Corporation",
  "amount": 1500.00,
  "status": 1
}
```

### Invoice Status Enum

- `0` - Draft
- `1` - Sent
- `2` - Paid
- `3` - Overdue
- `4` - Cancelled

## Running the Application

### Prerequisites

- .NET 9.0 SDK or later
- Windows OS (for Windows Certificate Store integration)
- Valid SSL certificate (or use self-signed for development)

### Development

1. **Restore Dependencies**:
   ```bash
   dotnet restore
   ```

2. **Build the Project**:
   ```bash
   dotnet build
   ```

3. **Run the Application**:
   ```bash
   dotnet run
   ```

4. **Access Swagger UI**:
   - Navigate to `https://localhost:5001/` or `http://localhost:5000/`

### Production

1. **Publish the Application**:
   ```bash
   dotnet publish -c Release -o ./publish
   ```

2. **Run Published Application**:
   ```bash
   cd publish
   dotnet artemis.svc.dll
   ```

## Testing the API

### Using cURL

```bash
# Get all invoices
curl -k https://localhost:5001/api/invoices

# Get invoice by ID
curl -k https://localhost:5001/api/invoices/1

# Create new invoice
curl -k -X POST https://localhost:5001/api/invoices \
  -H "Content-Type: application/json" \
  -d '{
    "invoiceNumber": "INV-2025-004",
    "date": "2025-10-03T00:00:00Z",
    "customerName": "New Customer Ltd",
    "amount": 3500.00,
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
# Skip SSL certificate validation for self-signed certs
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Get all invoices
Invoke-RestMethod -Uri "https://localhost:5001/api/invoices" -Method Get

# Create new invoice
$invoice = @{
    invoiceNumber = "INV-2025-005"
    date = "2025-10-03T00:00:00Z"
    customerName = "PowerShell Customer"
    amount = 2500.00
    status = 0
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:5001/api/invoices" `
    -Method Post `
    -ContentType "application/json" `
    -Body $invoice
```

## Docker Preparation

### Dockerfile (Example)

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["artemis.svc.csproj", "./"]
RUN dotnet restore "artemis.svc.csproj"
COPY . .
RUN dotnet build "artemis.svc.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "artemis.svc.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "artemis.svc.dll"]
```

**Note**: For Docker deployment, you'll need to configure certificate mounting or use environment-specific certificate configuration.

## Configuration

### appsettings.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://localhost:5001"
      },
      "Http": {
        "Url": "http://localhost:5000"
      }
    }
  },
  "CertificateSettings": {
    "Thumbprint": "YOUR_CERTIFICATE_THUMBPRINT_HERE",
    "StoreName": "My",
    "StoreLocation": "CurrentUser"
  }
}
```

### Environment Variables (Alternative Configuration)

```bash
# Override certificate thumbprint
export CertificateSettings__Thumbprint="A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0"

# Override Kestrel endpoints
export Kestrel__Endpoints__Https__Url="https://0.0.0.0:5001"
```

## Security Considerations

1. **Certificate Storage**: Production certificates should have appropriate access controls
2. **Certificate Expiration**: Monitor certificate expiration dates
3. **Private Key Protection**: Ensure private keys are properly secured
4. **HTTPS Redirection**: Enabled by default in production
5. **Input Validation**: Basic validation implemented in controller
6. **Error Handling**: Proper error responses without exposing sensitive information

## Troubleshooting

### Certificate Not Found

**Error**: "Certificate with thumbprint ... not found"

**Solutions**:
- Verify the thumbprint is correct (no spaces or colons)
- Check certificate is in the correct store location
- Ensure the certificate has a private key
- Verify current user has read access to the certificate

### SSL Connection Failed

**Error**: "SSL connection could not be established"

**Solutions**:
- Verify CA certificate is in Trusted Root store
- Check certificate validity period
- Ensure certificate includes localhost/artemis.local in SAN
- Try using `-k` flag with curl to skip validation

### Port Already in Use

**Error**: "Address already in use"

**Solutions**:
- Change port numbers in appsettings.json
- Stop other applications using ports 5000/5001
- Use `netstat -ano | findstr :5001` to find conflicting process

## Development Notes

- **In-Memory Storage**: Data is lost on application restart
- **Sample Data**: Three sample invoices are seeded on startup
- **Thread Safety**: ConcurrentDictionary ensures thread-safe operations
- **Logging**: Comprehensive logging for all operations
- **Swagger UI**: Served at root URL for easy testing

## Future Enhancements

- [ ] Database integration (SQL Server, PostgreSQL)
- [ ] Authentication & Authorization (JWT, OAuth2)
- [ ] Invoice PDF generation
- [ ] Email notifications
- [ ] Advanced filtering and pagination
- [ ] Audit logging
- [ ] Docker Compose configuration
- [ ] Kubernetes deployment manifests

## License

This is a demonstration project for educational purposes.

## Support

For issues and questions, please refer to the application logs and Swagger documentation.

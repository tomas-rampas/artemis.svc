using System.Reflection;
using System.Security.Cryptography.X509Certificates;
using Artemis.Svc.Services;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.AspNetCore.Server.Kestrel.Https;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Configure Kestrel with SSL certificate from Windows Certificate Store
builder.WebHost.ConfigureKestrel((context, serverOptions) =>
{
    var config = context.Configuration;
    var certThumbprint = config["CertificateSettings:Thumbprint"];
    var storeName = config["CertificateSettings:StoreName"] ?? "My";
    var storeLocation = config["CertificateSettings:StoreLocation"] ?? "CurrentUser";

    serverOptions.ConfigureHttpsDefaults(httpsOptions =>
    {
        // Only attempt to load certificate if thumbprint is provided and not a placeholder
        if (!string.IsNullOrWhiteSpace(certThumbprint) &&
            !certThumbprint.Contains("YOUR_CERTIFICATE") &&
            !certThumbprint.Contains("THUMBPRINT_HERE"))
        {
            try
            {
                var certificate = LoadCertificateFromStore(
                    certThumbprint,
                    storeName,
                    storeLocation);

                if (certificate != null)
                {
                    httpsOptions.ServerCertificate = certificate;
                    Console.WriteLine($"✓ SSL Certificate loaded successfully from {storeLocation}\\{storeName}");
                    Console.WriteLine($"  Subject: {certificate.Subject}");
                    Console.WriteLine($"  Thumbprint: {certificate.Thumbprint}");
                    Console.WriteLine($"  Expires: {certificate.NotAfter:yyyy-MM-dd}");
                }
                else
                {
                    Console.WriteLine($"⚠ Certificate with thumbprint {certThumbprint} not found in {storeLocation}\\{storeName}");
                    Console.WriteLine("  Falling back to development certificate");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠ Error loading certificate: {ex.Message}");
                Console.WriteLine("  Falling back to development certificate");
            }
        }
        else
        {
            Console.WriteLine("ℹ No certificate thumbprint configured - using development certificate");
            Console.WriteLine("  Configure CertificateSettings:Thumbprint in appsettings.json to use a custom certificate");
        }

        httpsOptions.ClientCertificateMode = ClientCertificateMode.NoCertificate;
    });
});

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Configure Swagger/OpenAPI
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Artemis Invoicing API",
        Version = "v1",
        Description = "ASP.NET Core Web API for Invoice Management System with SSL/TLS Support",
        Contact = new OpenApiContact
        {
            Name = "Artemis Team",
            Email = "support@artemis.local"
        }
    });

    // Include XML comments for API documentation
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
});

// Register application services
builder.Services.AddSingleton<IInvoiceService, InMemoryInvoiceService>();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Artemis Invoicing API v1");
        c.RoutePrefix = string.Empty; // Serve Swagger UI at root
    });
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

// Display startup information
var addresses = app.Services.GetRequiredService<IConfiguration>()
    .GetSection("Kestrel:Endpoints")
    .GetChildren()
    .Select(endpoint => endpoint["Url"])
    .Where(url => !string.IsNullOrEmpty(url));

Console.WriteLine("\n╔════════════════════════════════════════════════════════════╗");
Console.WriteLine("║        Artemis Invoicing API - Starting Up                ║");
Console.WriteLine("╚════════════════════════════════════════════════════════════╝");
Console.WriteLine($"\nEnvironment: {app.Environment.EnvironmentName}");
Console.WriteLine("\nListening on:");
foreach (var address in addresses)
{
    Console.WriteLine($"  • {address}");
}
Console.WriteLine("\nSwagger UI: https://localhost:5001/ or http://localhost:5000/");
Console.WriteLine("\nAPI Endpoints:");
Console.WriteLine("  • GET    /api/invoices       - List all invoices");
Console.WriteLine("  • GET    /api/invoices/{id}  - Get invoice by ID");
Console.WriteLine("  • POST   /api/invoices       - Create new invoice");
Console.WriteLine("  • PUT    /api/invoices/{id}  - Update invoice");
Console.WriteLine("  • DELETE /api/invoices/{id}  - Delete invoice");
Console.WriteLine("\n════════════════════════════════════════════════════════════\n");

app.Run();

// Helper method to load certificate from Windows Certificate Store
static X509Certificate2? LoadCertificateFromStore(string thumbprint, string storeName, string storeLocation)
{
    var location = Enum.Parse<StoreLocation>(storeLocation);
    var name = Enum.Parse<StoreName>(storeName);

    using var store = new X509Store(name, location);
    store.Open(OpenFlags.ReadOnly);

    var certificates = store.Certificates.Find(
        X509FindType.FindByThumbprint,
        thumbprint.Replace(" ", "").Replace(":", ""),
        validOnly: false);

    return certificates.Count > 0 ? certificates[0] : null;
}

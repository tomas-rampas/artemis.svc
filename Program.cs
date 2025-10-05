using System.Security.Cryptography.X509Certificates;
using Artemis.Svc.Services;
using Microsoft.AspNetCore.OpenApi;
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

// Configure OpenAPI (native .NET 9 support - replaces AddEndpointsApiExplorer + AddSwaggerGen)
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info = new()
        {
            Title = "Artemis Invoicing API",
            Version = "v1",
            Description = "ASP.NET Core Web API for Invoice Management System with SSL/TLS Support",
            Contact = new()
            {
                Name = "Artemis Team",
                Email = "support@artemis.local"
            }
        };
        return Task.CompletedTask;
    });
});

// Register application services
builder.Services.AddSingleton<IInvoiceService, InMemoryInvoiceService>();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    // Map OpenAPI endpoint (replaces UseSwagger)
    app.MapOpenApi();

    // Use Swagger UI to visualize OpenAPI document
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "Artemis Invoicing API v1");
        options.RoutePrefix = string.Empty; // Serve Swagger UI at root
        options.DocumentTitle = "Artemis Invoicing API - Swagger UI";
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

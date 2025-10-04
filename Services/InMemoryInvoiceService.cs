using System.Collections.Concurrent;
using Artemis.Svc.Models;

namespace Artemis.Svc.Services;

/// <summary>
/// In-memory implementation of invoice service for demonstration purposes
/// </summary>
public class InMemoryInvoiceService : IInvoiceService
{
    private readonly ConcurrentDictionary<int, Invoice> _invoices = new();
    private int _nextId = 1;

    public InMemoryInvoiceService()
    {
        // Seed with sample data
        SeedData();
    }

    public Task<IEnumerable<Invoice>> GetAllAsync()
    {
        return Task.FromResult(_invoices.Values.AsEnumerable());
    }

    public Task<Invoice?> GetByIdAsync(int id)
    {
        _invoices.TryGetValue(id, out Invoice? invoice);
        return Task.FromResult(invoice);
    }

    public Task<Invoice> CreateAsync(Invoice invoice)
    {
        invoice.Id = _nextId++;
        _invoices.TryAdd(invoice.Id, invoice);
        return Task.FromResult(invoice);
    }

    public Task<bool> UpdateAsync(int id, Invoice invoice)
    {
        if (!_invoices.ContainsKey(id))
        {
            return Task.FromResult(false);
        }

        invoice.Id = id;
        _invoices[id] = invoice;
        return Task.FromResult(true);
    }

    public Task<bool> DeleteAsync(int id)
    {
        return Task.FromResult(_invoices.TryRemove(id, out _));
    }

    private void SeedData()
    {
        var sampleInvoices = new List<Invoice>
        {
            new Invoice
            {
                Id = _nextId++,
                InvoiceNumber = "INV-2025-001",
                Date = DateTime.UtcNow.AddDays(-10),
                CustomerName = "Acme Corporation",
                Amount = 1500.00m,
                Status = InvoiceStatus.Paid
            },
            new Invoice
            {
                Id = _nextId++,
                InvoiceNumber = "INV-2025-002",
                Date = DateTime.UtcNow.AddDays(-5),
                CustomerName = "Tech Solutions Inc",
                Amount = 2750.50m,
                Status = InvoiceStatus.Sent
            },
            new Invoice
            {
                Id = _nextId++,
                InvoiceNumber = "INV-2025-003",
                Date = DateTime.UtcNow.AddDays(-2),
                CustomerName = "Global Services Ltd",
                Amount = 890.25m,
                Status = InvoiceStatus.Draft
            }
        };

        foreach (var invoice in sampleInvoices)
        {
            _invoices.TryAdd(invoice.Id, invoice);
        }
    }
}

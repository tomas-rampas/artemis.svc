using Artemis.Svc.Models;

namespace Artemis.Svc.Services;

/// <summary>
/// Interface for invoice service operations
/// </summary>
public interface IInvoiceService
{
    /// <summary>
    /// Get all invoices
    /// </summary>
    /// <returns>Collection of all invoices</returns>
    Task<IEnumerable<Invoice>> GetAllAsync();

    /// <summary>
    /// Get invoice by ID
    /// </summary>
    /// <param name="id">Invoice ID</param>
    /// <returns>Invoice if found, null otherwise</returns>
    Task<Invoice?> GetByIdAsync(int id);

    /// <summary>
    /// Create a new invoice
    /// </summary>
    /// <param name="invoice">Invoice to create</param>
    /// <returns>Created invoice with assigned ID</returns>
    Task<Invoice> CreateAsync(Invoice invoice);

    /// <summary>
    /// Update an existing invoice
    /// </summary>
    /// <param name="id">Invoice ID</param>
    /// <param name="invoice">Updated invoice data</param>
    /// <returns>True if updated, false if not found</returns>
    Task<bool> UpdateAsync(int id, Invoice invoice);

    /// <summary>
    /// Delete an invoice
    /// </summary>
    /// <param name="id">Invoice ID</param>
    /// <returns>True if deleted, false if not found</returns>
    Task<bool> DeleteAsync(int id);
}

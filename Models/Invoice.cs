namespace Artemis.Svc.Models;

/// <summary>
/// Represents an invoice in the system
/// </summary>
public class Invoice
{
    /// <summary>
    /// Unique identifier for the invoice
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    /// Invoice number (e.g., INV-2025-001)
    /// </summary>
    public required string InvoiceNumber { get; set; }

    /// <summary>
    /// Date when the invoice was created
    /// </summary>
    public DateTime Date { get; set; }

    /// <summary>
    /// Name of the customer
    /// </summary>
    public required string CustomerName { get; set; }

    /// <summary>
    /// Total amount of the invoice
    /// </summary>
    public decimal Amount { get; set; }

    /// <summary>
    /// Current status of the invoice
    /// </summary>
    public InvoiceStatus Status { get; set; }
}

/// <summary>
/// Status of an invoice
/// </summary>
public enum InvoiceStatus
{
    /// <summary>
    /// Invoice is in draft state
    /// </summary>
    Draft = 0,

    /// <summary>
    /// Invoice has been sent to customer
    /// </summary>
    Sent = 1,

    /// <summary>
    /// Invoice has been paid
    /// </summary>
    Paid = 2,

    /// <summary>
    /// Invoice is overdue
    /// </summary>
    Overdue = 3,

    /// <summary>
    /// Invoice has been cancelled
    /// </summary>
    Cancelled = 4
}

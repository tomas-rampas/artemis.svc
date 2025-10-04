using Artemis.Svc.Models;
using Artemis.Svc.Services;
using Microsoft.AspNetCore.Mvc;

namespace Artemis.Svc.Controllers;

/// <summary>
/// Controller for managing invoices
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class InvoicesController : ControllerBase
{
    private readonly IInvoiceService _invoiceService;
    private readonly ILogger<InvoicesController> _logger;

    public InvoicesController(IInvoiceService invoiceService, ILogger<InvoicesController> logger)
    {
        _invoiceService = invoiceService;
        _logger = logger;
    }

    /// <summary>
    /// Get all invoices
    /// </summary>
    /// <returns>List of all invoices</returns>
    /// <response code="200">Returns the list of invoices</response>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Invoice>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<Invoice>>> GetAll()
    {
        _logger.LogInformation("Retrieving all invoices");
        var invoices = await _invoiceService.GetAllAsync();
        return Ok(invoices);
    }

    /// <summary>
    /// Get a specific invoice by ID
    /// </summary>
    /// <param name="id">Invoice ID</param>
    /// <returns>The requested invoice</returns>
    /// <response code="200">Returns the invoice</response>
    /// <response code="404">If the invoice is not found</response>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Invoice), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<Invoice>> GetById(int id)
    {
        _logger.LogInformation("Retrieving invoice with ID: {Id}", id);
        var invoice = await _invoiceService.GetByIdAsync(id);

        if (invoice == null)
        {
            _logger.LogWarning("Invoice with ID {Id} not found", id);
            return NotFound(new { message = $"Invoice with ID {id} not found" });
        }

        return Ok(invoice);
    }

    /// <summary>
    /// Create a new invoice
    /// </summary>
    /// <param name="invoice">Invoice data</param>
    /// <returns>The created invoice</returns>
    /// <response code="201">Returns the newly created invoice</response>
    /// <response code="400">If the invoice data is invalid</response>
    [HttpPost]
    [ProducesResponseType(typeof(Invoice), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<Invoice>> Create([FromBody] Invoice invoice)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        _logger.LogInformation("Creating new invoice: {InvoiceNumber}", invoice.InvoiceNumber);
        var createdInvoice = await _invoiceService.CreateAsync(invoice);

        return CreatedAtAction(
            nameof(GetById),
            new { id = createdInvoice.Id },
            createdInvoice);
    }

    /// <summary>
    /// Update an existing invoice
    /// </summary>
    /// <param name="id">Invoice ID</param>
    /// <param name="invoice">Updated invoice data</param>
    /// <returns>No content if successful</returns>
    /// <response code="204">If the invoice was updated successfully</response>
    /// <response code="400">If the invoice data is invalid</response>
    /// <response code="404">If the invoice is not found</response>
    [HttpPut("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(int id, [FromBody] Invoice invoice)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        _logger.LogInformation("Updating invoice with ID: {Id}", id);
        var updated = await _invoiceService.UpdateAsync(id, invoice);

        if (!updated)
        {
            _logger.LogWarning("Invoice with ID {Id} not found for update", id);
            return NotFound(new { message = $"Invoice with ID {id} not found" });
        }

        return NoContent();
    }

    /// <summary>
    /// Delete an invoice
    /// </summary>
    /// <param name="id">Invoice ID</param>
    /// <returns>No content if successful</returns>
    /// <response code="204">If the invoice was deleted successfully</response>
    /// <response code="404">If the invoice is not found</response>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(int id)
    {
        _logger.LogInformation("Deleting invoice with ID: {Id}", id);
        var deleted = await _invoiceService.DeleteAsync(id);

        if (!deleted)
        {
            _logger.LogWarning("Invoice with ID {Id} not found for deletion", id);
            return NotFound(new { message = $"Invoice with ID {id} not found" });
        }

        return NoContent();
    }
}

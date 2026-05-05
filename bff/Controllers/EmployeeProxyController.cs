using bff.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace bff.Controllers;

[ApiController]
[Route("api")]
public class EmployeeProxyController : ControllerBase
{
    private readonly ApiClient _apiClient;

    public EmployeeProxyController(ApiClient apiClient)
    {
        _apiClient = apiClient;
    }

    [Authorize]
    [HttpGet("employees")]
    public async Task<IActionResult> GetEmployees()
    {
        var accessToken = await HttpContext.GetTokenAsync("access_token");
        
        if (string.IsNullOrEmpty(accessToken))
        {
            return Unauthorized(new { error = "No access token available" });
        }

        try
        {
            var response = await _apiClient.GetEmployeesAsync(accessToken);

            if (!response.IsSuccessStatusCode)
            {
                return StatusCode((int)response.StatusCode, new { error = "Failed to fetch employees from API" });
            }

            var content = await response.Content.ReadAsStringAsync();
            return Content(content, "application/json");
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = $"Internal server error: {ex.Message}" });
        }
    }
}

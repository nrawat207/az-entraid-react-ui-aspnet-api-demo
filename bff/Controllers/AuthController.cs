using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace bff.Controllers;

[ApiController]
[Route("auth")]
public class AuthController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public AuthController(IConfiguration configuration)
    {
        _configuration = configuration;
    }
    [HttpGet("me")]
    [Authorize]
    public IActionResult GetCurrentUser()
    {
        var identity = User.Identity;
        if (identity?.IsAuthenticated != true)
        {
            return Unauthorized();
        }

        var userId = User.FindFirst("sid")?.Value ?? User.FindFirst("sub")?.Value;
        var name = User.FindFirst("name")?.Value ?? identity.Name;

        return Ok(new { userId, name });
    }

    [HttpGet("login")]
    public IActionResult Login(string? returnUrl = null)
    {
        return Challenge(new AuthenticationProperties { RedirectUri = returnUrl ?? "/" }, OpenIdConnectDefaults.AuthenticationScheme);
    }

    [HttpGet("logout")]
    public async Task<IActionResult> Logout(string? returnUrl = null)
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignOutAsync(OpenIdConnectDefaults.AuthenticationScheme);

        var tenantId = _configuration["AzureAd:TenantId"];
        var postLogoutRedirectUri = returnUrl ?? "/";
        var logoutUrl = $"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/logout?post_logout_redirect_uri={Uri.EscapeDataString(postLogoutRedirectUri)}";
        
        return Redirect(logoutUrl);
    }

    [HttpPost("logout")]
    public async Task<IActionResult> LogoutPost(string? returnUrl = null)
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignOutAsync(OpenIdConnectDefaults.AuthenticationScheme);

        var tenantId = _configuration["AzureAd:TenantId"];
        var postLogoutRedirectUri = returnUrl ?? "/";
        var logoutUrl = $"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/logout?post_logout_redirect_uri={Uri.EscapeDataString(postLogoutRedirectUri)}";
        
        return Redirect(logoutUrl);
    }
}

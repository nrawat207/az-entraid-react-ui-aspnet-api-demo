using Azure.Identity;
using api.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add Key Vault configuration if running in Azure
var keyVaultUri = builder.Configuration["KeyVault:Uri"];
if (!string.IsNullOrEmpty(keyVaultUri))
{
    builder.Configuration.AddAzureKeyVault(
        new Uri(keyVaultUri),
        new DefaultAzureCredential());
}

// Add Application Insights
var appInsightsConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    if (!string.IsNullOrWhiteSpace(appInsightsConnectionString) &&
        !appInsightsConnectionString.StartsWith("{{", StringComparison.Ordinal))
    {
        options.ConnectionString = appInsightsConnectionString;
    }
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddControllers();
builder.Services.AddSwaggerGen();

// Database context with environment-specific provider
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var environment = builder.Environment.EnvironmentName;

builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (connectionString == null)
    {
        throw new InvalidOperationException("Connection string 'DefaultConnection' is missing.");
    }

    options.UseSqlServer(connectionString);

    //// Use SQL Server in production, SQLite in development
    //if (environment == "Production" && connectionString.Contains("Server="))
    //{
    //    options.UseSqlServer(connectionString);
    //}
    //else
    //{
    //    options.UseSqlite(connectionString);
    //}
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var tenantId = builder.Configuration["AzureAd:TenantId"];
        var audience = builder.Configuration["AzureAd:Audience"];
        
        options.Authority = $"https://login.microsoftonline.com/{tenantId}";
        options.Audience = audience;
        options.TokenValidationParameters.ValidateIssuer = true;
        options.TokenValidationParameters.ValidIssuer = $"https://login.microsoftonline.com/{tenantId}/v2.0";
    });

builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    var bffOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
        ?? new[] { "https://localhost:5001", "http://localhost:5001" };
    
    options.AddPolicy("BffOrigin", policy =>
    {
        policy.WithOrigins(bffOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

// Run migrations
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    dbContext.Database.Migrate();
}

// Health endpoint
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
// Redirect root URL to Swagger
app.Use(async (context, next) =>
{
    if (context.Request.Path == "/")
    {
        context.Response.Redirect("/swagger");
        return;
    }
    await next();
});

app.UseHttpsRedirection();
app.UseCors("BffOrigin");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

app.Run();

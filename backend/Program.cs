using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Hosting;
using Octopets.Backend.Data;
using Octopets.Backend.Endpoints;
using Octopets.Backend.Repositories;
using Octopets.Backend.Repositories.Interfaces;

using System.Text.Json.Serialization;

// Configure services
var builder = WebApplication.CreateBuilder(args);

// Add service defaults & Aspire client integrations
builder.AddServiceDefaults();

// Add DbContext using PostgreSQL
builder.AddNpgsqlDbContext<AppDbContext>("octopetsdb", configureDbContextOptions: options =>
{
    if (builder.Environment.IsProduction())
    {
        // Production-specific EF configurations
        options.EnableServiceProviderCaching();
        options.EnableSensitiveDataLogging(false);
        options.ConfigureWarnings(warnings => 
        {
            warnings.Ignore(CoreEventId.RedundantIndexRemoved);
            warnings.Ignore(RelationalEventId.PendingModelChangesWarning);
        });
    }
    else
    {
        // Development configurations
        options.EnableSensitiveDataLogging(true);
        options.EnableDetailedErrors(true);
    }
});

// Enhanced health checks will be configured by AddServiceDefaults
// but we can add specific health check endpoints

// Configure JSON serialization to handle circular references
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
    options.SerializerOptions.WriteIndented = true;
});

// Register repositories
builder.Services.AddScoped<IListingRepository, ListingRepository>();
builder.Services.AddScoped<IReviewRepository, ReviewRepository>();

// Enable CORS for frontend
builder.Services.AddCors(options =>
{
    if (builder.Environment.IsDevelopment())
    {
        // Development: Allow any origin for testing
        options.AddDefaultPolicy(policy =>
        {
            policy.AllowAnyOrigin()
                   .AllowAnyMethod()
                   .AllowAnyHeader();
        });
    }
    else
    {
        // Production: Restrict to specific origins
        var allowedOrigins = builder.Configuration.GetSection("Security:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();
        options.AddDefaultPolicy(policy =>
        {
            policy.WithOrigins(allowedOrigins)
                   .AllowAnyMethod()
                   .AllowAnyHeader()
                   .AllowCredentials();
        });
    }
});

// Build the app
var app = builder.Build();

// Map default endpoints added by AddServiceDefaults
app.MapDefaultEndpoints();

// Configure the HTTP request pipeline
// Only use HTTPS redirection in development - Container Apps handles HTTPS termination
if (app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}
app.UseCors();

// Initialize database in background - don't block startup
_ = Task.Run(async () =>
{
    try
    {
        // Add a small delay to allow the app to fully start
        await Task.Delay(2000);
        await DataInitializer.InitializeDatabase(app);
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "An error occurred during background database initialization");
    }
});

// Map endpoints
app.MapListingEndpoints();
app.MapReviewEndpoints();

// Root endpoint
app.MapGet("/", () => Results.Ok(new { 
    Message = "Octopets API", 
    Version = "1.0.0",
    Environment = app.Environment.EnvironmentName,
    Endpoints = new {
        Health = "/health",
        Listings = "/api/listings", 
        Reviews = "/api/reviews",
        Debug = "/api/debug/info"
    },
    Timestamp = DateTime.UtcNow 
}))
.WithName("Root")
.WithTags("Info");

// Health check endpoint - simple startup check
app.MapGet("/health", () => Results.Ok(new { Status = "Healthy", Timestamp = DateTime.UtcNow, Environment = app.Environment.EnvironmentName }))
   .WithName("HealthCheck")
   .WithTags("Health");

// More detailed health check with database connectivity
app.MapGet("/health/ready", async (AppDbContext dbContext) => 
{
    try
    {
        var canConnect = await dbContext.Database.CanConnectAsync();
        return Results.Ok(new { Status = "Ready", DatabaseConnected = canConnect, Timestamp = DateTime.UtcNow });
    }
    catch (Exception ex)
    {
        return Results.Ok(new { Status = "Starting", DatabaseConnected = false, Error = ex.Message, Timestamp = DateTime.UtcNow });
    }
})
.WithName("ReadinessCheck")
.WithTags("Health");

// Debug endpoint to check environment in production
app.MapGet("/api/debug/info", () => new 
{
    Environment = app.Environment.EnvironmentName,
    IsProduction = app.Environment.IsProduction(),
    IsDevelopment = app.Environment.IsDevelopment(),
    MachineName = Environment.MachineName,
    OSVersion = Environment.OSVersion.ToString()
})
.WithName("DebugInfo")
.WithTags("Debug");

app.Run();

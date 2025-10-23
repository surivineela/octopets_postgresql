using Microsoft.EntityFrameworkCore;
using Octopets.Backend.Data;

namespace Octopets.Backend.Data;

public static class DataInitializer
{
    public static async Task InitializeDatabase(WebApplication app)
    {
        using var scope = app.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<WebApplication>>();
        var environment = scope.ServiceProvider.GetRequiredService<IWebHostEnvironment>();
        
        try
        {
            // Apply migrations to create database schema
            if (dbContext.Database.GetPendingMigrations().Any())
            {
                logger.LogInformation("Applying pending database migrations...");
                try
                {
                    await dbContext.Database.MigrateAsync();
                    logger.LogInformation("Database migrations applied successfully.");
                }
                catch (Exception migrationEx)
                {
                    logger.LogError(migrationEx, "Failed to apply database migrations");
                    throw;
                }
            }
            else
            {
                logger.LogInformation("No pending database migrations found.");
                
                // Verify database connectivity
                logger.LogInformation("Verifying database connectivity...");
                try
                {
                    var canConnect = await dbContext.Database.CanConnectAsync();
                    if (canConnect)
                    {
                        logger.LogInformation("Database connection verified successfully.");
                    }
                    else
                    {
                        logger.LogWarning("Database connection check returned false.");
                    }
                }
                catch (Exception dbEx)
                {
                    logger.LogError(dbEx, "Database connectivity check failed.");
                    throw;
                }
            }

            // Seed development data if in development environment and no data exists
            if (environment.IsDevelopment())
            {
                SeedDevelopmentData(dbContext, logger);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "An error occurred while applying database migrations");
            throw;
        }
    }

    private static void SeedDevelopmentData(AppDbContext dbContext, ILogger logger)
    {
        // Check if we already have listings (seed data already applied)
        if (dbContext.Listings.Any())
        {
            logger.LogInformation("Database already contains listings. Skipping development data seeding.");
            return;
        }

        logger.LogInformation("Seeding development data...");

        // Add some additional development listings beyond what's in the migration
        var additionalListings = new[]
        {
            new Models.Listing
            {
                Id = 10001, // Use high ID to avoid conflicts with migration seed data
                Name = "Dev Test Park",
                Description = "A test park for development purposes",
                Price = 15.00m,
                Address = "123 Dev Street",
                Location = "Development City",
                Type = "Park",
                AllowedPets = new List<string> { "Dogs", "Cats" },
                Amenities = new List<string> { "Parking", "Water Fountains", "Benches" },
                Rating = 4.2,
                Photos = new List<string> { "/images/venues/dev-park.jpg" },
                CreatedAt = DateTime.UtcNow
            }
        };

        try
        {
            dbContext.Listings.AddRange(additionalListings);
            dbContext.SaveChanges();
            logger.LogInformation("Development data seeded successfully. Added {Count} additional listings.", additionalListings.Length);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not seed additional development data. This is normal if migration seed data is sufficient.");
        }
    }
}

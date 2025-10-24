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
            
            // Update existing listings with proper photo paths
            await UpdateListingPhotos(dbContext, logger);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "An error occurred while applying database migrations");
            throw;
        }
    }

    private static async Task UpdateListingPhotos(AppDbContext dbContext, ILogger logger)
    {
        try
        {
            logger.LogInformation("Checking and updating listing photos...");
            
            // Define the photo mappings for each listing (just filenames, component adds path)
            var photoMappings = new Dictionary<int, List<string>>
            {
                { 1, new List<string> { "park1.jpg", "park2.jpg" } },
                { 2, new List<string> { "cafe1.jpg", "cafe2.jpg" } },
                { 3, new List<string> { "home1.jpg", "home2.jpg" } },
                { 4, new List<string> { "hotel1.jpg", "hotel2.jpg" } },
                { 5, new List<string> { "store1.jpg", "store2.jpg" } },
                { 6, new List<string> { "moochs1.jpg", "moochs2.jpg" } }
            };
            
            int updatedCount = 0;
            foreach (var (listingId, photos) in photoMappings)
            {
                var listing = await dbContext.Listings.FindAsync(listingId);
                if (listing != null)
                {
                    // Update if empty OR if paths contain full path (migration from old format)
                    bool needsUpdate = listing.Photos == null || !listing.Photos.Any() || 
                                      listing.Photos.Any(p => p.Contains("/images/venues/"));
                    
                    if (needsUpdate)
                    {
                        listing.Photos = photos;
                        updatedCount++;
                        logger.LogInformation("Updated photos for listing {ListingId} - {ListingName}", listingId, listing.Name);
                    }
                }
            }
            
            if (updatedCount > 0)
            {
                await dbContext.SaveChangesAsync();
                logger.LogInformation("Successfully updated photos for {Count} listings", updatedCount);
            }
            else
            {
                logger.LogInformation("No listings needed photo updates");
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not update listing photos. This may be normal if photos are already set.");
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

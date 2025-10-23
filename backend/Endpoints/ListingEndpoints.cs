using Octopets.Backend.Models;
using Octopets.Backend.Repositories.Interfaces;

namespace Octopets.Backend.Endpoints;

public static class ListingEndpoints
{    // Method to simulate memory exhaustion by allocating ~1GB of memory
    private static void AReallyExpensiveOperation()
    {
        // Create lists to hold large amounts of data
        var memoryHogs = new List<byte[]>();

        // Allocate memory in chunks until we reach approximately 1GB
        // Each iteration allocates 100MB
        for (int i = 0; i < 10; i++)
        {
            // Allocate 100MB per iteration (100 * 1024 * 1024 = 104,857,600 bytes)
            var largeArray = new byte[100 * 1024 * 1024];

            // Fill with random data to ensure memory is actually allocated
            new Random().NextBytes(largeArray);

            // Add to list to prevent garbage collection
            memoryHogs.Add(largeArray);

            // Add a small delay to let the effect be more visible
            Thread.Sleep(100);
        }

        // Retain the reference to prevent garbage collection
        GC.KeepAlive(memoryHogs);
    }

    public static void MapListingEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/listings")
                       .WithTags("Listings");

        // GET all listings
        group.MapGet("/", async (IListingRepository repository) =>
        {
            var listings = await repository.GetAllAsync();
            return Results.Ok(listings);
        })
        .WithName("GetAllListings")
        .WithDescription("Gets all listings");
        group.MapGet("/{id:int}", async (int id, IListingRepository repository, IConfiguration config) =>
        {
            // Only throw exception or simulate memory issues if ERRORS flag is set to true
            if (config.GetValue<bool>("ERRORS"))
            {
                AReallyExpensiveOperation();
            }

            var listing = await repository.GetByIdAsync(id);
            return listing is null ? Results.NotFound() : Results.Ok(listing);
        })
        .WithName("GetListingById")
        .WithDescription("Gets a listing by its ID");
        group.MapPost("/", async (Listing listing, IListingRepository repository, IConfiguration config) =>
        {
            if (!config.GetValue<bool>("ENABLE_CRUD", true))
            {
                throw new InvalidOperationException("CRUD operations are currently disabled");
            }
            var newListing = await repository.CreateAsync(listing);
            return Results.Created($"/api/listings/{newListing.Id}", newListing);
        })
        .WithName("CreateListing")
        .WithDescription("Creates a new listing")
        ;

        // PUT update listing
        group.MapPut("/{id:int}", async (int id, Listing listing, IListingRepository repository, IConfiguration config) =>
        {
            if (!config.GetValue<bool>("ENABLE_CRUD", true))
            {
                throw new InvalidOperationException("CRUD operations are currently disabled");
            }
            var updatedListing = await repository.UpdateAsync(id, listing);
            return updatedListing is null ? Results.NotFound() : Results.Ok(updatedListing);
        })
        .WithName("UpdateListing")
        .WithDescription("Updates an existing listing")
        ;

        // DELETE listing
        group.MapDelete("/{id:int}", async (int id, IListingRepository repository, IConfiguration config) =>
        {
            if (!config.GetValue<bool>("ENABLE_CRUD", true))
            {
                throw new InvalidOperationException("CRUD operations are currently disabled");
            }
            var result = await repository.DeleteAsync(id);
            return result ? Results.NoContent() : Results.NotFound();
        })
        .WithName("DeleteListing")
        .WithDescription("Deletes a listing")
        ;
    }
}

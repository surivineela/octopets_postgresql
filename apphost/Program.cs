var builder = DistributedApplication.CreateBuilder(args);

// Add PostgreSQL database
var postgres = builder.AddPostgres("postgres")
    .WithEnvironment("POSTGRES_DB", "octopets");

var octopetsDb = postgres.AddDatabase("octopetsdb");

var api = builder.AddProject<Projects.Octopets_Backend>("octopetsapi")
        .WithReference(octopetsDb)
        .WithExternalHttpEndpoints()
        .WithEnvironment("ERRORS", builder.ExecutionContext.IsPublishMode ? "true" : "false")
        .WithEnvironment("ENABLE_CRUD", builder.ExecutionContext.IsPublishMode ? "false" : "true");

// Only add Application Insights in non-development environments
if (builder.ExecutionContext.IsPublishMode)
{
    var frontend = builder.AddDockerfile("octopetsfe", "../frontend", "Dockerfile")
        .WithReference(api)
        .WaitFor(api)
        .WithHttpEndpoint(80, 80)
        .WithExternalHttpEndpoints()
        .WithBuildArg("REACT_APP_USE_MOCK_DATA",  "false");

    var insights = builder.AddAzureApplicationInsights("octopets-appinsights");
    api.WithReference(insights);
    frontend.WithReference(insights);
}
else
{
    builder.AddNpmApp("octopetsfe", "../frontend")
    .WithReference(api)
    .WaitFor(api)
    .WithHttpEndpoint(env: "PORT")
    .WithEnvironment("BROWSER", "none");
}

builder.Build().Run(); 
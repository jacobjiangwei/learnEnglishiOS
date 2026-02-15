var builder = DistributedApplication.CreateBuilder(args);

// Cosmos DB emulator (vnext-preview) — same pattern as Euler
var cosmos = builder.AddContainer("cosmos", "mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator", "vnext-preview")
    .WithHttpEndpoint(port: 8081, targetPort: 8081, name: "emulator")
    .WithHttpEndpoint(port: 1234, targetPort: 1234, name: "explorer")
    .WithEnvironment("PROTOCOL", "http")
    .WithHttpHealthCheck(path: "/", endpointName: "emulator");

var api = builder.AddProject<Projects.Volingo_Api>("volingo-api")
    .WithEnvironment("ConnectionStrings__cosmos", "AccountEndpoint=http://localhost:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==")
    .WithEnvironment("CosmosDb__DatabaseName", "volingo")
    .WaitFor(cosmos)
    .WithExternalHttpEndpoints();

builder.Build().Run();

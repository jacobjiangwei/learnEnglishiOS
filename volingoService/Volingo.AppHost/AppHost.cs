var builder = DistributedApplication.CreateBuilder(args);

var api = builder.AddProject<Projects.Volingo_Api>("volingo-api")
    .WithExternalHttpEndpoints();

builder.Build().Run();

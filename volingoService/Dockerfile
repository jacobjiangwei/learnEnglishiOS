FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src
COPY ["Volingo.Api/Volingo.Api.csproj", "Volingo.Api/"]
COPY ["Volingo.ServiceDefaults/Volingo.ServiceDefaults.csproj", "Volingo.ServiceDefaults/"]
RUN dotnet restore "Volingo.Api/Volingo.Api.csproj"
COPY . .
WORKDIR "/src/Volingo.Api"
RUN dotnet build "Volingo.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Volingo.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "Volingo.Api.dll"]

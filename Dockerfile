# Corporate requirement: Using Red Hat Universal Base Images (UBI) instead of Microsoft official images
# Base images built from Dockerfile.ubi8-dotnet-sdk and Dockerfile.ubi8-aspnet-runtime

# Stage 1: Build
FROM artemis/ubi8-dotnet-sdk:9.0 AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY ["artemis.svc.csproj", "./"]
RUN dotnet restore "artemis.svc.csproj"

# Copy source code and build
COPY . .
RUN dotnet build "artemis.svc.csproj" -c Release -o /app/build

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish "artemis.svc.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 3: Runtime
# Using Red Hat UBI base image that already includes:
# - ASP.NET Core 9.0 runtime
# - PowerShell Core 7+
# - Non-root user 'artemis' (uid 1000)
# - Certificate directories configured
FROM artemis/ubi8-aspnet-runtime:9.0 AS final
WORKDIR /app

# Copy published application
COPY --from=publish --chown=artemis:artemis /app/publish .

# Copy PowerShell scripts
COPY --chown=artemis:artemis Install-DockerCertificates.ps1 /app/
COPY --chown=artemis:artemis docker-entrypoint.ps1 /app/

USER artemis

# Expose ports
EXPOSE 5000
EXPOSE 5001

# Set environment variables
ENV ASPNETCORE_URLS="http://+:5000;https://+:5001"
ENV ASPNETCORE_ENVIRONMENT=Production

# Use PowerShell entrypoint that installs certificates before starting app
ENTRYPOINT ["pwsh", "-File", "/app/docker-entrypoint.ps1"]

# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
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
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

# Install PowerShell
RUN apt-get update && \
    apt-get install -y wget apt-transport-https software-properties-common && \
    wget -q "https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb" && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -m -u 1000 artemis && chown -R artemis:artemis /app

# Create .NET certificate store directories (per Microsoft documentation)
# https://learn.microsoft.com/en-us/dotnet/standard/security/cross-platform-cryptography#x509store
RUN mkdir -p /home/artemis/.dotnet/corefx/cryptography/x509stores/my && \
    mkdir -p /home/artemis/.dotnet/corefx/cryptography/x509stores/root && \
    mkdir -p /home/artemis/.dotnet/corefx/cryptography/x509stores/ca && \
    chown -R artemis:artemis /home/artemis/.dotnet

# Create certificate mount points (matching Install-DockerCertificates.ps1 paths)
RUN mkdir -p /app/certs/docker/my /app/certs/docker/root /app/certs/server && \
    chown -R artemis:artemis /app/certs

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

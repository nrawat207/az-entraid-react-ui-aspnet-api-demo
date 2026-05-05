# Build stage for BFF
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder

WORKDIR /build

# Copy project file
COPY bff/*.csproj ./

# Restore dependencies
RUN dotnet restore

# Copy all source code
COPY bff/ ./

# Build the application
RUN dotnet build -c Release -o /app/build

# Publish stage
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS publish

WORKDIR /build

# Copy built files from builder
COPY --from=builder /app/build ./

# Publish the application
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy published app from publish stage
COPY --from=publish /app/publish .

# Expose port 5001 (HTTPS) and 5000 (HTTP for internal)
EXPOSE 5001 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000;https://+:5001
ENV ASPNETCORE_ENVIRONMENT=Production

# Start the application
ENTRYPOINT ["dotnet", "bff.dll"]

# Build stage for BFF
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS builder

WORKDIR /build

# Copy project file
COPY bff/*.csproj ./

# Restore dependencies
RUN dotnet restore

# Copy all source code
COPY bff/ ./

# Build and publish the application
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy published app from builder stage
COPY --from=builder /app/publish .

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

# Microsoft Entra ID React + ASP.NET Core BFF + Protected API Demo

This repository is a small end-to-end authentication sample. It shows a React TypeScript single-page app calling an ASP.NET Core Backend-for-Frontend (BFF), which signs users in with Microsoft Entra ID and then calls a protected ASP.NET Core API with an access token.

The main idea is deliberate: the browser never handles API access tokens directly. The React app talks to the BFF with a secure cookie, and the BFF is responsible for OpenID Connect sign-in and downstream API token handling.

## Architecture

```text
Browser / React TypeScript app
  http://localhost:3000
  - Shows login/logout UI
  - Calls the BFF with credentials: include
  - Does not store tokens

        |
        | cookie-based requests
        v

ASP.NET Core BFF
  https://localhost:5001
  - OpenID Connect sign-in with Microsoft Entra ID
  - HttpOnly secure cookie session
  - /auth/me, /auth/login, /auth/logout
  - /api/employees proxy endpoint
  - Sends bearer token to protected API

        |
        | bearer access token
        v

ASP.NET Core protected API
  https://localhost:5002
  - JWT bearer authentication
  - GET /employees requires authorization
  - Returns in-memory employee data
```

## Projects

```text
.
|-- frontend/                         React 19 + TypeScript + Vite app
|   |-- src/api.ts                    BFF HTTP client helpers
|   |-- src/types.ts                  Shared frontend User and Employee types
|   |-- src/App.tsx                   App shell and initial auth check
|   |-- src/components/Header.tsx     Login/logout header
|   |-- src/components/EmployeeTable.tsx
|   `-- src/pages/EmployeePage.tsx
|
|-- bff/                              ASP.NET Core Backend-for-Frontend
|   |-- Program.cs                    Cookie + OpenID Connect auth, CORS, Swagger
|   |-- Controllers/AuthController.cs /auth endpoints
|   |-- Controllers/EmployeeProxyController.cs
|   `-- Services/ApiClient.cs         Calls the protected API
|
|-- api/                              ASP.NET Core protected API
|   |-- Program.cs                    JWT bearer auth, CORS, Swagger
|   |-- Controllers/EmployeesController.cs
|   |-- Services/EmployeeService.cs   In-memory employee records
|   `-- Models/Employee.cs
|
`-- az-entraid-react-ui-aspnet-api-demo.sln
```

## Prerequisites

- .NET SDK 10.0 or later
- Node.js 18 or later
- npm
- A Microsoft Entra ID tenant
- Two Entra app registrations: one for the BFF web app and one for the protected API

Trust the local ASP.NET Core HTTPS development certificate if you have not already:

```powershell
dotnet dev-certs https --trust
```

## Microsoft Entra ID Setup

You need two app registrations.

### 1. Protected API app registration

Create an app registration for the API:

- Name: `entra-demo-api`
- Supported account type: choose the option appropriate for your tenant
- Redirect URI: leave empty

After registration:

1. Copy the Directory tenant ID.
2. Copy the Application client ID.
3. Go to Expose an API.
4. Set the Application ID URI, usually `api://<api-client-id>`.
5. Add a delegated scope, for example `access_as_user`.
6. Copy the full scope value, for example `api://<api-client-id>/access_as_user`.

Use these values in `api/appsettings.Development.json`:

```json
{
  "AzureAd": {
    "TenantId": "<tenant-id>",
    "Audience": "api://<api-client-id>"
  }
}
```

### 2. BFF app registration

Create an app registration for the BFF:

- Name: `entra-demo-bff`
- Platform: Web
- Redirect URI: `https://localhost:5001/signin-oidc`

After registration:

1. Copy the Application client ID.
2. Create a client secret under Certificates and secrets.
3. Go to API permissions.
4. Add delegated permission for the protected API scope, for example `access_as_user`.
5. Grant admin consent if your tenant policy requires it.

Use these values in `bff/appsettings.Development.json`:

```json
{
  "AzureAd": {
    "TenantId": "<tenant-id>",
    "ClientId": "<bff-client-id>",
    "ClientSecret": "<bff-client-secret>",
    "RedirectUri": "https://localhost:5001",
    "ApiScope": "api://<api-client-id>/access_as_user"
  },
  "Api": {
    "BaseUrl": "https://localhost:5002"
  }
}
```

The checked-in `appsettings.json` files contain placeholders only. Keep real secrets out of source control. For local development, prefer `appsettings.Development.json`, environment variables, or user secrets.

## Frontend Configuration

Create `frontend/.env.local`:

```env
VITE_BFF_URL=https://localhost:5001
```

The frontend defaults to `http://localhost:5001` if this value is missing, but HTTPS is recommended for this sample because the BFF uses secure cookies.

## Install Dependencies

Restore .NET projects:

```powershell
dotnet restore .\az-entraid-react-ui-aspnet-api-demo.sln
```

Install frontend packages:

```powershell
cd frontend
npm install
cd ..
```

## Run Locally

Use three terminals from the repository root.

Terminal 1, start the protected API:

```powershell
dotnet run --project .\api\api.csproj --urls "https://localhost:5002"
```

Terminal 2, start the BFF:

```powershell
dotnet run --project .\bff\bff.csproj --urls "https://localhost:5001"
```

Terminal 3, start the React app on the CORS-approved dev port:

```powershell
cd frontend
npm run dev -- --port 3000
```

Open:

```text
http://localhost:3000
```

## Expected Flow

1. The React app calls `GET https://localhost:5001/auth/me`.
2. If the user is not signed in, the app shows a sign-in prompt.
3. Clicking Sign in calls `GET /auth/login`.
4. The BFF redirects to Microsoft Entra ID.
5. Entra ID redirects back to `https://localhost:5001/signin-oidc`.
6. The BFF stores the session in a secure HttpOnly cookie.
7. The React app calls `GET /api/employees` on the BFF.
8. The BFF forwards the request to `https://localhost:5002/employees` with a bearer access token.
9. The API validates the token and returns employee data.

## Build and Validate

Build both .NET projects:

```powershell
dotnet build .\api\api.csproj
dotnet build .\bff\bff.csproj
```

Build the frontend:

```powershell
cd frontend
npm run build
```

Lint the frontend:

```powershell
cd frontend
npm run lint
```

Build the solution:

```powershell
dotnet build .\az-entraid-react-ui-aspnet-api-demo.sln
```

The solution contains the `api` and `bff` projects. The Vite frontend is built separately with npm.

## Endpoints

### BFF

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/auth/me` | Cookie if signed in | Returns current user info or 401 |
| GET | `/auth/login` | None | Starts the Entra ID OpenID Connect sign-in flow |
| GET | `/auth/logout` | Cookie if signed in | Signs out of the local cookie and OIDC session |
| POST | `/auth/logout` | Cookie if signed in | POST variant of logout |
| GET | `/api/employees` | Cookie | Gets employees by calling the protected API |

### Protected API

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/employees` | JWT bearer token | Returns the in-memory employee list |

Swagger is enabled in development for both ASP.NET Core projects:

- BFF: `https://localhost:5001/swagger`
- API: `https://localhost:5002/swagger`

## Troubleshooting

### CORS errors from the browser

Run the frontend on port 3000:

```powershell
npm run dev -- --port 3000
```

The BFF currently allows `http://localhost:3000` and `https://localhost:3000`.

### Redirect URI mismatch

Make sure the BFF app registration has this exact redirect URI:

```text
https://localhost:5001/signin-oidc
```

Also make sure `bff/appsettings.Development.json` has:

```json
"RedirectUri": "https://localhost:5001"
```

### Invalid audience from the API

Check that:

- `api/appsettings.Development.json` has `Audience` set to `api://<api-client-id>`.
- The BFF requests the delegated API scope, for example `api://<api-client-id>/access_as_user`.
- The API app registration exposes that scope.

### No access token available

Check that the BFF OpenID Connect setup includes the API scope and that `SaveTokens = true` is still set in `bff/Program.cs`.

### HTTPS certificate errors

Run:

```powershell
dotnet dev-certs https --trust
```

Then restart the API, BFF, and browser.

### Frontend cannot reach the BFF

Create or update `frontend/.env.local`:

```env
VITE_BFF_URL=https://localhost:5001
```

Then restart the Vite dev server.

## Security Notes

- The React app does not store access tokens in local storage or session storage.
- The BFF uses HttpOnly secure cookies for the browser session.
- The protected API requires JWT bearer authentication.
- CORS is restricted to known local frontend origins.
- Do not commit real `ClientSecret` values.
- This is a learning sample, not a production-ready security baseline.

## Common Customizations

- Replace `EmployeeService` with a database-backed service.
- Add role or policy-based authorization.
- Add create, update, and delete employee endpoints.
- Move local configuration to user secrets.
- Add automated tests for the BFF and API.
- Add the frontend to a broader build pipeline.

## License

This repository is intended for learning and experimentation. Adapt it for your own use case.

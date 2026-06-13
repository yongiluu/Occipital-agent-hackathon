# Environment Setup Guide

## Overview

This project requires environment variables for API integrations with external services. These credentials are **never committed to the repository** and must be configured locally for development and deployment.

## Security Notice

⚠️ **IMPORTANT:** The `.env` file is listed in `.gitignore` and should **never** be committed to version control. Always keep sensitive credentials on your local machine or secure CI/CD secrets management.

## Getting Started

### 1. Create the `.env` File

Navigate to the `iris_app/` directory and create a `.env` file from the template:

```bash
cd iris_app
cp .env.template .env
```

### 2. Obtain API Credentials

Fill in the `.env` file with your actual API keys. Below are the services and how to obtain credentials:

#### **Azure Foundry (Microsoft Agents League)**

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Foundry resource group
3. Find your Foundry instance and note:
   - **Endpoint**: Resource URL (looks like `https://[region]-resource.services.ai.azure.com/api/projects/[project-id]`)
   - **API Key**: Found in "Keys and Endpoint" section

```env
AZURE_FOUNDRY_ENDPOINT=https://your-region-resource.services.ai.azure.com/api/projects/your-project-id
AZURE_FOUNDRY_KEY=your-azure-foundry-api-key
```

#### **Azure AI Search**

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Azure Search resource
3. Copy:
   - **Endpoint**: The search service URL (format: `https://[service-name].search.windows.net`)
   - **API Key**: Found under "Keys" section (use either admin or query key)

```env
AZURE_SEARCH_ENDPOINT=https://your-search-service.search.windows.net
AZURE_SEARCH_KEY=your-azure-search-api-key
```

#### **LocationIQ (Geolocation & Reverse Geocoding)**

1. Visit [LocationIQ](https://locationiq.com/)
2. Sign up for a free account (free tier: 5,000 requests/day)
3. Navigate to your API tokens dashboard
4. Copy your API key (starts with `pk.`)

```env
LOCATIONIQ_KEY=pk.your_locationiq_api_key
```

#### **OpenWeatherMap (Weather Data)**

1. Visit [OpenWeatherMap](https://openweathermap.org/api)
2. Sign up for a free account (free tier: 1,000 calls/day)
3. Go to API keys section in your account
4. Copy your default API key

```env
OPENWEATHER_KEY=your_openweather_api_key
```

### 3. Verify Your `.env` File

Your completed `.env` file should look like this (with your actual credentials):

```env
AZURE_FOUNDRY_ENDPOINT=https://occipital-east-resource.services.ai.azure.com/api/projects/occipital-east
AZURE_FOUNDRY_KEY=YourActualAzureFoundryKeyHere
AZURE_SEARCH_ENDPOINT=https://occipital-search-dm.search.windows.net
AZURE_SEARCH_KEY=YourActualAzureSearchKeyHere
LOCATIONIQ_KEY=pk.YourActualLocationIQKeyHere
OPENWEATHER_KEY=YourActualOpenWeatherKeyHere
```

### 4. Load Environment in App

The app automatically loads the `.env` file on startup via `EnvConfig.init()` in `main.dart`. No additional setup is required once the `.env` file exists.

## Development Workflow

### Local Development

```bash
cd iris_app
flutter pub get
flutter run
```

The environment variables will be loaded automatically at app startup.

### Running Tests

Tests requiring API access should use mocked environment variables or be configured to skip external API calls.

## CI/CD Deployment

For GitHub Actions, GitLab CI, or other CI/CD systems:

1. **Add secrets** to your CI/CD platform (GitHub Secrets, GitLab Variables, etc.)
2. **Create `.env` at build time**:

```yaml
# Example GitHub Actions
- name: Create .env file
  env:
    AZURE_FOUNDRY_ENDPOINT: ${{ secrets.AZURE_FOUNDRY_ENDPOINT }}
    AZURE_FOUNDRY_KEY: ${{ secrets.AZURE_FOUNDRY_KEY }}
    AZURE_SEARCH_ENDPOINT: ${{ secrets.AZURE_SEARCH_ENDPOINT }}
    AZURE_SEARCH_KEY: ${{ secrets.AZURE_SEARCH_KEY }}
    LOCATIONIQ_KEY: ${{ secrets.LOCATIONIQ_KEY }}
    OPENWEATHER_KEY: ${{ secrets.OPENWEATHER_KEY }}
  run: |
    cat > iris_app/.env << EOF
    AZURE_FOUNDRY_ENDPOINT=$AZURE_FOUNDRY_ENDPOINT
    AZURE_FOUNDRY_KEY=$AZURE_FOUNDRY_KEY
    AZURE_SEARCH_ENDPOINT=$AZURE_SEARCH_ENDPOINT
    AZURE_SEARCH_KEY=$AZURE_SEARCH_KEY
    LOCATIONIQ_KEY=$LOCATIONIQ_KEY
    OPENWEATHER_KEY=$OPENWEATHER_KEY
    EOF
```

## Troubleshooting

### Environment Variables Not Loading

1. Verify `.env` exists in `iris_app/` directory
2. Check file encoding is UTF-8 (not UTF-8 BOM)
3. Ensure no trailing spaces after values
4. Restart Flutter dev server: `flutter clean && flutter pub get`

### API Errors

- **401 Unauthorized**: Check that API keys are correct and not expired
- **Rate Limited**: Check API quotas and upgrade plan if needed
- **Invalid Endpoint**: Verify endpoint URLs match your service region

## Security Best Practices

✅ **DO:**
- Keep `.env` on your local machine only
- Rotate API keys regularly
- Use separate keys for development, staging, and production
- Review API usage regularly for unauthorized access
- Store backup keys securely (e.g., password manager)

❌ **DON'T:**
- Commit `.env` to version control
- Share credentials via email or chat
- Use the same keys across multiple projects
- Expose keys in error logs or debugging output
- Disable HTTPS when transmitting credentials

## Additional Resources

- [Flutter Dotenv Documentation](https://pub.dev/packages/flutter_dotenv)
- [Azure SDK Best Practices](https://learn.microsoft.com/en-us/azure/developer/intro/best-practices)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

**Last Updated:** 2026-06-13  
**For Questions:** Refer to the main [README.md](./README.md)

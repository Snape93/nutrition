# Setup Production Environment Variables
# Usage: .\setup_production_env.ps1

Write-Host "⚙️  Production Environment Setup" -ForegroundColor Green
Write-Host "This script will help you set up environment variables for production deployment" -ForegroundColor Cyan

$envVars = @{}

# Backend URL
Write-Host "`n1. Backend URL (e.g., https://your-app.railway.app):" -ForegroundColor Yellow
$backendUrl = Read-Host
$envVars["API_BASE_URL"] = $backendUrl

# RapidAPI Key
Write-Host "`n2. RapidAPI Key (ExerciseDB) [Press Enter to skip if already set]:" -ForegroundColor Yellow
$rapidApiKey = Read-Host
if ($rapidApiKey) {
    $envVars["RAPIDAPI_KEY"] = $rapidApiKey
}

# Create .env.production file
Write-Host "`n📝 Creating production environment file..." -ForegroundColor Yellow

$envContent = @"
# Production Environment Variables
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Backend API URL
API_BASE_URL=$backendUrl

# RapidAPI Key (ExerciseDB)
RAPIDAPI_KEY=$rapidApiKey

# Build commands:
# Web: flutter build web --dart-define=API_BASE_URL=$backendUrl --release
# Android: flutter build apk --release --dart-define=API_BASE_URL=$backendUrl
# iOS: flutter build ios --release --dart-define=API_BASE_URL=$backendUrl
"@

$envContent | Out-File -FilePath ".env.production" -Encoding UTF8

Write-Host "✅ Created .env.production file" -ForegroundColor Green
Write-Host "`n📋 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review .env.production file" -ForegroundColor White
Write-Host "  2. Use the build scripts with your backend URL:" -ForegroundColor White
Write-Host "     .\build_android.ps1 -BackendUrl `"$backendUrl`"" -ForegroundColor Gray
Write-Host "     .\deploy_web.ps1 -BackendUrl `"$backendUrl`"" -ForegroundColor Gray


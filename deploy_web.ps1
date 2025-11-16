# Deploy Flutter Web App
# Usage: .\deploy_web.ps1 -BackendUrl "https://your-backend.railway.app" -Platform "firebase"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackendUrl,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("firebase", "vercel", "netlify")]
    [string]$Platform = "firebase"
)

Write-Host "🚀 Deploying Flutter Web App..." -ForegroundColor Green
Write-Host "Backend URL: $BackendUrl" -ForegroundColor Cyan
Write-Host "Platform: $Platform" -ForegroundColor Cyan

# Navigate to Flutter app directory
Set-Location -Path "nutrition_flutter"

# Clean previous builds
Write-Host "`n📦 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "📥 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build web app with production API URL
Write-Host "🔨 Building web app..." -ForegroundColor Yellow
flutter build web --dart-define=API_BASE_URL=$BackendUrl --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

# Deploy based on platform
switch ($Platform) {
    "firebase" {
        Write-Host "🔥 Deploying to Firebase..." -ForegroundColor Yellow
        firebase deploy --only hosting
    }
    "vercel" {
        Write-Host "▲ Deploying to Vercel..." -ForegroundColor Yellow
        Set-Location -Path "build\web"
        vercel --prod
        Set-Location -Path "..\.."
    }
    "netlify" {
        Write-Host "🌐 Deploying to Netlify..." -ForegroundColor Yellow
        Set-Location -Path "build\web"
        netlify deploy --prod
        Set-Location -Path "..\.."
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Deployment successful!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Set-Location -Path ".."


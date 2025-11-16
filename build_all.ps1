# Build Flutter App for All Platforms
# Usage: .\build_all.ps1 -BackendUrl "https://your-backend.railway.app"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackendUrl
)

Write-Host "🚀 Building Flutter App for All Platforms..." -ForegroundColor Green
Write-Host "Backend URL: $BackendUrl" -ForegroundColor Cyan

# Navigate to Flutter app directory
Set-Location -Path "nutrition_flutter"

# Clean and get dependencies
Write-Host "`n📦 Preparing build environment..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Build Web
Write-Host "`n🌐 Building Web App..." -ForegroundColor Yellow
flutter build web --dart-define=API_BASE_URL=$BackendUrl --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Web build failed!" -ForegroundColor Red
}

# Build Android APK
Write-Host "`n🤖 Building Android APK..." -ForegroundColor Yellow
flutter build apk --release --dart-define=API_BASE_URL=$BackendUrl
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Android build failed!" -ForegroundColor Red
}

# Build Android App Bundle
Write-Host "`n📦 Building Android App Bundle..." -ForegroundColor Yellow
flutter build appbundle --release --dart-define=API_BASE_URL=$BackendUrl
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ App Bundle build failed!" -ForegroundColor Red
}

# Build Windows
Write-Host "`n🪟 Building Windows App..." -ForegroundColor Yellow
flutter build windows --release --dart-define=API_BASE_URL=$BackendUrl
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Windows build failed!" -ForegroundColor Red
}

Write-Host "`n✅ Build process completed!" -ForegroundColor Green
Write-Host "`n📦 Build outputs:" -ForegroundColor Cyan
Write-Host "  Web: nutrition_flutter\build\web" -ForegroundColor White
Write-Host "  Android APK: nutrition_flutter\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
Write-Host "  Android Bundle: nutrition_flutter\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor White
Write-Host "  Windows: nutrition_flutter\build\windows\x64\runner\Release" -ForegroundColor White

Set-Location -Path ".."


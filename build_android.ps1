# Build Android APK/App Bundle for Production
# Usage: .\build_android.ps1 -BackendUrl "https://your-backend.railway.app" -BuildType "apk"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackendUrl,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("apk", "appbundle")]
    [string]$BuildType = "apk"
)

Write-Host "🤖 Building Android App..." -ForegroundColor Green
Write-Host "Backend URL: $BackendUrl" -ForegroundColor Cyan
Write-Host "Build Type: $BuildType" -ForegroundColor Cyan

# Navigate to Flutter app directory
Set-Location -Path "nutrition_flutter"

# Clean previous builds
Write-Host "`n📦 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "📥 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build Android app
Write-Host "🔨 Building Android $BuildType..." -ForegroundColor Yellow

if ($BuildType -eq "apk") {
    flutter build apk --release --dart-define=API_BASE_URL=$BackendUrl
    $outputPath = "build\app\outputs\flutter-apk\app-release.apk"
} else {
    flutter build appbundle --release --dart-define=API_BASE_URL=$BackendUrl
    $outputPath = "build\app\outputs\bundle\release\app-release.aab"
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Set-Location -Path ".."
    exit 1
}

if (Test-Path $outputPath) {
    $fileInfo = Get-Item $outputPath
    Write-Host "`n✅ Build successful!" -ForegroundColor Green
    Write-Host "📦 Output: $outputPath" -ForegroundColor Cyan
    Write-Host "📊 Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    
    # Copy to root directory for easy access
    $fileName = Split-Path $outputPath -Leaf
    Copy-Item $outputPath -Destination "..\$fileName" -Force
    Write-Host "📋 Also copied to: ..\$fileName" -ForegroundColor Cyan
} else {
    Write-Host "❌ Build output not found!" -ForegroundColor Red
    Set-Location -Path ".."
    exit 1
}

Set-Location -Path ".."


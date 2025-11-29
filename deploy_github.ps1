# Deploy Flutter Web App to GitHub Pages
# Usage: .\deploy_github.ps1 -BackendUrl "https://your-backend.azurewebsites.net" -GitHubRepoName "Nutrition"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackendUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepoName = "Nutrition"
)

Write-Host "Deploying Flutter Web App to GitHub Pages..." -ForegroundColor Green
Write-Host "Backend URL: $BackendUrl" -ForegroundColor Cyan
Write-Host "GitHub Repo Name: $GitHubRepoName" -ForegroundColor Cyan

# Navigate to Flutter app directory
Set-Location -Path "nutrition_flutter"

# Clean previous builds
Write-Host "`nCleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build web app with production API URL and GitHub Pages base-href
Write-Host "Building web app for GitHub Pages..." -ForegroundColor Yellow
$baseHref = "/$GitHubRepoName/"
flutter build web --dart-define=API_BASE_URL=$BackendUrl --release --base-href $baseHref

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    Set-Location -Path ".."
    exit 1
}

# Copy to docs folder (GitHub Pages can serve from /docs)
Write-Host "`nCopying build to docs/ folder..." -ForegroundColor Yellow

if (Test-Path "docs") {
    Remove-Item -Path "docs" -Recurse -Force
}

New-Item -ItemType Directory -Path "docs" | Out-Null
Copy-Item -Path "build\web\*" -Destination "docs\" -Recurse -Force

Write-Host "`nBuild copied to docs/ folder!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "   1. git add docs/" -ForegroundColor White
Write-Host "   2. git commit -m 'Deploy web app to GitHub Pages'" -ForegroundColor White
Write-Host "   3. git push origin main" -ForegroundColor White
Write-Host "   4. Go to GitHub repo -> Settings -> Pages" -ForegroundColor White
Write-Host "   5. Source: Deploy from a branch -> main -> /docs" -ForegroundColor White
Write-Host "   6. Save - Your app will be at: https://YOUR_USERNAME.github.io/$GitHubRepoName/" -ForegroundColor White

Set-Location -Path ".."

Write-Host "`nDone! Ready to commit and push." -ForegroundColor Green



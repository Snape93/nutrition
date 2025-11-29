# Deploy Flutter Web App
# Usage: .\deploy_web.ps1 -BackendUrl "https://your-backend.railway.app" -Platform "firebase"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackendUrl,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("firebase", "vercel", "netlify", "github")]
    [string]$Platform = "firebase",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepoName = "nutrition"
)

Write-Host "Deploying Flutter Web App..." -ForegroundColor Green
Write-Host "Backend URL: $BackendUrl" -ForegroundColor Cyan
Write-Host "Platform: $Platform" -ForegroundColor Cyan

# Navigate to Flutter app directory
Set-Location -Path "nutrition_flutter"

# Clean previous builds
Write-Host "`nCleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build web app with production API URL
Write-Host "Building web app..." -ForegroundColor Yellow
flutter build web --dart-define=API_BASE_URL=$BackendUrl --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    Set-Location -Path ".."
    exit 1
}

# Deploy based on platform
if ($Platform -eq "firebase") {
    Write-Host "Deploying to Firebase..." -ForegroundColor Yellow
    firebase deploy --only hosting
}
elseif ($Platform -eq "vercel") {
    Write-Host "Deploying to Vercel..." -ForegroundColor Yellow
    Set-Location -Path "build\web"
    vercel --prod
    Set-Location -Path "..\.."
}
elseif ($Platform -eq "netlify") {
    Write-Host "Deploying to Netlify..." -ForegroundColor Yellow
    Set-Location -Path "build\web"
    netlify deploy --prod
    Set-Location -Path "..\.."
}
elseif ($Platform -eq "github") {
    Write-Host "Preparing for GitHub Pages..." -ForegroundColor Yellow
    
    # Build with base-href for GitHub Pages
    Write-Host "Rebuilding with GitHub Pages base-href..." -ForegroundColor Yellow
    flutter build web --dart-define=API_BASE_URL=$BackendUrl --release --base-href "/$GitHubRepoName/"
    
    # Copy to docs folder (GitHub Pages can serve from /docs)
    if (Test-Path "docs") {
        Remove-Item -Path "docs" -Recurse -Force
    }
    New-Item -ItemType Directory -Path "docs" | Out-Null
    Copy-Item -Path "build\web\*" -Destination "docs\" -Recurse -Force
    
    Write-Host "`nBuild copied to docs/ folder!" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "   1. git add docs/" -ForegroundColor White
    Write-Host "   2. git commit -m 'Deploy web app to GitHub Pages'" -ForegroundColor White
    Write-Host "   3. git push origin main" -ForegroundColor White
    Write-Host "   4. Go to GitHub repo -> Settings -> Pages" -ForegroundColor White
    Write-Host "   5. Source: Deploy from a branch -> main -> /docs" -ForegroundColor White
    Write-Host "   6. Save - Your app will be at: https://YOUR_USERNAME.github.io/$GitHubRepoName/" -ForegroundColor White
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nDeployment successful!" -ForegroundColor Green
}
else {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    Set-Location -Path ".."
    exit 1
}

Set-Location -Path ".."

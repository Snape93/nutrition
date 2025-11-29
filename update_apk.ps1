# Update APK and create new GitHub release
# Usage: .\update_apk.ps1 -Version "1.0.1" -BuildNumber "2"

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$BuildNumber = "1",
    
    [Parameter(Mandatory=$false)]
    [string]$BackendUrl = "https://nutritionist-app-backend-dnbgf8bzf4h3hhhn.southeastasia-01.azurewebsites.net"
)

Write-Host "Updating APK to version $Version ($BuildNumber)..." -ForegroundColor Green

# Update version in pubspec.yaml
$pubspecPath = "nutrition_flutter\pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
$newVersion = "$Version+$BuildNumber"
$pubspecContent = $pubspecContent -replace "version: \d+\.\d+\.\d+\+\d+", "version: $newVersion"
Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline

Write-Host "Updated version to: $newVersion" -ForegroundColor Cyan

# Build new APK
Write-Host "`nBuilding new APK..." -ForegroundColor Yellow
.\build_android.ps1 -BackendUrl $BackendUrl -BuildType "apk"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nAPK build successful!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Go to: https://github.com/Snape93/nutrition/releases" -ForegroundColor White
    Write-Host "2. Click 'Create a new release'" -ForegroundColor White
    Write-Host "3. Tag: v$Version" -ForegroundColor White
    Write-Host "4. Title: Nutritionist App v$Version" -ForegroundColor White
    Write-Host "5. Upload: app-release.apk" -ForegroundColor White
    Write-Host "6. Publish release" -ForegroundColor White
}
else {
    Write-Host "`nBuild failed!" -ForegroundColor Red
}


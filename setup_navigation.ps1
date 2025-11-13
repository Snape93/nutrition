# PowerShell navigation helper functions
# Run this script once: . .\setup_navigation.ps1
# Or add these functions to your PowerShell profile

function Go-Flutter {
    <#
    .SYNOPSIS
    Navigate to the nutrition_flutter directory
    #>
    Set-Location "C:\Users\dlepo\Downloads\New folder\Nutrition\nutrition_flutter"
    Write-Host "Navigated to Flutter project" -ForegroundColor Green
}

function Go-Root {
    <#
    .SYNOPSIS
    Navigate to the project root directory
    #>
    Set-Location "C:\Users\dlepo\Downloads\New folder\Nutrition"
    Write-Host "Navigated to project root" -ForegroundColor Green
}

# Create aliases for convenience
Set-Alias -Name flutter -Value Go-Flutter -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name root -Value Go-Root -Scope Global -ErrorAction SilentlyContinue

Write-Host "Navigation helpers loaded!" -ForegroundColor Cyan
Write-Host "  Use 'Go-Flutter' or 'flutter' to navigate to nutrition_flutter" -ForegroundColor Yellow
Write-Host "  Use 'Go-Root' or 'root' to navigate to project root" -ForegroundColor Yellow



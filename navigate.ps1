# Helper script to navigate to common directories
# Usage: .\navigate.ps1 [flutter|root]

param(
    [Parameter(Position=0)]
    [ValidateSet("flutter", "root")]
    [string]$target = "root"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

switch ($target) {
    "flutter" {
        $targetPath = Join-Path $scriptDir "nutrition_flutter"
        if (Test-Path $targetPath) {
            Set-Location $targetPath
            Write-Host "Navigated to: $targetPath" -ForegroundColor Green
        } else {
            Write-Host "Error: Directory not found: $targetPath" -ForegroundColor Red
        }
    }
    "root" {
        Set-Location $scriptDir
        Write-Host "Navigated to: $scriptDir" -ForegroundColor Green
    }
}



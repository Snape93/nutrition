# PowerShell script to activate Python virtual environment
# This script bypasses execution policy restrictions

$ErrorActionPreference = "Stop"

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPath = Join-Path $scriptDir ".venv"

if (Test-Path $venvPath) {
    Write-Host "Activating virtual environment..." -ForegroundColor Green
    
    # Manually set environment variables (bypasses execution policy)
    $env:VIRTUAL_ENV = $venvPath
    $env:PATH = "$venvPath\Scripts;$env:PATH"
    
    # Remove PYTHONHOME if it exists
    if ($env:PYTHONHOME) {
        Remove-Item Env:\PYTHONHOME
    }
    
    # Update prompt
    function global:prompt {
        $prompt = "(.venv) PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
        return $prompt
    }
    
    Write-Host "Virtual environment activated!" -ForegroundColor Green
    Write-Host "Python path: $venvPath\Scripts\python.exe" -ForegroundColor Cyan
} else {
    Write-Host "Error: Virtual environment not found at $venvPath" -ForegroundColor Red
    exit 1
}



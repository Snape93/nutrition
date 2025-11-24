# Debug script to verify launcher icon updates
# This script checks icon file timestamps and sizes before/after generation

param(
    [switch]$GenerateIcons = $false
)

$ErrorActionPreference = "Stop"

Write-Host "`n🔍 Launcher Icon Debug Tool" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Navigate to Flutter app directory
$flutterDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $flutterDir

# Source icon file from pubspec.yaml
$sourceIcon = "design/logo.png"
$adaptiveForeground = "design/logo.png"

Write-Host "`n📋 Configuration Check:" -ForegroundColor Yellow
if (Test-Path "pubspec.yaml") {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match "image_path:\s*['""]([^'""]+)['""]") {
        $sourceIcon = $matches[1]
        Write-Host "  Source icon: $sourceIcon" -ForegroundColor White
    }
    if ($pubspec -match "adaptive_icon_foreground:\s*['""]([^'""]+)['""]") {
        $adaptiveForeground = $matches[1]
        Write-Host "  Adaptive foreground: $adaptiveForeground" -ForegroundColor White
    }
}

# Check source file
Write-Host "`n📁 Source Icon File:" -ForegroundColor Yellow
if (Test-Path $sourceIcon) {
    $sourceInfo = Get-Item $sourceIcon
    Write-Host "  ✅ File exists: $sourceIcon" -ForegroundColor Green
    Write-Host "  📏 Size: $([math]::Round($sourceInfo.Length / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "  🕐 Last Modified: $($sourceInfo.LastWriteTime)" -ForegroundColor White
    $sourceHash = (Get-FileHash $sourceIcon -Algorithm MD5).Hash
    Write-Host "  🔑 MD5: $sourceHash" -ForegroundColor Gray
} else {
    Write-Host "  ❌ Source file not found: $sourceIcon" -ForegroundColor Red
    exit 1
}

# Icon file locations to check
$iconLocations = @(
    @{Path="android\app\src\main\res\mipmap-mdpi\ic_launcher.png"; Name="Android MDPI"},
    @{Path="android\app\src\main\res\mipmap-hdpi\ic_launcher.png"; Name="Android HDPI"},
    @{Path="android\app\src\main\res\mipmap-xhdpi\ic_launcher.png"; Name="Android XHDPI"},
    @{Path="android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png"; Name="Android XXHDPI"},
    @{Path="android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"; Name="Android XXXHDPI"},
    @{Path="android\app\src\main\res\drawable-mdpi\ic_launcher_foreground.png"; Name="Adaptive MDPI"},
    @{Path="android\app\src\main\res\drawable-hdpi\ic_launcher_foreground.png"; Name="Adaptive HDPI"},
    @{Path="android\app\src\main\res\drawable-xhdpi\ic_launcher_foreground.png"; Name="Adaptive XHDPI"},
    @{Path="android\app\src\main\res\drawable-xxhdpi\ic_launcher_foreground.png"; Name="Adaptive XXHDPI"},
    @{Path="android\app\src\main\res\drawable-xxxhdpi\ic_launcher_foreground.png"; Name="Adaptive XXXHDPI"}
)

# Store before state
Write-Host "`n📊 Current Icon Files Status:" -ForegroundColor Yellow
$beforeState = @{}
foreach ($icon in $iconLocations) {
    if (Test-Path $icon.Path) {
        $fileInfo = Get-Item $icon.Path
        $beforeState[$icon.Path] = @{
            Exists = $true
            Size = $fileInfo.Length
            LastWrite = $fileInfo.LastWriteTime
            Hash = (Get-FileHash $icon.Path -Algorithm MD5).Hash
        }
        Write-Host "  ✅ $($icon.Name): $([math]::Round($fileInfo.Length / 1KB, 2)) KB - $($fileInfo.LastWriteTime)" -ForegroundColor Green
    } else {
        $beforeState[$icon.Path] = @{
            Exists = $false
            Size = 0
            LastWrite = $null
            Hash = $null
        }
        Write-Host "  ❌ $($icon.Name): NOT FOUND" -ForegroundColor Red
    }
}

# Generate icons if requested
if ($GenerateIcons) {
    Write-Host "`n🔄 Generating Icons..." -ForegroundColor Yellow
    Write-Host "  Running: flutter pub run flutter_launcher_icons" -ForegroundColor Gray
    
    $startTime = Get-Date
    flutter pub run flutter_launcher_icons
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Icon generation completed in $([math]::Round($duration, 2)) seconds" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Icon generation failed!" -ForegroundColor Red
        exit 1
    }
    
    # Wait a moment for file system to sync
    Start-Sleep -Seconds 1
    
    # Check after state
    Write-Host "`n📊 Icon Files Status After Generation:" -ForegroundColor Yellow
    $afterState = @{}
    $changesDetected = $false
    
    foreach ($icon in $iconLocations) {
        if (Test-Path $icon.Path) {
            $fileInfo = Get-Item $icon.Path
            $afterState[$icon.Path] = @{
                Exists = $true
                Size = $fileInfo.Length
                LastWrite = $fileInfo.LastWriteTime
                Hash = (Get-FileHash $icon.Path -Algorithm MD5).Hash
            }
            
            $before = $beforeState[$icon.Path]
            $after = $afterState[$icon.Path]
            
            if ($before.Exists) {
                if ($before.Hash -ne $after.Hash) {
                    Write-Host "  🔄 $($icon.Name): CHANGED" -ForegroundColor Cyan
                    Write-Host "     Size: $([math]::Round($before.Size / 1KB, 2)) KB → $([math]::Round($after.Size / 1KB, 2)) KB" -ForegroundColor Gray
                    Write-Host "     Time: $($before.LastWrite) → $($after.LastWrite)" -ForegroundColor Gray
                    $changesDetected = $true
                } else {
                    Write-Host "  ⏸️  $($icon.Name): UNCHANGED" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ✨ $($icon.Name): CREATED ($([math]::Round($fileInfo.Length / 1KB, 2)) KB)" -ForegroundColor Green
                $changesDetected = $true
            }
        } else {
            $afterState[$icon.Path] = @{
                Exists = $false
                Size = 0
                LastWrite = $null
                Hash = $null
            }
            Write-Host "  ❌ $($icon.Name): STILL MISSING" -ForegroundColor Red
        }
    }
    
    Write-Host "`n📈 Summary:" -ForegroundColor Yellow
    if ($changesDetected) {
        Write-Host "  ✅ Icons were updated successfully!" -ForegroundColor Green
        Write-Host "  💡 Next steps:" -ForegroundColor Cyan
        Write-Host "     1. Rebuild the app: flutter build apk" -ForegroundColor White
        Write-Host "     2. Uninstall old app from device" -ForegroundColor White
        Write-Host "     3. Install new build to see updated icon" -ForegroundColor White
    } else {
        Write-Host "  ⚠️  No changes detected - icons may already be up to date" -ForegroundColor Yellow
        Write-Host "  💡 Try modifying the source icon file and run again" -ForegroundColor Cyan
    }
} else {
    Write-Host "`n💡 To generate/update icons, run:" -ForegroundColor Cyan
    Write-Host "   .\debug_icon_update.ps1 -GenerateIcons" -ForegroundColor White
}

Write-Host "`n" -ForegroundColor White


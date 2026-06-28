# Start Firebase emulators and Flutter app with emulator flag (Windows PowerShell)
# Usage: .\scripts\emulators.ps1 [-Platform android|ios|web] [-Seed]
param(
    [string]$Platform = "android",
    [switch]$Seed
)

Write-Host "Firing up Firebase emulators..." -ForegroundColor Cyan
$emulatorJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data
}

Write-Host "Waiting for emulators to be ready (8s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 8

if ($Seed) {
    Write-Host "Seeding emulator with test data..." -ForegroundColor Magenta
    Push-Location functions
    npm run seed
    Pop-Location
    Write-Host "Seed complete." -ForegroundColor Green
}

Write-Host "Starting Flutter on $Platform with emulators enabled..." -ForegroundColor Green
flutter run `
    --dart-define=USE_EMULATORS=true `
    -d $Platform

Stop-Job $emulatorJob
Remove-Job $emulatorJob

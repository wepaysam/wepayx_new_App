# Run from mobile/ folder after Firebase login.
# This registers Android app com.nexwallet.nex_wallet automatically — no manual package entry in console.

$ErrorActionPreference = "Stop"

$flutterBin = "C:\Users\DELL\flutter\bin"
$pubBin = "$env:LOCALAPPDATA\Pub\Cache\bin"
$npmBin = "$env:USERPROFILE\.npm"
$env:Path = "$flutterBin;$pubBin;$npmBin;" + $env:Path

Write-Host "Step 1: Install FlutterFire CLI (if needed)..."
dart pub global activate flutterfire_cli

Write-Host ""
Write-Host "Step 2: Login to Firebase (browser opens if not logged in)..."
firebase login

Write-Host ""
Write-Host "Step 3: Configure Firebase for this Flutter project..."
Set-Location $PSScriptRoot\..
flutterfire configure --project=nex-wallet-c56eb --platforms=android --yes

Write-Host ""
Write-Host "Done. Files created:"
Write-Host "  - lib/firebase_options.dart"
Write-Host "  - android/app/google-services.json"
Write-Host ""
Write-Host "Next: flutter pub get && flutter run"

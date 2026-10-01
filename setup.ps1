# Math Jump - one-time project setup (run from PowerShell in this folder)
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error 'Flutter is not installed or not on PATH. See README.md (step 1).'
}

# Generate the missing Android platform files. Existing files (lib/, AndroidManifest.xml,
# strings.xml, tests) are kept because flutter create does not overwrite them.
flutter create --org com.mathjump --project-name math_jump --platforms android .

# Firebase Auth needs minSdk 23.
$gradle = 'android/app/build.gradle.kts'
if (-not (Test-Path $gradle)) { $gradle = 'android/app/build.gradle' }
$text = [IO.File]::ReadAllText((Resolve-Path $gradle))
$text = $text -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23'
$text = $text -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23'
[IO.File]::WriteAllText((Resolve-Path $gradle), $text)

flutter pub get
flutter test

Write-Host ''
Write-Host 'Done. Plug in an Android phone (USB debugging on) and run:  flutter run' -ForegroundColor Green
Write-Host 'To enable Facebook login + friends, follow README.md step 3.' -ForegroundColor Yellow

# Builds a signed release and publishes it on GitHub: makeover.apk (what the launcher's updater
# downloads) and firestick-makeover-windows.zip (what users download).
# Needs: tools\get-sdk.ps1 run once, JDK 17+, gh logged in, and the release key:
#   $env:MAKEOVER_KEYSTORE = 'C:\caminho\release.jks'; $env:MAKEOVER_KEYSTORE_PASS = '...'
# Bump versionCode and versionName in launcher\AndroidManifest.xml first.
param([switch]$NoPublish)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
if (-not $env:MAKEOVER_KEYSTORE -or -not (Test-Path $env:MAKEOVER_KEYSTORE)) { throw 'Defina MAKEOVER_KEYSTORE e MAKEOVER_KEYSTORE_PASS (chave de release).' }
$version = ([xml](Get-Content "$root\launcher\AndroidManifest.xml")).manifest.versionName
$tag = "v$version"

& "$PSScriptRoot\build.ps1"
$stage = "$root\dist\firestick-makeover"
Remove-Item $stage, "$root\dist\firestick-makeover-windows.zip" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $stage | Out-Null
Copy-Item "$root\Start-Here.bat", "$root\makeover.ps1", "$root\debloat.txt", "$root\README.md", "$root\README.en.md", `
    "$root\LICENSE", "$root\THIRD-PARTY-NOTICES.md", "$root\dist\makeover.apk" $stage
Compress-Archive "$stage\*" "$root\dist\firestick-makeover-windows.zip"
Remove-Item $stage -Recurse -Force
Write-Host "Pronto: $root\dist\firestick-makeover-windows.zip ($tag)"

if ($NoPublish) { return }
gh release create $tag "$root\dist\makeover.apk" "$root\dist\firestick-makeover-windows.zip" `
    --repo vitoradriao/firestick-makeover --title "Firestick Makeover $version" `
    --notes "Baixe **firestick-makeover-windows.zip**, extraia e rode **Start-Here.bat**. Instruções no README."

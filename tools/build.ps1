# Builds dist\makeover.apk from launcher\. Needs JDK 17+ and tools\get-sdk.ps1 run once.
# Signing: $env:MAKEOVER_KEYSTORE and $env:MAKEOVER_KEYSTORE_PASS for releases; otherwise a local
# development key (launcher\dev.jks) is created. Phones and sticks only update an app signed with
# the same key, so keep the release key safe and out of the repository.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
$src = "$root\launcher"
$out = "$root\dist\build"
$sdk = "$root\sdk"
$bt = (Get-ChildItem "$sdk\build-tools" -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Name } | Select-Object -Last 1).FullName
$jar = (Get-ChildItem "$sdk\platforms\*\android.jar" -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1).FullName
if (-not $bt -or -not $jar) { throw "Rode tools\get-sdk.ps1 primeiro." }
$javaHome = ((& java -XshowSettings:properties -version 2>&1 | Out-String) -split "`n" | Where-Object { $_ -match 'java\.home' }).Split('=')[1].Trim()
function Check($what) { if ($LASTEXITCODE) { throw "$what falhou" } }

Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory "$out\classes", "$out\dex" -Force | Out-Null
& "$bt\aapt2.exe" compile --dir "$src\res" -o "$out\res.zip"; Check aapt2
& "$bt\aapt2.exe" link -o "$out\unsigned.apk" -I $jar --manifest "$src\AndroidManifest.xml" -A "$src\assets" `
    --min-sdk-version 22 --target-sdk-version 34 "$out\res.zip"; Check aapt2
& javac -nowarn -Xlint:-options -encoding UTF-8 -source 1.8 -target 1.8 -bootclasspath "$jar;$bt\core-lambda-stubs.jar" `
    -d "$out\classes" (Get-ChildItem "$src\src" -Recurse -Filter *.java).FullName; Check javac
& "$bt\d8.bat" --min-api 22 --release --lib $jar --output "$out\dex" (Get-ChildItem "$out\classes" -Recurse -Filter *.class).FullName; Check d8

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open("$out\unsigned.apk", 'Update')
try {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$out\dex\classes.dex", 'classes.dex') | Out-Null
    # aapt2 on Windows stores assets as "assets/fonts\x.ttf", which Android can't find.
    foreach ($e in @($zip.Entries | Where-Object { $_.FullName.Contains('\') })) {
        $fixed = $zip.CreateEntry($e.FullName.Replace('\', '/'))
        $in = $e.Open(); $o = $fixed.Open()
        try { $in.CopyTo($o) } finally { $in.Dispose(); $o.Dispose() }
        $e.Delete()
    }
} finally { $zip.Dispose() }
& "$bt\zipalign.exe" -f 4 "$out\unsigned.apk" "$out\aligned.apk"; Check zipalign

$ks = $env:MAKEOVER_KEYSTORE; $pass = $env:MAKEOVER_KEYSTORE_PASS
if (-not $ks) {
    $ks = "$src\dev.jks"; $pass = 'makeover-dev'
    if (-not (Test-Path $ks)) {
        & "$javaHome\bin\keytool.exe" -genkeypair -keystore $ks -storepass $pass -keypass $pass -alias makeover `
            -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Makeover dev" 2>&1 | Out-Null; Check keytool
    }
    Write-Host "Assinando com a chave de desenvolvimento ($ks)."
}
& "$bt\apksigner.bat" sign --ks $ks --ks-pass "pass:$pass" --out "$root\dist\makeover.apk" "$out\aligned.apk"; Check apksigner
Remove-Item $out -Recurse -Force
Write-Host "Pronto: $root\dist\makeover.apk"

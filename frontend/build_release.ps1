$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$outputDirectory = Join-Path $projectRoot 'build\app\outputs\flutter-apk'
$flutterApk = Join-Path $outputDirectory 'app-release.apk'

$originalPubspec = [System.IO.File]::ReadAllText($pubspecPath)
$versionPattern = '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$'
$match = [regex]::Match($originalPubspec, $versionPattern)

if (-not $match.Success) {
    throw 'Could not find a version such as 1.1.0+2 in pubspec.yaml.'
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value + 1
$buildCode = [int]$match.Groups[4].Value + 1
$versionName = "$major.$minor.$patch"
$newVersionLine = "version: $versionName+$buildCode"
$updatedPubspec = [regex]::Replace(
    $originalPubspec,
    $versionPattern,
    $newVersionLine,
    1
)

$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec, $utf8WithoutBom)

Push-Location $projectRoot
try {
    Write-Host "Building Stella Plant Care v$versionName..." -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }

    if (-not (Test-Path -LiteralPath $flutterApk)) {
        throw "Flutter reported success but $flutterApk was not found."
    }

    $namedApk = Join-Path $outputDirectory "Stella-Plant-Care-v$versionName.apk"
    Copy-Item -LiteralPath $flutterApk -Destination $namedApk -Force

    Write-Host "`nBuild complete:" -ForegroundColor Green
    Write-Host $namedApk
    Write-Host "Version: $versionName (internal Android code: $buildCode)"
}
catch {
    # A failed build should not consume a version number.
    [System.IO.File]::WriteAllText(
        $pubspecPath,
        $originalPubspec,
        $utf8WithoutBom
    )
    throw
}
finally {
    Pop-Location
}

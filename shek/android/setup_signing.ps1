$ErrorActionPreference = "Stop"

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if ($null -eq $keytool) {
    throw "keytool is not available. Install Android Studio or a JDK, then run this script again."
}

$androidDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$keystorePath = Join-Path $androidDirectory "app\upload-keystore.jks"
$propertiesPath = Join-Path $androidDirectory "key.properties"

if ((Test-Path $keystorePath) -or (Test-Path $propertiesPath)) {
    throw "Signing files already exist. Back them up and remove them manually only if you intend to replace the signing key."
}

$randomBytes = New-Object byte[] 32
$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $random.GetBytes($randomBytes)
}
finally {
    $random.Dispose()
}
$password = [Convert]::ToBase64String($randomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

& $keytool.Source `
    -genkeypair `
    -keystore $keystorePath `
    -storetype JKS `
    -storepass $password `
    -keypass $password `
    -alias upload `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -dname "CN=Shek"

if ($LASTEXITCODE -ne 0) {
    if (Test-Path $keystorePath) {
        Remove-Item -LiteralPath $keystorePath
    }
    throw "keytool could not create the Android signing key."
}

$properties = @(
    "storePassword=$password"
    "keyPassword=$password"
    "keyAlias=upload"
    "storeFile=app/upload-keystore.jks"
)
Set-Content -LiteralPath $propertiesPath -Value $properties -Encoding ASCII

Write-Output "Created Android release signing files:"
Write-Output "  $keystorePath"
Write-Output "  $propertiesPath"
Write-Output "Back up both files securely. Do not commit or share them."

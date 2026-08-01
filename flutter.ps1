$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
$env:PUB_CACHE = (Join-Path $PSScriptRoot ".pub-cache")

# 本机地址必须绕开代理：flutter test 靠本地 WebSocket 连 flutter_tester，
# 若 HTTP(S)_PROXY 已设而 NO_PROXY 未含 localhost，这条连接会被送进代理，
# 报 "Invalid WebSocket upgrade request" 导致所有测试无法加载。
$localBypass = "localhost,127.0.0.1,::1"
$env:NO_PROXY = if ($env:NO_PROXY) { "$localBypass,$($env:NO_PROXY)" } else { $localBypass }

# 国内镜像 + Flutter SDK 路径
$FlutterSdk = "D:\flutter_windows_3.44.8-stable\flutter"
if (-not $env:FLUTTER_ROOT) { $env:FLUTTER_ROOT = $FlutterSdk }

if ($env:FLUTTER_ROOT) {
    $flutterFromRoot = Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
    if (Test-Path $flutterFromRoot) {
        & $flutterFromRoot @args
        exit $LASTEXITCODE
    }
}

$self = (Resolve-Path $PSCommandPath).Path
$flutter = Get-Command flutter.bat -All -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -ne $self } |
    Select-Object -First 1

if (-not $flutter) {
    Write-Error "Flutter SDK not found. Add Flutter's bin directory to PATH or set FLUTTER_ROOT."
    exit 1
}

& $flutter.Source @args
exit $LASTEXITCODE

# AI 量化 Flutter 客户端 · 生产构建脚本
# 用法(在 flutter_app 目录):
#   .\build_release.ps1 -ApiBaseUrl "https://api.example.com/api/v1"
# 产物: build\web(交由 Nginx 托管,见 deploy\nginx.conf)
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl
)

$ErrorActionPreference = "Stop"

Write-Host "==> API_BASE_URL = $ApiBaseUrl"

flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# API 地址通过 --dart-define 注入(ApiClient.baseUrl 读取 API_BASE_URL)
flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = Join-Path (Get-Location) "build\web"
Write-Host ""
Write-Host "==> 构建完成: $out"
Write-Host "==> 部署: 将 build\web 内容上传服务器 /opt/ai-quant/flutter-web(Nginx 托管,见 deploy/nginx.conf)"

#Requires -Version 5.1
<#
.SYNOPSIS
    TB System - ネットワーク検証スクリプト

.DESCRIPTION
    展示会場でのネットワーク疎通を確認するための検証ツール
    専門知識がなくても簡単にネットワーク状態を確認できます

.NOTES
    Author: TB Project Team
    Version: 1.0.0
#>

# スクリプトのディレクトリを取得
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configRoot = Split-Path -Parent $scriptDir
$projectRoot = Split-Path -Parent $configRoot

# 検証結果を保存する配列
$script:testResults = @()
$script:totalTests = 0
$script:passedTests = 0
$script:failedTests = 0

# カラー出力用の関数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" "Yellow"
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "ℹ $Message" "Cyan"
}

# ヘッダー表示
function Show-Header {
    Clear-Host
    Write-ColorOutput "================================================" "Cyan"
    Write-ColorOutput "  TB System - ネットワーク検証ツール" "Cyan"
    Write-ColorOutput "================================================" "Cyan"
    Write-Host ""
}

# テスト結果を記録
function Record-Test {
    param(
        [string]$TestName,
        [string]$Result,
        [string]$Message
    )

    $script:totalTests++

    if ($Result -eq "PASS") {
        $script:passedTests++
        Write-Success "$TestName`: $Message"
        $script:testResults += "✓ $TestName`: $Message"
    } else {
        $script:failedTests++
        Write-Error "$TestName`: $Message"
        $script:testResults += "✗ $TestName`: $Message"
    }
}

# 現在の環境を取得
function Get-CurrentEnvironment {
    $envFiles = @(
        (Join-Path $projectRoot "tb-acq-backend\.env"),
        (Join-Path $projectRoot "tb-acq-app\.env.local")
    )

    $currentEnv = ""
    foreach ($envFile in $envFiles) {
        if (Test-Path $envFile) {
            $content = Get-Content $envFile -Raw
            if ($content -match 'ENV_NAME\s*=\s*([^\s\r\n]+)') {
                $currentEnv = $matches[1]
                break
            }
        }
    }

    if ([string]::IsNullOrEmpty($currentEnv)) {
        $currentEnv = "development"
    }

    return $currentEnv
}

# TCP接続テスト
function Test-TcpConnection {
    param(
        [string]$Host,
        [int]$Port,
        [int]$Timeout = 3000
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connection = $tcpClient.BeginConnect($Host, $Port, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne($Timeout, $false)

        if ($wait) {
            try {
                $tcpClient.EndConnect($connection)
                $tcpClient.Close()
                return $true
            } catch {
                return $false
            }
        } else {
            return $false
        }
    } catch {
        return $false
    } finally {
        if ($tcpClient) {
            $tcpClient.Close()
        }
    }
}

# HTTP エンドポイントテスト
function Test-HttpEndpoint {
    param(
        [string]$Url,
        [int]$Timeout = 5
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $Timeout -UseBasicParsing -ErrorAction Stop
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

# MQTT ブローカーテスト
function Test-MqttBroker {
    param(
        [string]$Host,
        [int]$Port
    )

    Write-Host ""
    Write-Info "MQTT ブローカー接続テスト: $Host`:$Port"

    if (Test-TcpConnection -Host $Host -Port $Port) {
        Record-Test "MQTT Broker" "PASS" "$Host`:$Port に接続成功"
    } else {
        Record-Test "MQTT Broker" "FAIL" "$Host`:$Port に接続できません"
    }
}

# InfluxDB テスト
function Test-InfluxDB {
    param([string]$Url)

    Write-Host ""
    Write-Info "InfluxDB 接続テスト: $Url"

    $pingUrl = "$Url/ping"

    if (Test-HttpEndpoint -Url $pingUrl) {
        Record-Test "InfluxDB" "PASS" "$Url に接続成功"
    } else {
        Record-Test "InfluxDB" "FAIL" "$Url に接続できません"
    }
}

# Grafana テスト
function Test-Grafana {
    param([string]$Url)

    Write-Host ""
    Write-Info "Grafana 接続テスト: $Url"

    $healthUrl = "$Url/api/health"

    if (Test-HttpEndpoint -Url $healthUrl) {
        Record-Test "Grafana" "PASS" "$Url に接続成功"
    } else {
        Record-Test "Grafana" "FAIL" "$Url に接続できません"
    }
}

# バックエンドAPI テスト
function Test-BackendApi {
    param([string]$Url)

    Write-Host ""
    Write-Info "バックエンドAPI 接続テスト: $Url"

    $healthUrl = "$Url/api/health"

    if (Test-HttpEndpoint -Url $healthUrl) {
        Record-Test "Backend API" "PASS" "$Url に接続成功"
    } else {
        Record-Test "Backend API" "FAIL" "$Url に接続できません"
    }
}

# フロントエンド テスト
function Test-Frontend {
    param([string]$Url)

    Write-Host ""
    Write-Info "フロントエンド 接続テスト: $Url"

    if (Test-HttpEndpoint -Url $Url) {
        Record-Test "Frontend" "PASS" "$Url に接続成功"
    } else {
        Record-Test "Frontend" "FAIL" "$Url に接続できません"
    }
}

# 環境設定ファイルテスト
function Test-ConfigFiles {
    Write-Host ""
    Write-Info "環境設定ファイルの確認"

    $files = @(
        (Join-Path $projectRoot "tb-acq-backend\.env"),
        (Join-Path $projectRoot "tb-acq-app\.env.local"),
        (Join-Path $projectRoot "tb-data-pipeline\.env")
    )

    foreach ($file in $files) {
        $dirName = Split-Path (Split-Path $file -Parent) -Leaf
        $fileName = Split-Path $file -Leaf

        if (Test-Path $file) {
            Record-Test "Config File" "PASS" "$dirName\$fileName が存在します"
        } else {
            Record-Test "Config File" "FAIL" "$dirName\$fileName が見つかりません"
        }
    }
}

# デバイス設定ファイルテスト
function Test-DeviceConfig {
    Write-Host ""
    Write-Info "デバイス設定ファイルの確認"

    $devicesFile = Join-Path $configRoot "devices\allowed-devices.json"

    if (Test-Path $devicesFile) {
        try {
            $config = Get-Content $devicesFile -Raw | ConvertFrom-Json
            $deviceCount = $config.allowed_macs.Count
            Record-Test "Device Config" "PASS" "$deviceCount 台のデバイスが登録されています"
        } catch {
            Record-Test "Device Config" "PASS" "ファイルが存在します"
        }
    } else {
        Record-Test "Device Config" "FAIL" "デバイス設定ファイルが見つかりません"
    }
}

# レポート生成
function New-Report {
    param([string]$EnvName)

    $reportDir = Join-Path $projectRoot "reports"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFile = Join-Path $reportDir "network_verify_${EnvName}_$timestamp.txt"

    $reportContent = @"
================================================
  TB System - ネットワーク検証レポート
================================================

環境: $EnvName
実行日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

================================================
  テスト結果サマリー
================================================

総テスト数: $($script:totalTests)
成功: $($script:passedTests)
失敗: $($script:failedTests)

================================================
  詳細結果
================================================

$($script:testResults -join "`n")

"@

    Set-Content -Path $reportFile -Value $reportContent -Encoding UTF8

    Write-Success "レポートを保存しました: $reportFile"
}

# メイン処理
function Main {
    Show-Header

    # 現在の環境を取得
    $envName = Get-CurrentEnvironment
    Write-Info "現在の環境: $envName"
    Write-Host ""

    # 環境設定を読み込み
    $configFile = Join-Path $configRoot "environments\$envName.json"

    if (-not (Test-Path $configFile)) {
        Write-Error "環境設定ファイルが見つかりません: $configFile"
        return
    }

    $config = Get-Content $configFile -Raw | ConvertFrom-Json

    # 各種URLとポートを抽出
    $mqttUrl = $config.mqtt.broker_url
    $mqttHost = if ($mqttUrl -match 'mqtt://([^:]+):') { $matches[1] } else { "localhost" }
    $mqttPort = if ($mqttUrl -match ':(\d+)') { [int]$matches[1] } else { 1883 }

    $influxUrl = $config.influxdb.url
    $grafanaUrl = $config.grafana.url
    $backendUrl = $config.backend.url

    # フロントエンドURL
    $frontendUrl = "http://localhost:5173"

    # 各種テストを実行
    Test-ConfigFiles
    Test-DeviceConfig
    Test-MqttBroker -Host $mqttHost -Port $mqttPort
    Test-InfluxDB -Url $influxUrl
    Test-Grafana -Url $grafanaUrl
    Test-BackendApi -Url $backendUrl
    Test-Frontend -Url $frontendUrl

    # 結果サマリー
    Write-Host ""
    Write-ColorOutput "================================================" "Cyan"
    Write-ColorOutput "  テスト結果サマリー" "Cyan"
    Write-ColorOutput "================================================" "Cyan"
    Write-Host ""
    Write-Host "  環境: $envName"
    Write-Host "  総テスト数: $($script:totalTests)"
    Write-ColorOutput "  成功: $($script:passedTests)" "Green"
    Write-ColorOutput "  失敗: $($script:failedTests)" "Red"
    Write-Host ""

    # レポート生成
    New-Report -EnvName $envName

    Write-Host ""
    if ($script:failedTests -eq 0) {
        Write-ColorOutput "================================================" "Green"
        Write-ColorOutput "  すべてのテストに合格しました！" "Green"
        Write-ColorOutput "================================================" "Green"
        Write-Host ""
        Write-Success "ネットワーク環境は正常です"
    } else {
        Write-ColorOutput "================================================" "Red"
        Write-ColorOutput "  一部のテストが失敗しました" "Red"
        Write-ColorOutput "================================================" "Red"
        Write-Host ""
        Write-Warning "以下を確認してください:"
        Write-Host "  1. Docker コンテナが起動しているか"
        Write-Host "     docker compose ps"
        Write-Host ""
        Write-Host "  2. ファイアウォール設定が正しいか"
        Write-Host ""
        Write-Host "  3. 各サービスのログを確認"
        Write-Host "     docker compose logs -f"
        Write-Host ""
    }
}

# スクリプト実行
Main

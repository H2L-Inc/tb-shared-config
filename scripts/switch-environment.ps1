#Requires -Version 5.1
<#
.SYNOPSIS
    TB System - 環境切り替えスクリプト

.DESCRIPTION
    開発環境(development)と展示環境(exhibition)を切り替えるための対話型スクリプト
    専門知識がなくても安全に環境を切り替えられます

.NOTES
    Author: TB Project Team
    Version: 1.0.0
#>

param(
    [switch]$Silent = $false  # サイレントモード（テスト用）
)

# スクリプトのディレクトリを取得
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configRoot = Split-Path -Parent $scriptDir

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
    Write-ColorOutput "  TB System - 環境切り替えツール" "Cyan"
    Write-ColorOutput "================================================" "Cyan"
    Write-Host ""
}

# 利用可能な環境を取得
function Get-AvailableEnvironments {
    $envDir = Join-Path $configRoot "environments"
    $envFiles = Get-ChildItem -Path $envDir -Filter "*.json" -File

    $environments = @()
    foreach ($file in $envFiles) {
        $envName = $file.BaseName
        $environments += @{
            Name = $envName
            Path = $file.FullName
            DisplayName = switch ($envName) {
                "development" { "開発環境" }
                "production" { "本番環境" }
                "local" { "ローカル環境" }
                default { $envName }
            }
        }
    }

    return $environments
}

# 現在の環境を取得
function Get-CurrentEnvironment {
    $projectRoot = Split-Path -Parent $configRoot

    # .env ファイルをチェック
    $envFiles = @(
        (Join-Path $projectRoot "tb-acq-backend\.env"),
        (Join-Path $projectRoot "tb-data-pipeline\.env")
    )

    # tb-acq-appのVite .env.{mode}ファイルも追加
    $appEnvPath = Join-Path $projectRoot "tb-acq-app"
    if (Test-Path $appEnvPath) {
        Get-ChildItem -Path $appEnvPath -Filter ".env.*" -File | ForEach-Object {
            if ($_.Name -notmatch '\.example$' -and $_.Name -notmatch '\.local$') {
                $envFiles += $_.FullName
            }
        }
    }

    $currentEnv = $null
    foreach ($envFile in $envFiles) {
        if (Test-Path $envFile) {
            $content = Get-Content $envFile -Raw
            # ENV_NAMEまたはVITE_ENV_NAMEをチェック
            if ($content -match '(VITE_)?ENV_NAME\s*=\s*([^\s\r\n]+)') {
                $currentEnv = $matches[2]
                break
            }
        }
    }

    if (-not $currentEnv) {
        $currentEnv = "development"  # デフォルト
    }

    return $currentEnv
}

# 環境設定を読み込み
function Read-EnvironmentConfig {
    param([string]$EnvName)

    $configPath = Join-Path $configRoot "environments\$EnvName.json"

    if (-not (Test-Path $configPath)) {
        Write-Error "設定ファイルが見つかりません: $configPath"
        return $null
    }

    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-Error "設定ファイルの読み込みに失敗しました: $_"
        return $null
    }
}

# .envファイルを更新
function Update-EnvFile {
    param(
        [string]$FilePath,
        [string]$EnvName,
        [hashtable]$Variables
    )

    $content = ""

    # 既存のファイルがあれば読み込み
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw
    }

    # ENV_NAMEを更新または追加
    if ($content -match 'ENV_NAME\s*=') {
        $content = $content -replace 'ENV_NAME\s*=\s*[^\r\n]*', "ENV_NAME=$EnvName"
    } else {
        $content = "ENV_NAME=$EnvName`n$content"
    }

    # その他の変数を更新
    foreach ($key in $Variables.Keys) {
        $value = $Variables[$key]
        if ($content -match "$key\s*=") {
            $content = $content -replace "$key\s*=\s*[^\r\n]*", "$key=$value"
        } else {
            $content += "`n$key=$value"
        }
    }

    # ファイルに書き込み
    Set-Content -Path $FilePath -Value $content -NoNewline -Encoding UTF8
}

# 環境を切り替え
function Switch-Environment {
    param([string]$TargetEnv)

    Write-Info "環境を切り替えています: $TargetEnv"
    Write-Host ""

    # 設定を読み込み
    $config = Read-EnvironmentConfig -EnvName $TargetEnv
    if (-not $config) {
        return $false
    }

    $projectRoot = Split-Path -Parent $configRoot

    # バックエンドの.envを更新（テンプレートからコピー）
    $backendTemplate = Join-Path $projectRoot "tb-acq-backend\.env.$TargetEnv"
    $backendEnv = Join-Path $projectRoot "tb-acq-backend\.env"
    Write-Info "更新中: tb-acq-backend\.env"
    if (Test-Path $backendTemplate) {
        $backendDir = Split-Path -Parent $backendEnv
        if (-not (Test-Path $backendDir)) {
            New-Item -ItemType Directory -Path $backendDir -Force | Out-Null
        }
        Copy-Item -Path $backendTemplate -Destination $backendEnv -Force
        if (Test-Path $backendEnv) {
            Write-Success "完了: tb-acq-backend\.env (← .env.$TargetEnv)"
        } else {
            Write-Error "ファイルの作成に失敗しました: $backendEnv"
            return $false
        }
    } else {
        Write-Error "テンプレートが見つかりません: $backendTemplate"
        return $false
    }

    # フロントエンドの.envを更新（テンプレートからコピー）
    $frontendTemplate = Join-Path $projectRoot "tb-acq-app\.env.$TargetEnv"
    $frontendEnv = Join-Path $projectRoot "tb-acq-app\.env"
    Write-Info "更新中: tb-acq-app\.env"
    if (Test-Path $frontendTemplate) {
        $frontendDir = Split-Path -Parent $frontendEnv
        if (-not (Test-Path $frontendDir)) {
            New-Item -ItemType Directory -Path $frontendDir -Force | Out-Null
        }
        Copy-Item -Path $frontendTemplate -Destination $frontendEnv -Force
        if (Test-Path $frontendEnv) {
            Write-Success "完了: tb-acq-app\.env (← .env.$TargetEnv)"
        } else {
            Write-Error "ファイルの作成に失敗しました: $frontendEnv"
            return $false
        }
    } else {
        Write-Error "テンプレートが見つかりません: $frontendTemplate"
        return $false
    }

    # データパイプラインの.envを更新（テンプレートからコピー）
    $pipelineTemplate = Join-Path $projectRoot "tb-data-pipeline\.env.$TargetEnv"
    $pipelineEnv = Join-Path $projectRoot "tb-data-pipeline\.env"
    Write-Info "更新中: tb-data-pipeline\.env"
    if (Test-Path $pipelineTemplate) {
        $pipelineDir = Split-Path -Parent $pipelineEnv
        if (-not (Test-Path $pipelineDir)) {
            New-Item -ItemType Directory -Path $pipelineDir -Force | Out-Null
        }
        Copy-Item -Path $pipelineTemplate -Destination $pipelineEnv -Force
        if (Test-Path $pipelineEnv) {
            Write-Success "完了: tb-data-pipeline\.env (← .env.$TargetEnv)"
        } else {
            Write-Error "ファイルの作成に失敗しました: $pipelineEnv"
            return $false
        }
    } else {
        Write-Error "テンプレートが見つかりません: $pipelineTemplate"
        return $false
    }

    Write-Host ""
    Write-Success "環境の切り替えが完了しました: $TargetEnv"

    return $true
}

# メイン処理
function Main {
    Show-Header

    # 現在の環境を取得
    $currentEnv = Get-CurrentEnvironment
    Write-Info "現在の環境: $currentEnv"
    Write-Host ""

    # 利用可能な環境を取得
    $environments = Get-AvailableEnvironments

    if ($environments.Count -eq 0) {
        Write-Error "利用可能な環境設定が見つかりません"
        Write-Info "tb-shared-config/environments/ ディレクトリを確認してください"
        return
    }

    # 環境を選択
    Write-ColorOutput "利用可能な環境:" "Yellow"
    for ($i = 0; $i -lt $environments.Count; $i++) {
        $env = $environments[$i]
        $marker = if ($env.Name -eq $currentEnv) { " [現在]" } else { "" }
        Write-Host "  [$($i + 1)] $($env.DisplayName) ($($env.Name))$marker"
    }
    Write-Host ""

    if (-not $Silent) {
        $selection = Read-Host "切り替える環境の番号を入力してください (終了: q)"

        if ($selection -eq "q" -or $selection -eq "Q") {
            Write-Info "キャンセルしました"
            return
        }

        try {
            $index = [int]$selection - 1
            if ($index -lt 0 -or $index -ge $environments.Count) {
                Write-Error "無効な選択です"
                return
            }
        } catch {
            Write-Error "無効な入力です"
            return
        }

        $targetEnv = $environments[$index]

        # 現在と同じ環境の場合は確認
        if ($targetEnv.Name -eq $currentEnv) {
            Write-Warning "既に $($targetEnv.DisplayName) です"
            $confirm = Read-Host "それでも再適用しますか？ (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                Write-Info "キャンセルしました"
                return
            }
        } else {
            # 切り替え確認
            Write-Host ""
            Write-Warning "以下の環境に切り替えます:"
            Write-Host "  現在: $currentEnv"
            Write-Host "  切替先: $($targetEnv.Name)"
            Write-Host ""

            $confirm = Read-Host "よろしいですか？ (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                Write-Info "キャンセルしました"
                return
            }
        }
    } else {
        # サイレントモードでは最初の環境を選択（テスト用）
        $targetEnv = $environments[0]
    }

    Write-Host ""

    # 環境を切り替え
    $success = Switch-Environment -TargetEnv $targetEnv.Name

    if ($success) {
        Write-Host ""
        Write-ColorOutput "================================================" "Green"
        Write-ColorOutput "  次のステップ" "Green"
        Write-ColorOutput "================================================" "Green"
        Write-Host ""
        Write-Info "以下のサービスを再起動してください:"
        Write-Host "  1. Docker コンテナ:"
        Write-Host "     cd /path/to/tb"
        Write-Host "     docker compose restart"
        Write-Host ""
        Write-Host "  2. フロントエンド開発サーバー（起動中の場合）:"
        Write-Host "     Ctrl+C で停止 → npm run dev で再起動"
        Write-Host ""
        Write-Host "  3. バックエンドサーバー（起動中の場合）:"
        Write-Host "     Ctrl+C で停止 → npm run dev で再起動"
        Write-Host ""
    } else {
        Write-Error "環境の切り替えに失敗しました"
    }
}

# スクリプト実行
Main

#Requires -Version 5.1
<#
.SYNOPSIS
    TB System - デバイス追加スクリプト

.DESCRIPTION
    新しいFirstVRデバイスをシステムに追加するための対話型スクリプト
    専門知識がなくても安全にデバイスを追加できます

.NOTES
    Author: TB Project Team
    Version: 1.0.0
#>

# スクリプトのディレクトリを取得
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configRoot = Split-Path -Parent $scriptDir
$devicesFile = Join-Path $configRoot "devices\allowed-devices.json"
$backupDir = Join-Path $configRoot "backups"

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
    Write-ColorOutput "  TB System - デバイス追加ツール" "Cyan"
    Write-ColorOutput "================================================" "Cyan"
    Write-Host ""
}

# MAC アドレスを正規化
function ConvertTo-NormalizedMac {
    param([string]$Mac)
    return $Mac -replace '[:-]', '' | ForEach-Object { $_.ToUpper() }
}

# MAC アドレスの形式を検証
function Test-MacAddress {
    param([string]$Mac)

    $normalized = ConvertTo-NormalizedMac -Mac $Mac

    # 12桁の16進数かチェック
    if ($normalized -notmatch '^[0-9A-F]{12}$') {
        return $false
    }

    return $true
}

# 現在のデバイスリストを表示
function Show-CurrentDevices {
    if (-not (Test-Path $devicesFile)) {
        Write-Warning "デバイスファイルが見つかりません: $devicesFile"
        return
    }

    $config = Get-Content $devicesFile -Raw | ConvertFrom-Json

    $count = $config.allowed_macs.Count

    Write-ColorOutput "現在登録されているデバイス ($count 台):" "Yellow"
    Write-Host ""

    foreach ($mac in $config.allowed_macs) {
        $alias = $config.aliases.$mac
        Write-Host "  MAC: $mac"
        if ($alias) {
            Write-Host "  ニックネーム: $($alias.nickname)"
            if ($alias.description) {
                Write-Host "  説明: $($alias.description)"
            }
            if ($alias.location) {
                Write-Host "  設置場所: $($alias.location)"
            }
        } else {
            Write-Host "  ニックネーム: (未設定)"
        }
        Write-Host ""
    }
}

# バックアップを作成
function New-DeviceBackup {
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $backupDir "allowed-devices_$timestamp.json"

    Copy-Item $devicesFile $backupFile
    Write-Success "バックアップを作成しました: $backupFile"
}

# デバイスを追加
function Add-Device {
    param(
        [string]$Mac,
        [string]$Nickname,
        [string]$Description,
        [string]$Location
    )

    # 現在のデバイスリストを読み込み
    $config = Get-Content $devicesFile -Raw | ConvertFrom-Json

    # デバイスが既に存在するかチェック
    if ($config.allowed_macs -contains $Mac) {
        Write-Error "このMAC アドレスは既に登録されています: $Mac"
        return $false
    }

    # バックアップを作成
    New-DeviceBackup

    # MAC アドレスを追加
    $config.allowed_macs += $Mac

    # エイリアス情報を追加
    $aliasInfo = @{
        nickname = $Nickname
    }

    if ($Description) {
        $aliasInfo.description = $Description
    }

    if ($Location) {
        $aliasInfo.location = $Location
    }

    # PowerShellのハッシュテーブルをPSCustomObjectに変換
    if (-not $config.aliases) {
        $config.aliases = New-Object PSObject
    }

    $config.aliases | Add-Member -MemberType NoteProperty -Name $Mac -Value ([PSCustomObject]$aliasInfo) -Force

    # ファイルに保存
    $config | ConvertTo-Json -Depth 10 | Set-Content $devicesFile -Encoding UTF8

    Write-Success "デバイスを追加しました: $Mac ($Nickname)"
    return $true
}

# メイン処理
function Main {
    Show-Header

    # デバイスファイルの確認
    if (-not (Test-Path $devicesFile)) {
        Write-Error "デバイスファイルが見つかりません: $devicesFile"
        return
    }

    # 現在のデバイスを表示
    Show-CurrentDevices

    Write-ColorOutput "新しいデバイスを追加します" "Cyan"
    Write-Host ""

    # MAC アドレス入力
    $mac = ""
    while ($true) {
        Write-ColorOutput "MAC アドレスを入力してください" "Yellow"
        Write-Host "  形式: AABBCCDDEEFF または AA:BB:CC:DD:EE:FF"
        Write-Host "  終了: q"
        Write-Host ""
        $macInput = Read-Host "MAC アドレス"

        if ($macInput -eq "q" -or $macInput -eq "Q") {
            Write-Info "キャンセルしました"
            return
        }

        if (Test-MacAddress -Mac $macInput) {
            $mac = ConvertTo-NormalizedMac -Mac $macInput
            Write-Success "MAC アドレス: $mac"
            Write-Host ""
            break
        } else {
            Write-Error "無効なMAC アドレスです。12桁の16進数で入力してください"
            Write-Host ""
        }
    }

    # ニックネーム入力
    $nickname = ""
    while ($true) {
        Write-ColorOutput "デバイスのニックネームを入力してください" "Yellow"
        Write-Host "  例: FVR-48D8, デモ機1, 展示用FirstVR"
        Write-Host ""
        $nickname = Read-Host "ニックネーム"

        if ([string]::IsNullOrWhiteSpace($nickname)) {
            Write-Error "ニックネームは必須です"
            Write-Host ""
        } elseif ($nickname.Length -gt 20) {
            Write-Error "ニックネームは20文字以内にしてください"
            Write-Host ""
        } else {
            Write-Success "ニックネーム: $nickname"
            Write-Host ""
            break
        }
    }

    # 説明入力（オプション）
    Write-ColorOutput "デバイスの説明を入力してください（省略可）" "Yellow"
    Write-Host "  例: 開発用テストデバイス, 展示会用デバイス"
    Write-Host ""
    $description = Read-Host "説明"
    if ($description) {
        Write-Success "説明: $description"
    }
    Write-Host ""

    # 設置場所入力（オプション）
    Write-ColorOutput "設置場所を入力してください（省略可）" "Yellow"
    Write-Host "  例: ラボA, 展示ホール, 開発室"
    Write-Host ""
    $location = Read-Host "設置場所"
    if ($location) {
        Write-Success "設置場所: $location"
    }
    Write-Host ""

    # 確認
    Write-ColorOutput "================================================" "Cyan"
    Write-ColorOutput "  追加するデバイス情報" "Cyan"
    Write-ColorOutput "================================================" "Cyan"
    Write-Host "  MAC アドレス: $mac"
    Write-Host "  ニックネーム: $nickname"
    if ($description) {
        Write-Host "  説明: $description"
    }
    if ($location) {
        Write-Host "  設置場所: $location"
    }
    Write-Host ""

    $confirm = Read-Host "この内容で追加しますか？ (y/N)"

    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Info "キャンセルしました"
        return
    }

    Write-Host ""

    # デバイスを追加
    $success = Add-Device -Mac $mac -Nickname $nickname -Description $description -Location $location

    if ($success) {
        Write-Host ""
        Write-ColorOutput "================================================" "Green"
        Write-ColorOutput "  デバイスの追加が完了しました" "Green"
        Write-ColorOutput "================================================" "Green"
        Write-Host ""
        Write-Info "次のステップ:"
        Write-Host "  1. システムを再起動するか、MAC Guard をリロードしてください"
        Write-Host "     バックエンドを再起動: cd C:\path\to\tb\tb-acq-backend"
        Write-Host "                         npm run dev"
        Write-Host ""
        Write-Host "  2. FirstVRデバイスの設定を確認してください"
        Write-Host "     - MQTT ブローカーのIPアドレスが正しいこと"
        Write-Host "     - Wi-Fi接続が確立していること"
        Write-Host ""
        Write-Host "  3. デバイスリストに表示されることを確認してください"
        Write-Host "     ブラウザ: http://localhost:5173 → デバイス一覧"
        Write-Host ""
    } else {
        Write-Error "デバイスの追加に失敗しました"
    }
}

# スクリプト実行
Main

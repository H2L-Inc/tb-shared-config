# TB System - 運用ガイド

展示会場でのTB Systemの運用手順をまとめたガイドです。

## 目次

1. [システム概要](#システム概要)
2. [展示会場での初期セットアップ](#展示会場での初期セットアップ)
3. [日常運用](#日常運用)
4. [トラブルシューティング](#トラブルシューティング)
5. [緊急時の対応](#緊急時の対応)

---

## システム概要

### 構成

- **FirstVRデバイス**: 最大3台まで同時接続可能
- **サーバーPC**: Windows 11 Pro + Docker Desktop (MQTT, InfluxDB, Grafana, Python worker, Backend)
- **タブレット**: Surface Pro (ブラウザUI)

### 重要なポート

| サービス | ポート | 用途 |
|---------|-------|------|
| MQTT Broker | 1883 | FirstVR ↔ サーバー通信 |
| Backend API | 4000 | タブレット ↔ サーバー通信 |
| Frontend | 5173 | タブレットUI |
| InfluxDB | 8086 | データベース |
| Grafana | 3000 | ダッシュボード表示 |

---

## 展示会場での初期セットアップ

### 事前準備（搬入前）

1. **ネットワーク情報の確認**
   - Toyota Boshoku社から提供されたIPアドレスを確認
   - Wi-Fi SSID とパスワードを確認

2. **デバイス情報の準備**
   - 使用するFirstVRデバイスのMAC アドレス一覧
   - デバイスのニックネーム（例: FVR-48D8, デモ機1）

### Step 1: サーバーPCのセットアップ

#### 1-1. ネットワーク接続

```powershell
# Wi-Fi接続を確認
ipconfig

# サーバーPCのIPアドレスをメモ
# 例: 192.168.1.100
```

#### 1-2. 環境設定の切り替え

展示環境の設定ファイルを生成します。

```powershell
# PowerShellを管理者権限で起動
cd C:\work\tb\tb-env-win\bin

# 環境変数を自動生成
.\05_setup_env_production.ps1
```

#### 1-3. 環境設定ファイルの更新

`tb-shared-config/environments/exhibition.json` を編集:

```json
{
  "env": "exhibition",
  "mqtt": {
    "broker_url": "mqtt://192.168.1.100:1883"  ← サーバーPCのIP
  },
  "backend": {
    "url": "http://192.168.1.100:4000",  ← サーバーPCのIP
    "port": 4000
  },
  "influxdb": {
    "url": "http://localhost:8086",
    "token": "...",
    "org": "tb"
  },
  "grafana": {
    "url": "http://localhost:3000"
  }
}
```

#### 1-4. Dockerサービスの起動

```powershell
cd C:\path\to\tb

# Dockerコンテナを起動
docker compose up -d

# 起動確認（6つのコンテナが"Up"になるまで待つ）
docker compose ps

# ログ確認
docker compose logs -f
```

#### 1-5. ネットワーク疎通確認

```powershell
cd C:\path\to\tb\tb-shared-config\scripts

# ネットワーク検証スクリプトを実行
.\verify-network.ps1

# すべてのテストが成功することを確認
# - MQTT Broker: PASS
# - InfluxDB: PASS
# - Grafana: PASS
# - Backend API: PASS
# - Frontend: PASS
```

### Step 2: FirstVRデバイスのセットアップ

#### 2-1. MACアドレスの確認

FirstVRデバイスの底面シールまたはシリアル番号からMAC アドレスを確認します。

例:
- デバイス1: `34:CD:B0:35:48:D8`
- デバイス2: `34:CD:B0:35:48:E0`
- デバイス3: `34:CD:B0:35:49:1C`

#### 2-2. デバイスをシステムに追加

```powershell
cd C:\path\to\tb\tb-shared-config\scripts

# デバイス追加スクリプトを実行
.\add-device.ps1

# プロンプトに従って入力:
# 1. MAC アドレス: 34CDB03548D8 （コロン不要）
# 2. ニックネーム: FVR-48D8
# 3. 説明: 展示用デバイス1
# 4. 設置場所: 展示ホール
```

#### 2-3. FirstVRファームウェア設定変更

Tera Term を使用してFirstVRに接続し、MQTT ブローカーIPを変更します。

```
# Tera Term で FirstVR に接続

# 現在の設定を確認
AT+MQTT?

# MQTT ブローカーIPを変更
AT+MQTT=192.168.1.100,1883

# 設定を保存して再起動
AT+SAVE
AT+RESET
```

**重要**: ファームウェア ver 1.3.0 はデフォルトで `54.186.2.217` (AWS EC2) に接続します。必ずローカルサーバーIPに変更してください。

#### 2-4. Wi-Fi接続確認

FirstVRデバイスが展示会場のWi-Fiに接続されていることを確認します。

```
# Tera Term で確認
AT+WIFI?

# 接続状態が "Connected" になっていること
```

#### 2-5. バックエンドの再起動

デバイス追加後、MAC Guardをリロードするためバックエンドを再起動します。

```powershell
cd C:\path\to\tb\tb-acq-backend

# バックエンドを再起動（開発モード）
npm run dev

# または Dockerコンテナを再起動
docker compose restart tb-acq-backend
```

### Step 3: タブレットのセットアップ

#### 3-1. タブレットのネットワーク接続

タブレット（Surface Pro）を展示会場のWi-Fiに接続します。

#### 3-2. ブラウザでUIにアクセス

```
http://192.168.1.100:5173
```

サーバーPCのIPアドレスに合わせて変更してください。

#### 3-3. デバイス一覧の確認

UIのデバイス一覧画面で、追加したFirstVRデバイスが表示されることを確認します。

- デバイス名: FVR-48D8
- MAC: 34CDB03548D8
- Status: Online

---

## 日常運用

### 朝の起動手順

1. **サーバーPCを起動**
   - Docker Desktop が自動起動することを確認
   - `docker compose ps` で6つのコンテナが"Up"であることを確認

2. **タブレットを起動**
   - ブラウザでUI (`http://192.168.1.100:5173`) を開く

3. **FirstVRデバイスの電源ON**
   - デバイスが自動的にWi-Fiに接続
   - UI上で"Online"になることを確認

4. **Grafanaダッシュボードの確認**
   - `http://localhost:3000` でダッシュボードを開く
   - データが正常に表示されることを確認

### 夕方の終了手順

1. **FirstVRデバイスの電源OFF**
   - 各デバイスの電源ボタンを長押し

2. **タブレットをスリープ**
   - ブラウザは閉じなくてOK

3. **サーバーPCをスリープ（または電源OFF）**
   - Docker コンテナは自動的に停止

### データのバックアップ

週に1回、以下のディレクトリをバックアップしてください。

```powershell
# バックアップ対象
C:\path\to\tb\tb-shared-config\devices\allowed-devices.json
C:\path\to\tb\reports\

# バックアップ先（外付けUSBドライブなど）
E:\backup\tb-config\YYYYMMDD\
```

---

## トラブルシューティング

### 問題: デバイスがUIに表示されない

#### 原因1: MAC アドレスがホワイトリストに登録されていない

```powershell
# デバイス一覧を確認
cd C:\path\to\tb\tb-shared-config
type devices\allowed-devices.json

# 該当MACが含まれているか確認
# 含まれていない場合は add-device.ps1 で追加
```

#### 原因2: FirstVRがWi-Fiに接続されていない

```
# Tera Term でFirstVRに接続
AT+WIFI?

# Wi-Fi再接続
AT+WIFI=<SSID>,<PASSWORD>
```

#### 原因3: MQTT ブローカーIPが間違っている

```
# Tera Term で確認
AT+MQTT?

# 正しいサーバーIPに変更
AT+MQTT=192.168.1.100,1883
AT+SAVE
AT+RESET
```

### 問題: タブレットからサーバーに接続できない

#### 原因1: ネットワークが異なる

タブレットとサーバーPCが同じWi-Fiに接続されているか確認してください。

```powershell
# サーバーPC側で確認
ipconfig

# タブレット側で確認（Edge開発者ツール）
# ブラウザのコンソールでエラーメッセージを確認
```

#### 原因2: ファイアウォールがブロックしている

Windows Defender ファイアウォールでポート4000と5173が許可されているか確認してください。

```powershell
# ファイアウォール設定を確認
Get-NetFirewallRule | Where-Object {$_.LocalPort -eq 4000 -or $_.LocalPort -eq 5173}
```

### 問題: データがGrafanaに表示されない

#### 原因1: InfluxDBが起動していない

```powershell
docker compose ps

# InfluxDBコンテナが"Up"になっているか確認
# 停止している場合は再起動
docker compose restart config-influxdb-1
```

#### 原因2: Pythonワーカー（sensor_reader.exe）がエラー

```powershell
# ログを確認
Get-Content C:\workspace\tb\tb-data-pipeline\reports\worker\LATEST_SUMMARY.md
Get-Content C:\workspace\tb\tb-data-pipeline\reports\worker\cron.log -Tail 100

# 再起動（exe を再起動）
cd C:\workspace\tb\tb-env-win\bin
Stop-Process -Name sensor_reader -ErrorAction SilentlyContinue
./40_start_worker.ps1
```

---

## 緊急時の対応

### すべてのサービスを再起動

```powershell
cd C:\path\to\tb

# すべてのコンテナを停止
docker compose down

# 再起動
docker compose up -d

# 起動確認
docker compose ps
```

### 設定を初期状態に戻す

```powershell
cd C:\path\to\tb\tb-shared-config

# バックアップから復元
copy E:\backup\tb-config\YYYYMMDD\allowed-devices.json devices\

# 環境を再設定
cd C:\work\tb\tb-env-win\bin
.\05_setup_env_production.ps1
```

### サポート連絡先

- **技術担当**: 浅川 (asaka@example.com)
- **表示担当**: 西口 (nishiguchi@example.com)

### ログファイルの場所

トラブル時には以下のログを確認してください。

```
# Dockerログ
docker compose logs -f > C:\temp\docker-logs.txt

# ネットワーク検証レポート
C:\path\to\tb\reports\network_verify_*.txt

# バックエンドログ
C:\path\to\tb\tb-acq-backend\logs\
```

---

## 付録: コマンドリファレンス

### 環境切り替え

```powershell
cd C:\work\tb\tb-env-win\bin
.\05_setup_env_production.ps1
```

### ヘルスチェック

```powershell
cd C:\work\tb\tb-env-win\bin
.\80_health_check.ps1
```

### Docker操作

```powershell
# コンテナ一覧
docker compose ps

# ログ確認
docker compose logs -f [service-name]

# 再起動
docker compose restart [service-name]

# 停止
docker compose down

# 起動
docker compose up -d
```

---

**最終更新**: 2025-10-22
**Version**: 1.0.0

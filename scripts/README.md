# TB System - 運用スクリプト

TB System の環境設定とデバイス管理を簡単に行うためのスクリプト集です。
専門知識がなくても安全に操作できるよう、対話型のインターフェースを提供しています。

## 概要

| スクリプト | 説明 | 対象OS |
|---------|------|--------|
| `switch-environment.sh` | 環境切り替え（開発⇔展示） | macOS/Linux |
| `switch-environment.ps1` | 環境切り替え（開発⇔展示） | Windows |
| `add-device.sh` | FirstVRデバイス追加 | macOS/Linux |
| `add-device.ps1` | FirstVRデバイス追加 | Windows |
| `verify-network.sh` | ネットワーク疎通確認 | macOS/Linux |
| `verify-network.ps1` | ネットワーク疎通確認 | Windows |

## 1. 環境切り替えスクリプト

開発環境（development）と展示環境（exhibition）を安全に切り替えます。

### 使い方

#### macOS/Linux:
```bash
cd /path/to/tb/tb-shared-config/scripts
./switch-environment.sh
```

#### Windows PowerShell:
```powershell
cd C:\path\to\tb\tb-shared-config\scripts
.\switch-environment.ps1
```

### 実行内容

1. 現在の環境を表示
2. 利用可能な環境を一覧表示
3. 切り替える環境を番号で選択
4. 確認プロンプト
5. 以下のファイルを自動更新:
   - `tb-acq-backend/.env` - バックエンド設定
   - `tb-acq-app/.env.local` - フロントエンド設定
   - `tb-data-pipeline/.env` - データパイプライン設定

### 切り替え後の手順

スクリプト完了後、以下のサービスを再起動してください:

```bash
# 1. Docker コンテナを再起動
cd /path/to/tb
docker compose restart

# 2. フロントエンド開発サーバー（起動中の場合）
# Ctrl+C で停止 → npm run dev で再起動

# 3. バックエンドサーバー（起動中の場合）
# Ctrl+C で停止 → npm run dev で再起動
```

### 例

```
================================================
  TB System - 環境切り替えツール
================================================

ℹ 現在の環境: development

利用可能な環境:
  [1] 開発環境 (development) [現在]
  [2] 展示環境 (exhibition)

切り替える環境の番号を入力してください (終了: q): 2

⚠ 以下の環境に切り替えます:
  現在: development
  切替先: exhibition

よろしいですか？ (y/N): y

ℹ 環境を切り替えています: exhibition

ℹ 更新中: tb-acq-backend/.env
✓ 完了: tb-acq-backend/.env
ℹ 更新中: tb-acq-app/.env.local
✓ 完了: tb-acq-app/.env.local
ℹ 更新中: tb-data-pipeline/.env
✓ 完了: tb-data-pipeline/.env

✓ 環境の切り替えが完了しました: exhibition
```

## 2. デバイス追加スクリプト（準備中）

新しいFirstVRデバイスをシステムに追加します。

**Status**: 実装中（Phase 4.2）

### 予定機能

- デバイスMAC アドレスの入力（自動フォーマット）
- デバイスニックネームの設定
- ホワイトリストへの自動追加
- 設定ファイルの自動更新

## 3. ネットワーク検証スクリプト（準備中）

展示会場でのネットワーク疎通を確認します。

**Status**: 実装中（Phase 4.3）

### 予定機能

- MQTT ブローカー疎通確認（port 1883）
- InfluxDB 疎通確認（port 8086）
- Grafana 疎通確認（port 3000）
- バックエンドAPI 疎通確認（port 4000）
- フロントエンド疎通確認（port 5173）
- 結果レポートの生成

## トラブルシューティング

### "ENV_NAME が見つかりません"

.env ファイルが存在しない場合は、以下のコマンドで作成してください:

```bash
# バックエンド
echo "ENV_NAME=development" > tb-acq-backend/.env

# フロントエンド
echo "ENV_NAME=development" > tb-acq-app/.env.local

# データパイプライン
echo "ENV_NAME=development" > tb-data-pipeline/.env
```

### "jq コマンドが見つかりません"（macOS/Linux）

jq をインストールしてください:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq
```

### Windows PowerShell の実行ポリシーエラー

PowerShell スクリプトの実行が制限されている場合:

```powershell
# 実行ポリシーを確認
Get-ExecutionPolicy

# 制限されている場合は変更（管理者権限が必要）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 環境切り替え後にサービスが動作しない

1. Docker コンテナの状態を確認:
   ```bash
   docker compose ps
   ```

2. ログを確認:
   ```bash
   docker compose logs -f
   ```

3. 完全に再起動:
   ```bash
   docker compose down
   docker compose up -d
   ```

## 技術詳細

### ディレクトリ構造

```
tb-shared-config/
├── environments/          # 環境別設定ファイル
│   ├── development.json   # 開発環境
│   └── exhibition.json    # 展示環境
├── devices/               # デバイス管理ファイル
│   └── allowed-devices.json  # ホワイトリスト
├── schema/                # JSON Schema 定義
│   ├── environment.schema.json
│   └── devices.schema.json
└── scripts/               # 運用スクリプト（このディレクトリ）
    ├── switch-environment.sh
    ├── switch-environment.ps1
    └── README.md
```

### 環境設定ファイルの構造

`environments/*.json` の形式:

```json
{
  "env": "development",
  "mqtt": {
    "broker_url": "mqtt://localhost:1883"
  },
  "backend": {
    "url": "http://localhost:4000",
    "port": 4000
  },
  "influxdb": {
    "url": "http://localhost:8086",
    "token": "...",
    "org": "tb"
  },
  "grafana": {
    "url": "http://localhost:3000"
  },
  "logging": {
    "level": "debug"
  }
}
```

### デバイスホワイトリストの構造

`devices/allowed-devices.json` の形式:

```json
{
  "allowed_macs": [
    "34CDB035491C",
    "34CDB03548E0",
    "34CDB03548D8"
  ],
  "aliases": {
    "34CDB03548D8": {
      "nickname": "FVR-48D8",
      "description": "Development test device",
      "location": "Lab A"
    }
  }
}
```

## 参考情報

- プロジェクト仕様: `../../../CLAUDE.md`
- 実装計画: `../../../IMPLEMENTATION_PLAN.md`
- タスク管理: `../../../TASKS.md`

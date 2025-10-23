# tb-shared-config

共通設定管理リポジトリ（アーカイブ）

**注意**: このリポジトリは参照用に保持されていますが、環境設定管理は各リポジトリの `.env` ファイルに移行しました。

## ディレクトリ構造

```
tb-shared-config/
├── README.md                    # このファイル
├── schema/
│   ├── environment.schema.json  # 環境設定のJSON Schema（参照用）
│   └── devices.schema.json      # デバイス設定のJSON Schema（参照用）
├── environments/
│   ├── development.json         # 開発環境設定（参照用）
│   ├── production.json          # 展示環境設定（参照用）
│   └── local.json               # ローカル環境設定（参照用）
└── devices/
    ├── allowed-devices.json     # デバイス設定（参照用）
    └── mock-devices.json        # モックデバイス定義（参照用）
```

## 現在の環境設定方法

### 本番環境（Windows展示PC）

```powershell
cd tb-env-win/bin
.\05_setup_env_production.ps1  # 自動で .env ファイル生成
```

### 開発環境（Mac/ローカル）

```bash
# 各リポジトリの .env.example から .env を作成
cp tb-acq-backend/.env.example tb-acq-backend/.env
cp tb-acq-app/.env.example tb-acq-app/.env
cp tb-data-pipeline/.env.example tb-data-pipeline/.env

# 必要に応じて .env ファイルを編集
```

### 2. デバイスの追加

`devices/allowed-devices.json` を編集：

```json
{
  "allowed_macs": [
    "34CDB03548D8",
    "新しいMAC"
  ],
  "aliases": {
    "新しいMAC": {
      "nickname": "FVR-XXXX",
      "description": "説明",
      "location": "場所"
    }
  }
}
```

### 3. デバイス管理

**現在の実装**: MAC Guard は削除され、全ての FirstVR デバイスが自動的に受け入れられます。

デバイスエイリアスが必要な場合は、各アプリケーションのロジック内で管理してください。

## 移行履歴

- 2025-10-24: 環境設定を `.env` ファイルベースに移行
- ConfigLoader 削除、直接 `process.env` から読み込み
- `switch-environment` スクリプト削除
- MAC Guard 機能削除

# TB System - 運用スクリプト（アーカイブ）

**注意**: このディレクトリのスクリプトは廃止されました。

## 移行先

### 環境設定

**旧**: `switch-environment.sh` / `switch-environment.ps1`
**新**: 各リポジトリの `.env` ファイルで直接管理

#### 本番環境（Windows展示PC）
```powershell
cd tb-env-win/bin
.\05_setup_env_production.ps1
```

#### 開発環境（Mac/ローカル）
```bash
cp tb-acq-backend/.env.example tb-acq-backend/.env
cp tb-acq-app/.env.example tb-acq-app/.env
cp tb-data-pipeline/.env.example tb-data-pipeline/.env
```

### デバイス管理

**旧**: `add-device.sh` / `allowed-devices.json`
**新**: MAC Guard 削除、全デバイス自動受け入れ

### ネットワーク検証

**旧**: `verify-network.sh`
**新**: `tb-env-win/bin/80_health_check.ps1`

## 移行履歴

- 2025-10-24: 環境設定を `.env` ファイルベースに移行
- ConfigLoader 削除
- `switch-environment` スクリプト削除
- MAC Guard 機能削除

## 参考情報

- 現在の運用手順: `tb-env-win/README.md`
- プロジェクト仕様: `/tb/AGENTS.md`

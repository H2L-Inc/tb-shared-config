# tb-shared-config

共通設定管理リポジトリ

## ディレクトリ構造

```
tb-shared-config/
├── README.md                    # このファイル
├── schema/
│   ├── environment.schema.json  # 環境設定のJSON Schema
│   └── devices.schema.json      # デバイス設定のJSON Schema
├── environments/
│   ├── development.json         # 開発環境設定
│   ├── exhibition.json          # 展示環境設定
│   └── local.json               # ローカル上書き用（gitignore）
└── devices/
    ├── allowed-devices.json     # MACホワイトリスト + エイリアス
    └── mock-devices.json        # モックデバイス定義
```

## 使い方

### 1. 環境の切り替え

```bash
# 開発環境
export ENV_NAME=development
npm run dev

# 展示環境
export ENV_NAME=exhibition
npm start
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

### 3. ネットワーク設定の変更

`environments/exhibition.json` を編集：

```json
{
  "mqtt": {
    "broker_url": "mqtt://新しいIP:1883"
  },
  "backend": {
    "url": "http://新しいIP:4000"
  }
}
```

## バリデーション

設定ファイルは JSON Schema でバリデーションされます。

```bash
# スキーマ検証
npm run validate:config
```

## 詳細設計

詳細は `_vault/CONFIG_DESIGN.md` を参照してください。

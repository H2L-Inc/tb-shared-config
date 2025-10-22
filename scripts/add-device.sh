#!/usr/bin/env bash
#
# TB System - デバイス追加スクリプト (macOS/Linux用)
#
# 新しいFirstVRデバイスをシステムに追加するための対話型スクリプト
# 専門知識がなくても安全にデバイスを追加できます
#

set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"
DEVICES_FILE="$CONFIG_ROOT/devices/allowed-devices.json"
BACKUP_DIR="$CONFIG_ROOT/backups"

# カラー出力用の定数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 出力関数
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# ヘッダー表示
show_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}  TB System - デバイス追加ツール${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# MAC アドレスを正規化（コロン・ハイフンを削除、大文字化）
normalize_mac() {
    local mac="$1"
    echo "$mac" | tr -d ':-' | tr '[:lower:]' '[:upper:]'
}

# MAC アドレスの形式を検証
validate_mac() {
    local mac="$1"
    local normalized=$(normalize_mac "$mac")

    # 12桁の16進数かチェック
    if [[ ! "$normalized" =~ ^[0-9A-F]{12}$ ]]; then
        return 1
    fi

    return 0
}

# 現在のデバイスリストを表示
show_current_devices() {
    if [ ! -f "$DEVICES_FILE" ]; then
        print_warning "デバイスファイルが見つかりません: $DEVICES_FILE"
        return
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jqコマンドが見つかりません。インストールしてください: brew install jq"
        exit 1
    fi

    local macs=$(cat "$DEVICES_FILE" | jq -r '.allowed_macs[]')
    local count=$(echo "$macs" | wc -l | tr -d ' ')

    echo -e "${YELLOW}現在登録されているデバイス ($count 台):${NC}"
    echo ""

    for mac in $macs; do
        local alias=$(cat "$DEVICES_FILE" | jq -r ".aliases[\"$mac\"].nickname // \"(未設定)\"")
        local description=$(cat "$DEVICES_FILE" | jq -r ".aliases[\"$mac\"].description // \"\"")
        echo "  MAC: $mac"
        echo "  ニックネーム: $alias"
        if [ -n "$description" ]; then
            echo "  説明: $description"
        fi
        echo ""
    done
}

# バックアップを作成
create_backup() {
    mkdir -p "$BACKUP_DIR"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/allowed-devices_$timestamp.json"

    cp "$DEVICES_FILE" "$backup_file"
    print_success "バックアップを作成しました: $backup_file"
}

# デバイスを追加
add_device() {
    local mac="$1"
    local nickname="$2"
    local description="$3"
    local location="$4"

    # 現在のデバイスリストを読み込み
    local current_json=$(cat "$DEVICES_FILE")

    # デバイスが既に存在するかチェック
    if echo "$current_json" | jq -e ".allowed_macs | index(\"$mac\")" > /dev/null 2>&1; then
        print_error "このMAC アドレスは既に登録されています: $mac"
        return 1
    fi

    # バックアップを作成
    create_backup

    # MAC アドレスを追加
    current_json=$(echo "$current_json" | jq ".allowed_macs += [\"$mac\"]")

    # エイリアス情報を追加
    local alias_obj="{\"nickname\": \"$nickname\""
    if [ -n "$description" ]; then
        alias_obj="$alias_obj, \"description\": \"$description\""
    fi
    if [ -n "$location" ]; then
        alias_obj="$alias_obj, \"location\": \"$location\""
    fi
    alias_obj="$alias_obj}"

    current_json=$(echo "$current_json" | jq ".aliases[\"$mac\"] = $alias_obj")

    # JSON Schema検証（スキーマファイルがある場合）
    local schema_file="$CONFIG_ROOT/schema/devices.schema.json"
    if [ -f "$schema_file" ]; then
        if ! echo "$current_json" | jq -e --slurpfile schema "$schema_file" '. as $data | $schema[0] as $s | $data' > /dev/null 2>&1; then
            print_error "デバイス設定がスキーマに適合しません"
            return 1
        fi
    fi

    # ファイルに保存
    echo "$current_json" | jq '.' > "$DEVICES_FILE"

    print_success "デバイスを追加しました: $mac ($nickname)"
    return 0
}

# メイン処理
main() {
    show_header

    # jqコマンドの確認
    if ! command -v jq &> /dev/null; then
        print_error "jqコマンドが見つかりません"
        print_info "インストール方法:"
        echo "  macOS:        brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  CentOS/RHEL:  sudo yum install jq"
        exit 1
    fi

    # デバイスファイルの確認
    if [ ! -f "$DEVICES_FILE" ]; then
        print_error "デバイスファイルが見つかりません: $DEVICES_FILE"
        exit 1
    fi

    # 現在のデバイスを表示
    show_current_devices

    echo -e "${CYAN}新しいデバイスを追加します${NC}"
    echo ""

    # MAC アドレス入力
    while true; do
        echo -e "${YELLOW}MAC アドレスを入力してください${NC}"
        echo "  形式: AABBCCDDEEFF または AA:BB:CC:DD:EE:FF"
        echo "  終了: q"
        echo ""
        read -p "MAC アドレス: " mac_input

        if [ "$mac_input" = "q" ] || [ "$mac_input" = "Q" ]; then
            print_info "キャンセルしました"
            exit 0
        fi

        if validate_mac "$mac_input"; then
            mac=$(normalize_mac "$mac_input")
            print_success "MAC アドレス: $mac"
            echo ""
            break
        else
            print_error "無効なMAC アドレスです。12桁の16進数で入力してください"
            echo ""
        fi
    done

    # ニックネーム入力
    while true; do
        echo -e "${YELLOW}デバイスのニックネームを入力してください${NC}"
        echo "  例: FVR-48D8, デモ機1, 展示用FirstVR"
        echo ""
        read -p "ニックネーム: " nickname

        if [ -z "$nickname" ]; then
            print_error "ニックネームは必須です"
            echo ""
        elif [ ${#nickname} -gt 20 ]; then
            print_error "ニックネームは20文字以内にしてください"
            echo ""
        else
            print_success "ニックネーム: $nickname"
            echo ""
            break
        fi
    done

    # 説明入力（オプション）
    echo -e "${YELLOW}デバイスの説明を入力してください（省略可）${NC}"
    echo "  例: 開発用テストデバイス, 展示会用デバイス"
    echo ""
    read -p "説明: " description
    if [ -n "$description" ]; then
        print_success "説明: $description"
    fi
    echo ""

    # 設置場所入力（オプション）
    echo -e "${YELLOW}設置場所を入力してください（省略可）${NC}"
    echo "  例: ラボA, 展示ホール, 開発室"
    echo ""
    read -p "設置場所: " location
    if [ -n "$location" ]; then
        print_success "設置場所: $location"
    fi
    echo ""

    # 確認
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}  追加するデバイス情報${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo "  MAC アドレス: $mac"
    echo "  ニックネーム: $nickname"
    if [ -n "$description" ]; then
        echo "  説明: $description"
    fi
    if [ -n "$location" ]; then
        echo "  設置場所: $location"
    fi
    echo ""

    read -p "この内容で追加しますか？ (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "キャンセルしました"
        exit 0
    fi

    echo ""

    # デバイスを追加
    if add_device "$mac" "$nickname" "$description" "$location"; then
        echo ""
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}  デバイスの追加が完了しました${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""
        print_info "次のステップ:"
        echo "  1. システムを再起動するか、MAC Guard をリロードしてください"
        echo "     バックエンドを再起動: cd /path/to/tb/tb-acq-backend && npm run dev"
        echo ""
        echo "  2. FirstVRデバイスの設定を確認してください"
        echo "     - MQTT ブローカーのIPアドレスが正しいこと"
        echo "     - Wi-Fi接続が確立していること"
        echo ""
        echo "  3. デバイスリストに表示されることを確認してください"
        echo "     ブラウザ: http://localhost:5173 → デバイス一覧"
        echo ""
    else
        print_error "デバイスの追加に失敗しました"
        exit 1
    fi
}

# スクリプト実行
main

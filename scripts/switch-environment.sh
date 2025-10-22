#!/usr/bin/env bash
#
# TB System - 環境切り替えスクリプト (macOS/Linux用)
#
# 開発環境(development)と展示環境(exhibition)を切り替えるための対話型スクリプト
# 専門知識がなくても安全に環境を切り替えられます
#

set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$CONFIG_ROOT")"

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
    echo -e "${CYAN}  TB System - 環境切り替えツール${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# 利用可能な環境を取得
get_available_environments() {
    local env_dir="$CONFIG_ROOT/environments"
    local environments=()

    for file in "$env_dir"/*.json; do
        if [ -f "$file" ]; then
            local env_name=$(basename "$file" .json)
            environments+=("$env_name")
        fi
    done

    echo "${environments[@]}"
}

# 環境名を表示名に変換
get_display_name() {
    local env_name="$1"
    case "$env_name" in
        development) echo "開発環境" ;;
        exhibition) echo "展示環境" ;;
        production) echo "本番環境" ;;
        *) echo "$env_name" ;;
    esac
}

# 現在の環境を取得
get_current_environment() {
    local env_files=(
        "$PROJECT_ROOT/tb-acq-backend/.env"
        "$PROJECT_ROOT/tb-acq-app/.env.local"
        "$PROJECT_ROOT/tb-data-pipeline/.env"
    )

    local current_env=""
    for env_file in "${env_files[@]}"; do
        if [ -f "$env_file" ]; then
            current_env=$(grep -E '^ENV_NAME=' "$env_file" | cut -d'=' -f2 | tr -d '\r\n' || echo "")
            if [ -n "$current_env" ]; then
                break
            fi
        fi
    done

    if [ -z "$current_env" ]; then
        current_env="development"  # デフォルト
    fi

    echo "$current_env"
}

# 環境設定を読み込み
read_environment_config() {
    local env_name="$1"
    local config_path="$CONFIG_ROOT/environments/$env_name.json"

    if [ ! -f "$config_path" ]; then
        print_error "設定ファイルが見つかりません: $config_path"
        return 1
    fi

    cat "$config_path"
}

# JSONから値を抽出（jqがない場合の代替実装）
json_value() {
    local json="$1"
    local key_path="$2"

    if command -v jq &> /dev/null; then
        echo "$json" | jq -r "$key_path"
    else
        # jqがない場合はgrepとsedで簡易的に抽出
        echo "$json" | grep -o "\"$key_path\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*: *"\(.*\)".*/\1/'
    fi
}

# .envファイルを更新
update_env_file() {
    local file_path="$1"
    local env_name="$2"
    shift 2
    local -a variables=("$@")

    # ディレクトリが存在しない場合は作成
    local dir_path=$(dirname "$file_path")
    mkdir -p "$dir_path"

    # 既存のファイルがあれば読み込み
    local content=""
    if [ -f "$file_path" ]; then
        content=$(cat "$file_path")
    fi

    # ENV_NAMEを更新または追加
    if echo "$content" | grep -q '^ENV_NAME='; then
        content=$(echo "$content" | sed "s/^ENV_NAME=.*/ENV_NAME=$env_name/")
    else
        content="ENV_NAME=$env_name"$'\n'"$content"
    fi

    # その他の変数を更新
    for var_def in "${variables[@]}"; do
        local key=$(echo "$var_def" | cut -d'=' -f1)
        local value=$(echo "$var_def" | cut -d'=' -f2-)

        if echo "$content" | grep -q "^$key="; then
            content=$(echo "$content" | sed "s|^$key=.*|$key=$value|")
        else
            content="$content"$'\n'"$key=$value"
        fi
    done

    # ファイルに書き込み
    echo "$content" > "$file_path"
}

# 環境を切り替え
switch_environment() {
    local target_env="$1"

    print_info "環境を切り替えています: $target_env"
    echo ""

    # 設定を読み込み
    local config=$(read_environment_config "$target_env")
    if [ $? -ne 0 ]; then
        return 1
    fi

    # jqで値を抽出（jqがない場合はエラー）
    if ! command -v jq &> /dev/null; then
        print_error "jqコマンドが見つかりません。インストールしてください: brew install jq"
        return 1
    fi

    local mqtt_url=$(echo "$config" | jq -r '.mqtt.broker_url')
    local backend_url=$(echo "$config" | jq -r '.backend.url')
    local backend_port=$(echo "$config" | jq -r '.backend.port')
    local influx_url=$(echo "$config" | jq -r '.influxdb.url')
    local influx_token=$(echo "$config" | jq -r '.influxdb.token')
    local influx_org=$(echo "$config" | jq -r '.influxdb.org')

    # バックエンドの.envを更新
    print_info "更新中: tb-acq-backend/.env"
    update_env_file \
        "$PROJECT_ROOT/tb-acq-backend/.env" \
        "$target_env" \
        "MQTT_URL=$mqtt_url" \
        "BACKEND_PORT=$backend_port" \
        "INFLUXDB_URL=$influx_url"
    print_success "完了: tb-acq-backend/.env"

    # フロントエンドの.env.localを更新
    print_info "更新中: tb-acq-app/.env.local"
    update_env_file \
        "$PROJECT_ROOT/tb-acq-app/.env.local" \
        "$target_env" \
        "VITE_BACKEND_URL=$backend_url"
    print_success "完了: tb-acq-app/.env.local"

    # データパイプラインの.envを更新
    print_info "更新中: tb-data-pipeline/.env"
    update_env_file \
        "$PROJECT_ROOT/tb-data-pipeline/.env" \
        "$target_env" \
        "INFLUXDB_URL=$influx_url" \
        "INFLUXDB_TOKEN=$influx_token" \
        "INFLUXDB_ORG=$influx_org"
    print_success "完了: tb-data-pipeline/.env"

    echo ""
    print_success "環境の切り替えが完了しました: $target_env"

    return 0
}

# メイン処理
main() {
    show_header

    # 現在の環境を取得
    local current_env=$(get_current_environment)
    print_info "現在の環境: $current_env"
    echo ""

    # 利用可能な環境を取得
    local environments=($(get_available_environments))

    if [ ${#environments[@]} -eq 0 ]; then
        print_error "利用可能な環境設定が見つかりません"
        print_info "tb-shared-config/environments/ ディレクトリを確認してください"
        exit 1
    fi

    # 環境を選択
    echo -e "${YELLOW}利用可能な環境:${NC}"
    for i in "${!environments[@]}"; do
        local env_name="${environments[$i]}"
        local display_name=$(get_display_name "$env_name")
        local marker=""
        if [ "$env_name" = "$current_env" ]; then
            marker=" [現在]"
        fi
        echo "  [$((i + 1))] $display_name ($env_name)$marker"
    done
    echo ""

    read -p "切り替える環境の番号を入力してください (終了: q): " selection

    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        print_info "キャンセルしました"
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        print_error "無効な入力です"
        exit 1
    fi

    local index=$((selection - 1))
    if [ $index -lt 0 ] || [ $index -ge ${#environments[@]} ]; then
        print_error "無効な選択です"
        exit 1
    fi

    local target_env="${environments[$index]}"
    local display_name=$(get_display_name "$target_env")

    # 現在と同じ環境の場合は確認
    if [ "$target_env" = "$current_env" ]; then
        print_warning "既に $display_name です"
        read -p "それでも再適用しますか？ (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_info "キャンセルしました"
            exit 0
        fi
    else
        # 切り替え確認
        echo ""
        print_warning "以下の環境に切り替えます:"
        echo "  現在: $current_env"
        echo "  切替先: $target_env"
        echo ""

        read -p "よろしいですか？ (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_info "キャンセルしました"
            exit 0
        fi
    fi

    echo ""

    # 環境を切り替え
    if switch_environment "$target_env"; then
        echo ""
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}  次のステップ${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""
        print_info "以下のサービスを再起動してください:"
        echo "  1. Docker コンテナ:"
        echo "     cd $PROJECT_ROOT"
        echo "     docker compose restart"
        echo ""
        echo "  2. フロントエンド開発サーバー（起動中の場合）:"
        echo "     Ctrl+C で停止 → npm run dev で再起動"
        echo ""
        echo "  3. バックエンドサーバー（起動中の場合）:"
        echo "     Ctrl+C で停止 → npm run dev で再起動"
        echo ""
    else
        print_error "環境の切り替えに失敗しました"
        exit 1
    fi
}

# スクリプト実行
main

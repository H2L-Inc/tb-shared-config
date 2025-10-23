#!/usr/bin/env bash
#
# TB System - ネットワーク検証スクリプト (macOS/Linux用)
#
# 展示会場でのネットワーク疎通を確認するための検証ツール
# 専門知識がなくても簡単にネットワーク状態を確認できます
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

# 検証結果を保存する配列
declare -a TEST_RESULTS=()
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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
    echo -e "${CYAN}  TB System - ネットワーク検証ツール${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# テスト結果を記録
record_test() {
    local test_name="$1"
    local result="$2"
    local message="$3"

    ((TOTAL_TESTS++))

    if [ "$result" = "PASS" ]; then
        ((PASSED_TESTS++))
        print_success "$test_name: $message"
        TEST_RESULTS+=("✓ $test_name: $message")
    else
        ((FAILED_TESTS++))
        print_error "$test_name: $message"
        TEST_RESULTS+=("✗ $test_name: $message")
    fi
}

# 環境設定を読み込み
load_environment_config() {
    local env_name="${1:-development}"
    local config_file="$CONFIG_ROOT/environments/$env_name.json"

    if [ ! -f "$config_file" ]; then
        echo "development"
        return
    fi

    echo "$env_name"
}

# 現在の環境を取得
get_current_environment() {
    local env_files=(
        "$PROJECT_ROOT/tb-acq-backend/.env"
        "$PROJECT_ROOT/tb-acq-app/.env"
    )

    local current_env=""
    for env_file in "${env_files[@]}"; do
        if [ -f "$env_file" ]; then
            # ENV_NAMEまたはVITE_ENV_NAMEをチェック
            current_env=$(grep -E '^(VITE_)?ENV_NAME=' "$env_file" | cut -d'=' -f2 | tr -d '\r\n' || echo "")
            if [ -n "$current_env" ]; then
                break
            fi
        fi
    done

    if [ -z "$current_env" ]; then
        current_env="development"
    fi

    echo "$current_env"
}

# TCP接続テスト
test_tcp_connection() {
    local host="$1"
    local port="$2"
    local timeout=3

    if timeout $timeout bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# HTTP エンドポイントテスト
test_http_endpoint() {
    local url="$1"
    local timeout=5

    if command -v curl &> /dev/null; then
        if curl -s -f -m $timeout "$url" > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        # curl がない場合は TCP接続のみテスト
        local host=$(echo "$url" | sed -E 's|^https?://([^:/]+).*|\1|')
        local port=$(echo "$url" | sed -E 's|^https?://[^:]+:([0-9]+).*|\1|')
        if [ "$port" = "$url" ]; then
            port=80
        fi
        test_tcp_connection "$host" "$port"
        return $?
    fi
}

# MQTT ブローカーテスト
test_mqtt_broker() {
    local host="$1"
    local port="$2"

    echo ""
    print_info "MQTT ブローカー接続テスト: $host:$port"

    if test_tcp_connection "$host" "$port"; then
        record_test "MQTT Broker" "PASS" "$host:$port に接続成功"
    else
        record_test "MQTT Broker" "FAIL" "$host:$port に接続できません"
    fi
}

# InfluxDB テスト
test_influxdb() {
    local url="$1"

    echo ""
    print_info "InfluxDB 接続テスト: $url"

    # ping エンドポイントをテスト
    local ping_url="$url/ping"

    if test_http_endpoint "$ping_url"; then
        record_test "InfluxDB" "PASS" "$url に接続成功"
    else
        record_test "InfluxDB" "FAIL" "$url に接続できません"
    fi
}

# Grafana テスト
test_grafana() {
    local url="$1"

    echo ""
    print_info "Grafana 接続テスト: $url"

    # api/health エンドポイントをテスト
    local health_url="$url/api/health"

    if test_http_endpoint "$health_url"; then
        record_test "Grafana" "PASS" "$url に接続成功"
    else
        record_test "Grafana" "FAIL" "$url に接続できません"
    fi
}

# バックエンドAPI テスト
test_backend_api() {
    local url="$1"

    echo ""
    print_info "バックエンドAPI 接続テスト: $url"

    # health エンドポイントをテスト
    local health_url="$url/api/health"

    if test_http_endpoint "$health_url"; then
        record_test "Backend API" "PASS" "$url に接続成功"
    else
        record_test "Backend API" "FAIL" "$url に接続できません"
    fi
}

# フロントエンド テスト
test_frontend() {
    local url="$1"

    echo ""
    print_info "フロントエンド 接続テスト: $url"

    if test_http_endpoint "$url"; then
        record_test "Frontend" "PASS" "$url に接続成功"
    else
        record_test "Frontend" "FAIL" "$url に接続できません"
    fi
}

# 環境設定ファイルテスト
test_config_files() {
    echo ""
    print_info "環境設定ファイルの確認"

    local files=(
        "$PROJECT_ROOT/tb-acq-backend/.env"
        "$PROJECT_ROOT/tb-acq-app/.env"
        "$PROJECT_ROOT/tb-data-pipeline/.env"
    )

    local all_exist=true
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            record_test "Config File" "PASS" "$(basename $(dirname $file))/$(basename $file) が存在します"
        else
            record_test "Config File" "FAIL" "$(basename $(dirname $file))/$(basename $file) が見つかりません"
            all_exist=false
        fi
    done
}

# デバイス設定ファイルテスト
test_device_config() {
    echo ""
    print_info "デバイス設定ファイルの確認"

    local devices_file="$CONFIG_ROOT/devices/allowed-devices.json"

    if [ -f "$devices_file" ]; then
        if command -v jq &> /dev/null; then
            local device_count=$(cat "$devices_file" | jq -r '.allowed_macs | length')
            record_test "Device Config" "PASS" "$device_count 台のデバイスが登録されています"
        else
            record_test "Device Config" "PASS" "ファイルが存在します"
        fi
    else
        record_test "Device Config" "FAIL" "デバイス設定ファイルが見つかりません"
    fi
}

# レポート生成
generate_report() {
    local env_name="$1"
    local report_dir="$PROJECT_ROOT/reports"
    mkdir -p "$report_dir"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file="$report_dir/network_verify_${env_name}_$timestamp.txt"

    {
        echo "================================================"
        echo "  TB System - ネットワーク検証レポート"
        echo "================================================"
        echo ""
        echo "環境: $env_name"
        echo "実行日時: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "================================================"
        echo "  テスト結果サマリー"
        echo "================================================"
        echo ""
        echo "総テスト数: $TOTAL_TESTS"
        echo "成功: $PASSED_TESTS"
        echo "失敗: $FAILED_TESTS"
        echo ""
        echo "================================================"
        echo "  詳細結果"
        echo "================================================"
        echo ""
        for result in "${TEST_RESULTS[@]}"; do
            echo "$result"
        done
        echo ""
    } > "$report_file"

    print_success "レポートを保存しました: $report_file"
}

# メイン処理
main() {
    show_header

    # jqコマンドの確認（警告のみ）
    if ! command -v jq &> /dev/null; then
        print_warning "jqコマンドが見つかりません。一部の機能が制限されます"
        print_info "インストール: brew install jq"
        echo ""
    fi

    # 現在の環境を取得
    local env_name=$(get_current_environment)
    print_info "現在の環境: $env_name"
    echo ""

    # 環境設定を読み込み
    local config_file="$CONFIG_ROOT/environments/$env_name.json"

    if [ ! -f "$config_file" ]; then
        print_error "環境設定ファイルが見つかりません: $config_file"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jqコマンドが必要です。インストールしてください: brew install jq"
        exit 1
    fi

    local config=$(cat "$config_file")

    # 各種URLとポートを抽出
    local mqtt_url=$(echo "$config" | jq -r '.mqtt.broker_url')
    local mqtt_host=$(echo "$mqtt_url" | sed -E 's|^mqtt://([^:]+):.*|\1|')
    local mqtt_port=$(echo "$mqtt_url" | sed -E 's|^mqtt://[^:]+:([0-9]+).*|\1|')

    local influx_url=$(echo "$config" | jq -r '.influxdb.url')
    local grafana_url=$(echo "$config" | jq -r '.grafana.url')
    local backend_url=$(echo "$config" | jq -r '.backend.url')

    # フロントエンドURL（開発環境は5173、展示環境は別ポート）
    local frontend_url="http://localhost:5173"

    # 各種テストを実行
    test_config_files
    test_device_config
    test_mqtt_broker "$mqtt_host" "$mqtt_port"
    test_influxdb "$influx_url"
    test_grafana "$grafana_url"
    test_backend_api "$backend_url"
    test_frontend "$frontend_url"

    # 結果サマリー
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}  テスト結果サマリー${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
    echo "  環境: $env_name"
    echo "  総テスト数: $TOTAL_TESTS"
    echo "  成功: ${GREEN}$PASSED_TESTS${NC}"
    echo "  失敗: ${RED}$FAILED_TESTS${NC}"
    echo ""

    # レポート生成
    generate_report "$env_name"

    echo ""
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}  すべてのテストに合格しました！${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""
        print_success "ネットワーク環境は正常です"
    else
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}  一部のテストが失敗しました${NC}"
        echo -e "${RED}================================================${NC}"
        echo ""
        print_warning "以下を確認してください:"
        echo "  1. Docker コンテナが起動しているか"
        echo "     docker compose ps"
        echo ""
        echo "  2. ファイアウォール設定が正しいか"
        echo ""
        echo "  3. 各サービスのログを確認"
        echo "     docker compose logs -f"
        echo ""
    fi
}

# スクリプト実行
main

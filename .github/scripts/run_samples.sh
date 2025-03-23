#!/bin/bash

# GraphAIサンプル実行スクリプト
# .github/scripts/tutorial_yml/ フォルダ内のYAMLファイルが全て問題なく実行できるかを確認する

# 定数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
YAML_DIR="${SCRIPT_DIR}/tutorial_yml"
RESULTS_DIR="${REPO_ROOT}/test_results"
LOG_DIR="${RESULTS_DIR}/logs"
YAML_LOG_DIR="${LOG_DIR}/yaml_samples"
CACHE_FILE="${RESULTS_DIR}/.cache"

# デフォルト設定
VERBOSE=false
TIMEOUT=300  # 5分
ENV_FILE=""
OUTPUT_FORMAT="text"  # text, json, github-actions
SPECIFIC_SAMPLE=""
USE_CACHE=false

# 色の定義（CI環境では無効化）
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# 使用方法の表示
usage() {
  echo "使用方法: $0 [オプション]"
  echo "オプション:"
  echo "  -v, --verbose         詳細な出力を表示"
  echo "  -e, --env <file>      環境変数ファイルを指定"
  echo "  -t, --timeout <sec>   タイムアウト時間を秒単位で指定（デフォルト: 300）"
  echo "  -o, --output <format> 出力形式を指定（text, json, github-actions）"
  echo "  -s, --sample <name>   特定のサンプルのみを実行（ファイル名またはパス）"
  echo "  --cache               キャッシュを使用して変更のないサンプルをスキップ"
  echo "  -h, --help            このヘルプメッセージを表示"
  exit 1
}

# 引数の解析
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -e|--env)
        ENV_FILE="$2"
        shift 2
        ;;
      -t|--timeout)
        TIMEOUT="$2"
        shift 2
        ;;
      -o|--output)
        OUTPUT_FORMAT="$2"
        shift 2
        ;;
      -s|--sample)
        SPECIFIC_SAMPLE="$2"
        shift 2
        ;;
      --cache)
        USE_CACHE=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo "不明なオプション: $1"
        usage
        ;;
    esac
  done
  
  # 出力形式の検証
  if [[ "${OUTPUT_FORMAT}" != "text" && "${OUTPUT_FORMAT}" != "json" && "${OUTPUT_FORMAT}" != "github-actions" ]]; then
    echo "エラー: 無効な出力形式です。text, json, github-actionsのいずれかを指定してください。"
    exit 1
  fi
  
  # デバッグ情報の出力
  if [[ "${OUTPUT_FORMAT}" == "text" || "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "設定パラメータ:"
    echo "  特定サンプル: ${SPECIFIC_SAMPLE}"
    echo "  キャッシュ: ${USE_CACHE}"
    echo "  タイムアウト: ${TIMEOUT}秒"
  fi
}

# 環境のセットアップ
setup() {
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}環境のセットアップ...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::環境のセットアップ"
  fi
  
  # 結果ディレクトリの作成
  mkdir -p "${RESULTS_DIR}"
  mkdir -p "${LOG_DIR}"
  mkdir -p "${YAML_LOG_DIR}"
  
  # 環境変数ファイルの読み込み
  if [[ -n "${ENV_FILE}" && -f "${ENV_FILE}" ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${BLUE}環境変数ファイル ${ENV_FILE} を読み込み中...${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "環境変数ファイル ${ENV_FILE} を読み込み中..."
    fi
    source "${ENV_FILE}"
  fi
  
  # graphaiコマンドの確認
  if ! command -v graphai &> /dev/null; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${RED}エラー: graphaiコマンドが見つかりません。${NC}"
      echo "インストール方法: npm i -g @receptron/graphai_cli"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::error::graphaiコマンドが見つかりません。npm i -g @receptron/graphai_cli でインストールしてください。"
    fi
    exit 1
  fi
  
  # 必要な環境変数の確認
  if [[ -z "${OPENAI_API_KEY}" ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${YELLOW}警告: OPENAI_API_KEYが設定されていません。一部のサンプルが失敗する可能性があります。${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::warning::OPENAI_API_KEYが設定されていません。一部のサンプルが失敗する可能性があります。"
    fi
  fi
  
  if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::endgroup::"
  fi
}

# ファイルのハッシュ値を計算
calculate_hash() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    sha256sum "${file}" | cut -d' ' -f1
  else
    echo "file-not-found"
  fi
}

# キャッシュの読み込み
load_cache() {
  if [[ "${USE_CACHE}" == "true" && -f "${CACHE_FILE}" ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${BLUE}キャッシュを読み込み中...${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::group::キャッシュを読み込み中"
    fi
    source "${CACHE_FILE}"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
  else
    # キャッシュ変数の初期化
    declare -A YAML_CACHE
  fi
}

# キャッシュの保存
save_cache() {
  if [[ "${USE_CACHE}" == "true" ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${BLUE}キャッシュを保存中...${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::group::キャッシュを保存中"
    fi
    
    # キャッシュファイルの作成
    echo "# GraphAI サンプル実行キャッシュ" > "${CACHE_FILE}"
    echo "# $(date)" >> "${CACHE_FILE}"
    
    # YAMLサンプルのハッシュを保存
    echo "declare -A YAML_CACHE" >> "${CACHE_FILE}"
    for key in "${!YAML_CACHE[@]}"; do
      echo "YAML_CACHE[\"${key}\"]=\"${YAML_CACHE[${key}]}\"" >> "${CACHE_FILE}"
    done
    
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
  fi
}

# YAMLサンプルの準備
prepare_yaml_samples() {
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}YAMLサンプルを準備中...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::YAMLサンプルを準備中"
  fi
  
  # YAMLディレクトリの存在確認
  if [[ ! -d "${YAML_DIR}" ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${RED}エラー: ${YAML_DIR} ディレクトリが見つかりません。${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::error::${YAML_DIR} ディレクトリが見つかりません。"
    fi
    exit 1
  fi
  
  # 結果ファイルの初期化
  echo "sample,status,duration,hash" > "${RESULTS_DIR}/yaml_results.csv"
  
  # YAMLファイルの検索
  local yaml_count=0
  for yaml_file in "${YAML_DIR}"/*.yml "${YAML_DIR}"/*.yaml; do
    # ファイルが存在しない場合はスキップ
    if [[ ! -f "${yaml_file}" ]]; then
      continue
    fi
    
    ((yaml_count++))
    local base_name=$(basename "${yaml_file}")
    
    # ファイルのハッシュを計算
    local file_hash=$(calculate_hash "${yaml_file}")
    
    # 特定のサンプルが指定されている場合、一致するかチェック
    local should_run=true
    if [[ -n "${SPECIFIC_SAMPLE}" ]]; then
      if [[ "${base_name}" != *"${SPECIFIC_SAMPLE}"* ]]; then
        should_run=false
      fi
    fi
    
    # キャッシュをチェック
    if [[ "${USE_CACHE}" == "true" && -n "${YAML_CACHE[${yaml_file}]}" && "${YAML_CACHE[${yaml_file}]}" == "${file_hash}" ]]; then
      if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        echo -e "  スキップ: ${YELLOW}${base_name}${NC} (キャッシュ済み)"
      elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
        echo "  スキップ: ${base_name} (キャッシュ済み)"
      fi
      echo "${base_name},cached,0,${file_hash}" >> "${RESULTS_DIR}/yaml_results.csv"
      continue
    fi
    
    # サンプル情報を記録
    if [[ "${should_run}" == "true" ]]; then
      echo "${base_name},pending,0,${file_hash}" >> "${RESULTS_DIR}/yaml_results.csv"
      if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        echo -e "  準備: ${YELLOW}${base_name}${NC}"
      elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
        echo "  準備: ${base_name}"
      fi
    else
      echo "${base_name},skipped,0,${file_hash}" >> "${RESULTS_DIR}/yaml_results.csv"
      if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        echo -e "  スキップ: ${YELLOW}${base_name}${NC} (フィルタ対象外)"
      elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
        echo "  スキップ: ${base_name} (フィルタ対象外)"
      fi
    fi
  done
  
  if [[ ${yaml_count} -eq 0 ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${YELLOW}警告: YAMLファイルが見つかりませんでした。${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::warning::YAMLファイルが見つかりませんでした。"
    fi
  else
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${GREEN}${yaml_count}個のYAMLサンプルを準備しました。${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "${yaml_count}個のYAMLサンプルを準備しました。"
    fi
  fi
  
  if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::endgroup::"
  fi
}

# YAMLサンプルの実行
run_yaml_sample() {
  local yaml_file="$1"
  local file_hash="$2"
  local full_path="${YAML_DIR}/${yaml_file}"
  local log_file="${YAML_LOG_DIR}/$(basename "${yaml_file}" .yml).log"
  local start_time=$(date +%s)
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}実行中: ${yaml_file}${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::実行中: ${yaml_file}"
  fi
  
  # タイムアウト付きでサンプルを実行（インタラクティブなサンプルに対応）
  # 自動応答を提供（yes/noの質問に対して常に「y」と応答）
  timeout ${TIMEOUT} bash -c "yes y | graphai \"${full_path}\"" > "${log_file}" 2>&1
  local exit_code=$?
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # キャッシュを更新
  YAML_CACHE["${full_path}"]="${file_hash}"
  
  if [[ ${exit_code} -eq 0 ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${GREEN}成功: ${yaml_file} (${duration}秒)${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::notice::成功: ${yaml_file} (${duration}秒)"
    fi
    sed -i "s/^${yaml_file},pending,0,${file_hash}/${yaml_file},success,${duration},${file_hash}/" "${RESULTS_DIR}/yaml_results.csv"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
    return 0
  elif [[ ${exit_code} -eq 124 ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${RED}タイムアウト: ${yaml_file} (${TIMEOUT}秒)${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::warning::タイムアウト: ${yaml_file} (${TIMEOUT}秒)"
    fi
    sed -i "s/^${yaml_file},pending,0,${file_hash}/${yaml_file},timeout,${TIMEOUT},${file_hash}/" "${RESULTS_DIR}/yaml_results.csv"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
    return 1
  else
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${RED}失敗: ${yaml_file} (${duration}秒)${NC}"
      if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${YELLOW}エラーログ:${NC}"
        tail -n 10 "${log_file}"
      fi
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::error::失敗: ${yaml_file} (${duration}秒)"
      if [[ "${VERBOSE}" == "true" ]]; then
        echo "エラーログ:"
        tail -n 10 "${log_file}" | while IFS= read -r line; do
          echo "::debug::${line}"
        done
      fi
    fi
    sed -i "s/^${yaml_file},pending,0,${file_hash}/${yaml_file},failure,${duration},${file_hash}/" "${RESULTS_DIR}/yaml_results.csv"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
    return 1
  fi
}

# サンプルの逐次実行
run_samples_sequential() {
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}サンプルを逐次実行中...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::サンプルを逐次実行中"
  fi
  
  # YAMLサンプルの実行
  while IFS=, read -r yaml_file status duration file_hash; do
    # ヘッダー行をスキップ
    if [[ "${yaml_file}" == "sample" ]]; then
      continue
    fi
    
    # pendingのサンプルのみ実行
    if [[ "${status}" != "pending" ]]; then
      continue
    fi
    
    run_yaml_sample "${yaml_file}" "${file_hash}"
  done < "${RESULTS_DIR}/yaml_results.csv"
  
  if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::endgroup::"
  fi
}

# 結果の集計（テキスト形式）
summarize_results_text() {
  echo -e "${BLUE}結果の集計...${NC}"
  
  echo -e "\n${BLUE}======= サンプル実行結果 =======${NC}\n"
  
  # YAMLサンプルの結果
  if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
    echo -e "${YELLOW}YAMLサンプル実行結果${NC}"
    echo ""
    
    local yaml_success=0
    local yaml_failure=0
    local yaml_timeout=0
    local yaml_cached=0
    local yaml_skipped=0
    
    echo -e "  ${BLUE}詳細結果:${NC}"
    while IFS=, read -r yaml_file status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${yaml_file}" == "sample" ]]; then
        continue
      fi
      
      # ステータスに基づいてカウント
      if [[ "${status}" == "success" ]]; then
        ((yaml_success++))
        echo -e "    ${GREEN}✓${NC} ${yaml_file} (${duration}秒)"
      elif [[ "${status}" == "timeout" ]]; then
        ((yaml_timeout++))
        echo -e "    ${YELLOW}⏱${NC} ${yaml_file} (タイムアウト)"
      elif [[ "${status}" == "cached" ]]; then
        ((yaml_cached++))
        echo -e "    ${BLUE}⚡${NC} ${yaml_file} (キャッシュ済み)"
      elif [[ "${status}" == "skipped" ]]; then
        ((yaml_skipped++))
        echo -e "    ${BLUE}⏭${NC} ${yaml_file} (スキップ)"
      else
        ((yaml_failure++))
        echo -e "    ${RED}✗${NC} ${yaml_file} (${duration}秒)"
      fi
    done < "${RESULTS_DIR}/yaml_results.csv"
    
    local yaml_total=$((yaml_success + yaml_failure + yaml_timeout + yaml_cached))
    local yaml_success_rate=0
    if [[ $((yaml_total - yaml_skipped)) -gt 0 ]]; then
      yaml_success_rate=$(echo "scale=2; ${yaml_success} * 100 / $((yaml_total - yaml_skipped))" | bc)
    fi
    
    echo ""
    echo -e "  ${BLUE}サマリー:${NC}"
    echo -e "    成功: ${GREEN}${yaml_success}${NC}"
    echo -e "    失敗: ${RED}${yaml_failure}${NC}"
    echo -e "    タイムアウト: ${YELLOW}${yaml_timeout}${NC}"
    echo -e "    キャッシュ済み: ${BLUE}${yaml_cached}${NC}"
    echo -e "    スキップ: ${BLUE}${yaml_skipped}${NC}"
    echo -e "    成功率: ${GREEN}${yaml_success_rate}%${NC} (${yaml_success}/$((yaml_total - yaml_skipped)))"
    echo ""
  fi
  
  echo -e "${BLUE}詳細なログは ${LOG_DIR} ディレクトリにあります。${NC}"
}

# 結果の集計（JSON形式）
summarize_results_json() {
  local yaml_results="[]"
  
  # YAMLサンプルの結果
  if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
    yaml_results="["
    local first_sample=true
    
    while IFS=, read -r yaml_file status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${yaml_file}" == "sample" ]]; then
        continue
      fi
      
      if [[ "${first_sample}" == "true" ]]; then
        first_sample=false
      else
        yaml_results="${yaml_results},"
      fi
      
      # サンプル情報をJSONに追加
      yaml_results="${yaml_results}{\"file\":\"${yaml_file}\",\"status\":\"${status}\",\"duration\":${duration}}"
    done < "${RESULTS_DIR}/yaml_results.csv"
    
    yaml_results="${yaml_results}]"
  fi
  
  # 統計情報の計算
  local yaml_total=0
  local yaml_success=0
  local yaml_timeout=0
  local yaml_failure=0
  local yaml_cached=0
  local yaml_skipped=0
  
  if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
    yaml_total=$(grep -v "^sample" "${RESULTS_DIR}/yaml_results.csv" | wc -l)
    yaml_success=$(grep ",success," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
    yaml_timeout=$(grep ",timeout," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
    yaml_failure=$(grep ",failure," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
    yaml_cached=$(grep ",cached," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
    yaml_skipped=$(grep ",skipped," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
  fi
  
  local yaml_success_rate=0
  if [[ $((yaml_total - yaml_skipped)) -gt 0 ]]; then
    yaml_success_rate=$(echo "scale=2; ${yaml_success} * 100 / $((yaml_total - yaml_skipped))" | bc)
  fi
  
  # 最終的なJSON出力
  echo "{"
  echo "  \"samples\": ${yaml_results},"
  echo "  \"stats\": {"
  echo "    \"total\": ${yaml_total},"
  echo "    \"success\": ${yaml_success},"
  echo "    \"failure\": ${yaml_failure},"
  echo "    \"timeout\": ${yaml_timeout},"
  echo "    \"cached\": ${yaml_cached},"
  echo "    \"skipped\": ${yaml_skipped},"
  echo "    \"success_rate\": ${yaml_success_rate}"
  echo "  }"
  echo "}"
}

# 結果の集計
summarize_results() {
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    summarize_results_text
  elif [[ "${OUTPUT_FORMAT}" == "json" ]]; then
    summarize_results_json
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::実行結果サマリー"
    summarize_results_text
    echo "::endgroup::"
    
    # GitHub Actionsの注釈を追加
    local yaml_success=0
    local yaml_total=0
    
    if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
      yaml_total=$(grep -v "^sample" "${RESULTS_DIR}/yaml_results.csv" | grep -v ",skipped," | wc -l)
      yaml_success=$(grep ",success," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
    fi
    
    local success_rate=0
    if [[ ${yaml_total} -gt 0 ]]; then
      success_rate=$(echo "scale=2; ${yaml_success} * 100 / ${yaml_total}" | bc)
    fi
    
    echo "::notice title=サンプル実行結果::成功率: ${success_rate}% (${yaml_success}/${yaml_total})"
    
    # 失敗したサンプルがある場合は警告を表示
    if [[ ${yaml_success} -lt ${yaml_total} ]]; then
      echo "::warning::${yaml_total}個中${yaml_success}個のサンプルが成功しました。詳細なログを確認してください。"
    fi
  fi
}

# メイン処理
main() {
  parse_args "$@"
  setup
  load_cache
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}GraphAIサンプル実行スクリプト${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "GraphAIサンプル実行スクリプト"
  fi
  
  # YAMLサンプルの準備
  prepare_yaml_samples
  
  # サンプルの実行
  run_samples_sequential
  
  # キャッシュの保存
  save_cache
  
  # 結果の集計
  summarize_results
  
  # 失敗したサンプルがある場合は終了コードを1にする
  local failure_count=0
  
  if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
    failure_count=$(grep ",failure," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
  fi
  
  if [[ ${failure_count} -gt 0 ]]; then
    exit 1
  fi
  
  exit 0
}

# スクリプトの実行
main "$@"

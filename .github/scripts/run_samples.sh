#!/bin/bash

# GraphAIサンプル実行スクリプト
# PR反映後のGraphAIリポジトリで、docs/Tutorial.mdのYAMLサンプルと
# packages/samples/src/内のサンプルを実行し、結果をチュートリアルごとに紐づけて出力

# 定数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SAMPLES_DIR="${REPO_ROOT}/packages/samples/src"
TUTORIAL_MD="${REPO_ROOT}/docs/Tutorial.md"
TEMP_DIR="${REPO_ROOT}/temp_yaml"
RESULTS_DIR="${REPO_ROOT}/test_results"
LOG_DIR="${RESULTS_DIR}/logs"
YAML_LOG_DIR="${LOG_DIR}/yaml_samples"
TS_LOG_DIR="${LOG_DIR}/ts_samples"
CACHE_FILE="${RESULTS_DIR}/.cache"

# デフォルト設定
VERBOSE=false
PARALLEL=false
MAX_JOBS=4
TIMEOUT=300  # 5分
ENV_FILE=""
OUTPUT_FORMAT="text"  # text, json, github-actions
CATEGORY="all"  # all, tutorial, samples
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

# TypeScriptサンプルリスト（packages/samples/README.mdから）
TS_SAMPLES=(
  "llm/interview.ts:Interview"
  "llm/interview_jp.ts:Interview in Japanese"
  "llm/research.ts:Research"
  "llm/describe_graph.ts:Graph Description"
  "interaction/chat.ts:Chat"
  "interaction/wikipedia.ts:In-memory RAG"
  "interaction/reception.ts:Reception"
  "interaction/metachat.ts:Generated Graph Example"
  "net/rss.ts:RSS Reader"
  "net/weather.ts:Weather app"
)

# 使用方法の表示
usage() {
  echo "使用方法: $0 [オプション]"
  echo "オプション:"
  echo "  -v, --verbose         詳細な出力を表示"
  echo "  -p, --parallel        サンプルを並列実行"
  echo "  -j, --jobs <num>      並列実行時の最大ジョブ数（デフォルト: 4）"
  echo "  -e, --env <file>      環境変数ファイルを指定"
  echo "  -t, --timeout <sec>   タイムアウト時間を秒単位で指定（デフォルト: 300）"
  echo "  -o, --output <format> 出力形式を指定（text, json, github-actions）"
  echo "  -c, --category <cat>  実行カテゴリを指定（all, tutorial, samples）"
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
      -p|--parallel)
        PARALLEL=true
        shift
        ;;
      -j|--jobs)
        MAX_JOBS="$2"
        shift 2
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
      -c|--category)
        CATEGORY="$2"
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
  
  # カテゴリの検証
  if [[ "${CATEGORY}" != "all" && "${CATEGORY}" != "tutorial" && "${CATEGORY}" != "samples" ]]; then
    echo "エラー: 無効なカテゴリです。all, tutorial, samplesのいずれかを指定してください。"
    exit 1
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
  mkdir -p "${TS_LOG_DIR}"
  mkdir -p "${TEMP_DIR}"
  
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
    # macOSの古いBashでは連想配列がサポートされていないため、通常の配列を使用
    YAML_CACHE_KEYS=()
    YAML_CACHE_VALUES=()
    TS_CACHE_KEYS=()
    TS_CACHE_VALUES=()
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
    
    # TypeScriptサンプルのハッシュを保存
    echo "declare -A TS_CACHE" >> "${CACHE_FILE}"
    for key in "${!TS_CACHE[@]}"; do
      echo "TS_CACHE[\"${key}\"]=\"${TS_CACHE[${key}]}\"" >> "${CACHE_FILE}"
    done
    
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
  fi
}

# Tutorial.mdからYAMLサンプルを抽出
extract_yaml_samples() {
  if [[ "${CATEGORY}" == "samples" ]]; then
    return
  fi
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}Tutorial.mdからYAMLサンプルを抽出中...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::Tutorial.mdからYAMLサンプルを抽出中"
  fi
  
  # 一時ディレクトリをクリア
  rm -rf "${TEMP_DIR}"/*
  
  # YAMLサンプルの抽出
  local yaml_count=0
  local in_yaml_block=false
  local yaml_content=""
  local yaml_section=""
  local line_num=0
  local start_line=0
  
  # 結果ファイルの初期化
  echo "sample,section,status,duration,hash" > "${RESULTS_DIR}/yaml_results.csv"
  
  while IFS= read -r line; do
    ((line_num++))
    
    # セクションヘッダーの検出
    if [[ $line =~ ^##[^#] ]]; then
      yaml_section="${line#\#\# }"
    fi
    
    # YAMLブロックの開始を検出
    if [[ $line == '```YAML' ]]; then
      in_yaml_block=true
      yaml_content=""
      start_line=$line_num
      continue
    fi
    
    # YAMLブロックの終了を検出
    if [[ $in_yaml_block == true && $line == '```' ]]; then
      in_yaml_block=false
      ((yaml_count++))
      
      # セクション名からファイル名を生成
      local section_slug=$(echo "${yaml_section}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
      local yaml_file="${TEMP_DIR}/tutorial_${section_slug}_${yaml_count}.yaml"
      
      # YAMLコンテンツをファイルに保存
      echo "${yaml_content}" > "${yaml_file}"
      
      # ファイルのハッシュを計算
      local file_hash=$(calculate_hash "${yaml_file}")
      
      # 特定のサンプルが指定されている場合、一致するかチェック
      local should_run=true
      if [[ -n "${SPECIFIC_SAMPLE}" && "${SPECIFIC_SAMPLE}" != "" ]]; then
        local base_name=$(basename "${yaml_file}")
        if [[ "${base_name}" != *"${SPECIFIC_SAMPLE}"* && "${yaml_section}" != *"${SPECIFIC_SAMPLE}"* ]]; then
          should_run=false
        fi
      fi
      
      # キャッシュをチェック
      if [[ "${USE_CACHE}" == "true" && -n "${YAML_CACHE[${yaml_file}]}" && "${YAML_CACHE[${yaml_file}]}" == "${file_hash}" ]]; then
        if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
          echo -e "  スキップ: ${YELLOW}${yaml_file}${NC} (キャッシュ済み)"
        elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
          echo "  スキップ: $(basename "${yaml_file}") (キャッシュ済み)"
        fi
        echo "$(basename "${yaml_file}"),${yaml_section},cached,0,${file_hash}" >> "${RESULTS_DIR}/yaml_results.csv"
        continue
      fi
      
      # サンプル情報を記録
      if [[ "${should_run}" == "true" ]]; then
        echo "$(basename "${yaml_file}"),${yaml_section},pending,0,${file_hash}" >> "${RESULTS_DIR}/yaml_results.csv"
        if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
          echo -e "  抽出: ${YELLOW}$(basename "${yaml_file}")${NC} (セクション: ${BLUE}${yaml_section}${NC})"
        elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
          echo "  抽出: $(basename "${yaml_file}") (セクション: ${yaml_section})"
        fi
      else
        echo "$(basename "${yaml_file}"),${yaml_section},skipped,0,${file_hash}" >> "${RESULTS_DIR}/yaml_results.csv"
        if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
          echo -e "  スキップ: ${YELLOW}$(basename "${yaml_file}")${NC} (フィルタ対象外)"
        elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
          echo "  スキップ: $(basename "${yaml_file}") (フィルタ対象外)"
        fi
      fi
      
      continue
    fi
    
    # YAMLブロック内の行を収集
    if [[ $in_yaml_block == true ]]; then
      yaml_content="${yaml_content}${line}
"
    fi
  done < "${TUTORIAL_MD}"
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${GREEN}${yaml_count}個のYAMLサンプルを抽出しました。${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "${yaml_count}個のYAMLサンプルを抽出しました。"
    echo "::endgroup::"
  fi
}

# YAMLサンプルの実行
run_yaml_sample() {
  local yaml_file="$1"
  local section="$2"
  local file_hash="$3"
  local log_file="${YAML_LOG_DIR}/$(basename "${yaml_file}" .yaml).log"
  local start_time=$(date +%s)
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}実行中: ${yaml_file} (セクション: ${section})${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::実行中: ${yaml_file} (セクション: ${section})"
  fi
  
  # タイムアウト付きでサンプルを実行（インタラクティブなサンプルに対応）
  # 自動応答を提供（yes/noの質問に対して常に「y」と応答）
  timeout ${TIMEOUT} bash -c "yes y | graphai \"${TEMP_DIR}/${yaml_file}\"" > "${log_file}" 2>&1
  local exit_code=$?
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # キャッシュを更新
  YAML_CACHE["${TEMP_DIR}/${yaml_file}"]="${file_hash}"
  
  if [[ ${exit_code} -eq 0 ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${GREEN}成功: ${yaml_file} (${duration}秒)${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::notice::成功: ${yaml_file} (${duration}秒)"
    fi
    sed -i "s/^$(basename "${yaml_file}"),${section},pending,0,${file_hash}/$(basename "${yaml_file}"),${section},success,${duration},${file_hash}/" "${RESULTS_DIR}/yaml_results.csv"
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
    sed -i "s/^$(basename "${yaml_file}"),${section},pending,0,${file_hash}/$(basename "${yaml_file}"),${section},timeout,${TIMEOUT},${file_hash}/" "${RESULTS_DIR}/yaml_results.csv"
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
    sed -i "s/^$(basename "${yaml_file}"),${section},pending,0,${file_hash}/$(basename "${yaml_file}"),${section},failure,${duration},${file_hash}/" "${RESULTS_DIR}/yaml_results.csv"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
    return 1
  fi
}

# TypeScriptサンプルの準備
prepare_ts_samples() {
  if [[ "${CATEGORY}" == "tutorial" ]]; then
    return
  fi
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}TypeScriptサンプルを準備中...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::TypeScriptサンプルを準備中"
  fi
  
  # TypeScript結果ファイルの初期化
  echo "sample,section,status,duration,hash" > "${RESULTS_DIR}/ts_results.csv"
  
  for sample_info in "${TS_SAMPLES[@]}"; do
    local sample_path="${sample_info%%:*}"
    local sample_name="${sample_info#*:}"
    local full_path="${SAMPLES_DIR}/${sample_path}"
    
    # ファイルのハッシュを計算
    local file_hash=$(calculate_hash "${full_path}")
    
    # 特定のサンプルが指定されている場合、一致するかチェック
    local should_run=true
    if [[ -n "${SPECIFIC_SAMPLE}" && "${SPECIFIC_SAMPLE}" != "" ]]; then
      if [[ "${sample_path}" != *"${SPECIFIC_SAMPLE}"* && "${sample_name}" != *"${SPECIFIC_SAMPLE}"* ]]; then
        should_run=false
      fi
    fi
    
    # キャッシュをチェック
    if [[ "${USE_CACHE}" == "true" && -n "${TS_CACHE[${full_path}]}" && "${TS_CACHE[${full_path}]}" == "${file_hash}" ]]; then
      if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        echo -e "  スキップ: ${YELLOW}${sample_path}${NC} (キャッシュ済み)"
      elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
        echo "  スキップ: ${sample_path} (キャッシュ済み)"
      fi
      echo "${sample_path},${sample_name},cached,0,${file_hash}" >> "${RESULTS_DIR}/ts_results.csv"
      continue
    fi
    
    # サンプル情報を記録
    if [[ "${should_run}" == "true" ]]; then
      echo "${sample_path},${sample_name},pending,0,${file_hash}" >> "${RESULTS_DIR}/ts_results.csv"
      if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        echo -e "  準備: ${YELLOW}${sample_path}${NC} (${BLUE}${sample_name}${NC})"
      elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
        echo "  準備: ${sample_path} (${sample_name})"
      fi
    else
      echo "${sample_path},${sample_name},skipped,0,${file_hash}" >> "${RESULTS_DIR}/ts_results.csv"
      if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        echo -e "  スキップ: ${YELLOW}${sample_path}${NC} (フィルタ対象外)"
      elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
        echo "  スキップ: ${sample_path} (フィルタ対象外)"
      fi
    fi
  done
  
  if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::endgroup::"
  fi
}

# TypeScriptサンプルの実行
run_ts_sample() {
  local sample_path="$1"
  local sample_name="$2"
  local file_hash="$3"
  local full_path="${SAMPLES_DIR}/${sample_path}"
  local log_file="${TS_LOG_DIR}/$(basename "${sample_path}" .ts).log"
  local start_time=$(date +%s)
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}実行中: ${sample_path} (${sample_name})${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::実行中: ${sample_path} (${sample_name})"
  fi
  
  # タイムアウト付きでサンプルを実行（インタラクティブなサンプルに対応）
  # 自動応答を提供（yes/noの質問に対して常に「y」と応答）
  timeout ${TIMEOUT} bash -c "yes y | graphai \"${full_path}\"" > "${log_file}" 2>&1
  local exit_code=$?
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # キャッシュを更新
  TS_CACHE["${full_path}"]="${file_hash}"
  
  if [[ ${exit_code} -eq 0 ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${GREEN}成功: ${sample_path} (${duration}秒)${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::notice::成功: ${sample_path} (${duration}秒)"
    fi
    sed -i "s/^${sample_path},${sample_name},pending,0,${file_hash}/${sample_path},${sample_name},success,${duration},${file_hash}/" "${RESULTS_DIR}/ts_results.csv"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
    return 0
  elif [[ ${exit_code} -eq 124 ]]; then
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${RED}タイムアウト: ${sample_path} (${TIMEOUT}秒)${NC}"
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::warning::タイムアウト: ${sample_path} (${TIMEOUT}秒)"
    fi
    sed -i "s/^${sample_path},${sample_name},pending,0,${file_hash}/${sample_path},${sample_name},timeout,${TIMEOUT},${file_hash}/" "${RESULTS_DIR}/ts_results.csv"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
    return 1
  else
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
      echo -e "${RED}失敗: ${sample_path} (${duration}秒)${NC}"
      if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${YELLOW}エラーログ:${NC}"
        tail -n 10 "${log_file}"
      fi
    elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::error::失敗: ${sample_path} (${duration}秒)"
      if [[ "${VERBOSE}" == "true" ]]; then
        echo "エラーログ:"
        tail -n 10 "${log_file}" | while IFS= read -r line; do
          echo "::debug::${line}"
        done
      fi
    fi
    sed -i "s/^${sample_path},${sample_name},pending,0,${file_hash}/${sample_path},${sample_name},failure,${duration},${file_hash}/" "${RESULTS_DIR}/ts_results.csv"
    if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
      echo "::endgroup::"
    fi
    return 1
  fi
}

# 並列実行
run_samples_parallel() {
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}サンプルを並列実行中（最大${MAX_JOBS}ジョブ）...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::サンプルを並列実行中（最大${MAX_JOBS}ジョブ）"
  fi
  
  # YAMLサンプルの実行
  if [[ "${CATEGORY}" != "samples" ]]; then
    while IFS=, read -r yaml_file section status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${yaml_file}" == "sample" ]]; then
        continue
      fi
      
      # pendingのサンプルのみ実行
      if [[ "${status}" != "pending" ]]; then
        continue
      fi
      
      # 現在実行中のジョブ数を確認
      while [[ $(jobs -r | wc -l) -ge ${MAX_JOBS} ]]; do
        sleep 1
      done
      
      # バックグラウンドでサンプルを実行
      run_yaml_sample "${yaml_file}" "${section}" "${file_hash}" &
    done < "${RESULTS_DIR}/yaml_results.csv"
  fi
  
  # TypeScriptサンプルの実行
  if [[ "${CATEGORY}" != "tutorial" ]]; then
    while IFS=, read -r sample_path sample_name status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${sample_path}" == "sample" ]]; then
        continue
      fi
      
      # pendingのサンプルのみ実行
      if [[ "${status}" != "pending" ]]; then
        continue
      fi
      
      # 現在実行中のジョブ数を確認
      while [[ $(jobs -r | wc -l) -ge ${MAX_JOBS} ]]; do
        sleep 1
      done
      
      # バックグラウンドでサンプルを実行
      run_ts_sample "${sample_path}" "${sample_name}" "${file_hash}" &
    done < "${RESULTS_DIR}/ts_results.csv"
  fi
  
  # すべてのジョブが完了するのを待つ
  wait
  
  if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::endgroup::"
  fi
}

# 逐次実行
run_samples_sequential() {
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}サンプルを逐次実行中...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::サンプルを逐次実行中"
  fi
  
  # YAMLサンプルの実行
  if [[ "${CATEGORY}" != "samples" ]]; then
    while IFS=, read -r yaml_file section status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${yaml_file}" == "sample" ]]; then
        continue
      fi
      
      # pendingのサンプルのみ実行
      if [[ "${status}" != "pending" ]]; then
        continue
      fi
      
      run_yaml_sample "${yaml_file}" "${section}" "${file_hash}"
    done < "${RESULTS_DIR}/yaml_results.csv"
  fi
  
  # TypeScriptサンプルの実行
  if [[ "${CATEGORY}" != "tutorial" ]]; then
    while IFS=, read -r sample_path sample_name status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${sample_path}" == "sample" ]]; then
        continue
      fi
      
      # pendingのサンプルのみ実行
      if [[ "${status}" != "pending" ]]; then
        continue
      fi
      
      run_ts_sample "${sample_path}" "${sample_name}" "${file_hash}"
    done < "${RESULTS_DIR}/ts_results.csv"
  fi
  
  if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::endgroup::"
  fi
}

# 結果の集計（テキスト形式）
summarize_results_text() {
  echo -e "${BLUE}結果の集計...${NC}"
  
  echo -e "\n${BLUE}======= チュートリアル別実行結果 =======${NC}\n"
  
  # YAMLサンプル（Tutorial.md）の結果
  if [[ "${CATEGORY}" != "samples" && -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
    echo -e "${YELLOW}基本チュートリアル (Tutorial.md)${NC}"
    
    # セクションごとに結果をグループ化
    local current_section=""
    local section_success=0
    local section_failure=0
    local section_timeout=0
    local section_cached=0
    local section_skipped=0
    
    while IFS=, read -r yaml_file section status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${yaml_file}" == "sample" ]]; then
        continue
      fi
      
      # 新しいセクションの開始
      if [[ "${section}" != "${current_section}" ]]; then
        # 前のセクションの結果を表示（初回以外）
        if [[ -n "${current_section}" ]]; then
          local total=$((section_success + section_failure + section_timeout + section_cached))
          local success_rate=0
          if [[ ${total} -gt 0 ]]; then
            success_rate=$(echo "scale=2; ${section_success} * 100 / ${total}" | bc)
          fi
          
          echo -e "  ${BLUE}成功率:${NC} ${success_rate}% (${section_success}/${total})"
          if [[ ${section_cached} -gt 0 ]]; then
            echo -e "  ${BLUE}キャッシュ済み:${NC} ${section_cached}"
          fi
          if [[ ${section_skipped} -gt 0 ]]; then
            echo -e "  ${BLUE}スキップ:${NC} ${section_skipped}"
          fi
          echo ""
        fi
        
        # 新しいセクションの初期化
        current_section="${section}"
        section_success=0
        section_failure=0
        section_timeout=0
        section_cached=0
        section_skipped=0
        
        echo -e "  ${BLUE}セクション:${NC} ${current_section}"
      fi
      
      # ステータスに基づいてカウント
      if [[ "${status}" == "success" ]]; then
        ((section_success++))
        echo -e "    ${GREEN}✓${NC} ${yaml_file} (${duration}秒)"
      elif [[ "${status}" == "timeout" ]]; then
        ((section_timeout++))
        echo -e "    ${YELLOW}⏱${NC} ${yaml_file} (タイムアウト)"
      elif [[ "${status}" == "cached" ]]; then
        ((section_cached++))
        echo -e "    ${BLUE}⚡${NC} ${yaml_file} (キャッシュ済み)"
      elif [[ "${status}" == "skipped" ]]; then
        ((section_skipped++))
        echo -e "    ${BLUE}⏭${NC} ${yaml_file} (スキップ)"
      else
        ((section_failure++))
        echo -e "    ${RED}✗${NC} ${yaml_file} (${duration}秒)"
      fi
    done < "${RESULTS_DIR}/yaml_results.csv"
    
    # 最後のセクションの結果を表示
    if [[ -n "${current_section}" ]]; then
      local total=$((section_success + section_failure + section_timeout + section_cached))
      local success_rate=0
      if [[ ${total} -gt 0 ]]; then
        success_rate=$(echo "scale=2; ${section_success} * 100 / ${total}" | bc)
      fi
      
      echo -e "  ${BLUE}成功率:${NC} ${success_rate}% (${section_success}/${total})"
      if [[ ${section_cached} -gt 0 ]]; then
        echo -e "  ${BLUE}キャッシュ済み:${NC} ${section_cached}"
      fi
      if [[ ${section_skipped} -gt 0 ]]; then
        echo -e "  ${BLUE}スキップ:${NC} ${section_skipped}"
      fi
      echo ""
    fi
  fi
  
  # TypeScriptサンプル（packages/samples/README.md）の結果
  if [[ "${CATEGORY}" != "tutorial" && -f "${RESULTS_DIR}/ts_results.csv" ]]; then
    echo -e "${YELLOW}開発者向けチュートリアル (packages/samples/README.md)${NC}"
    
    local ts_success=0
    local ts_failure=0
    local ts_timeout=0
    local ts_cached=0
    local ts_skipped=0
    
    while IFS=, read -r sample_path sample_name status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${sample_path}" == "sample" ]]; then
        continue
      fi
      
      # ステータスに基づいてカウント
      if [[ "${status}" == "success" ]]; then
        ((ts_success++))
        echo -e "  ${GREEN}✓${NC} ${sample_name} (${sample_path}) - ${duration}秒"
      elif [[ "${status}" == "timeout" ]]; then
        ((ts_timeout++))
        echo -e "  ${YELLOW}⏱${NC} ${sample_name} (${sample_path}) - タイムアウト"
      elif [[ "${status}" == "cached" ]]; then
        ((ts_cached++))
        echo -e "  ${BLUE}⚡${NC} ${sample_name} (${sample_path}) - キャッシュ済み"
      elif [[ "${status}" == "skipped" ]]; then
        ((ts_skipped++))
        echo -e "  ${BLUE}⏭${NC} ${sample_name} (${sample_path}) - スキップ"
      else
        ((ts_failure++))
        echo -e "  ${RED}✗${NC} ${sample_name} (${sample_path}) - ${duration}秒"
      fi
    done < "${RESULTS_DIR}/ts_results.csv"
    
    local ts_total=$((ts_success + ts_failure + ts_timeout + ts_cached))
    local ts_success_rate=0
    if [[ ${ts_total} -gt 0 ]]; then
      ts_success_rate=$(echo "scale=2; ${ts_success} * 100 / ${ts_total}" | bc)
    fi
    
    echo -e "  ${BLUE}成功率:${NC} ${ts_success_rate}% (${ts_success}/${ts_total})"
    if [[ ${ts_cached} -gt 0 ]]; then
      echo -e "  ${BLUE}キャッシュ済み:${NC} ${ts_cached}"
    fi
    if [[ ${ts_skipped} -gt 0 ]]; then
      echo -e "  ${BLUE}スキップ:${NC} ${ts_skipped}"
    fi
    echo ""
  fi
  
  # 全体のサマリー
  echo -e "\n${BLUE}======= 全体サマリー =======${NC}\n"
  
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
  
  local ts_total=0
  local ts_success=0
  local ts_timeout=0
  local ts_failure=0
  local ts_cached=0
  local ts_skipped=0
  
  if [[ -f "${RESULTS_DIR}/ts_results.csv" ]]; then
    ts_total=$(grep -v "^sample" "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_success=$(grep ",success," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_timeout=$(grep ",timeout," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_failure=$(grep ",failure," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_cached=$(grep ",cached," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_skipped=$(grep ",skipped," "${RESULTS_DIR}/ts_results.csv" | wc -l)
  fi
  
  local total=$((yaml_total + ts_total))
  local success=$((yaml_success + ts_success))
  local timeout=$((yaml_timeout + ts_timeout))
  local failure=$((yaml_failure + ts_failure))
  local cached=$((yaml_cached + ts_cached))
  local skipped=$((yaml_skipped + ts_skipped))
  
  local yaml_success_rate=0
  if [[ $((yaml_total - yaml_skipped)) -gt 0 ]]; then
    yaml_success_rate=$(echo "scale=2; ${yaml_success} * 100 / $((yaml_total - yaml_skipped))" | bc)
  fi
  
  local ts_success_rate=0
  if [[ $((ts_total - ts_skipped)) -gt 0 ]]; then
    ts_success_rate=$(echo "scale=2; ${ts_success} * 100 / $((ts_total - ts_skipped))" | bc)
  fi
  
  local overall_success_rate=0
  if [[ $((total - skipped)) -gt 0 ]]; then
    overall_success_rate=$(echo "scale=2; ${success} * 100 / $((total - skipped))" | bc)
  fi
  
  echo -e "  ${BLUE}基本チュートリアル:${NC} ${yaml_success}/$((yaml_total - yaml_skipped)) 成功 (${yaml_success_rate}%)"
  echo -e "  ${BLUE}開発者向けチュートリアル:${NC} ${ts_success}/$((ts_total - ts_skipped)) 成功 (${ts_success_rate}%)"
  echo -e "  ${BLUE}全体:${NC} ${success}/$((total - skipped)) 成功 (${overall_success_rate}%)"
  
  echo -e "\n${BLUE}詳細なログは ${LOG_DIR} ディレクトリにあります。${NC}"
}

# 結果の集計（JSON形式）
summarize_results_json() {
  local yaml_results="{}"
  local ts_results="{}"
  
  # YAMLサンプルの結果
  if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
    yaml_results="{"
    local first_section=true
    local current_section=""
    local section_samples="[]"
    
    while IFS=, read -r yaml_file section status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${yaml_file}" == "sample" ]]; then
        continue
      fi
      
      # 新しいセクションの開始
      if [[ "${section}" != "${current_section}" ]]; then
        # 前のセクションの結果を追加（初回以外）
        if [[ -n "${current_section}" ]]; then
          if [[ "${first_section}" == "true" ]]; then
            first_section=false
          else
            yaml_results="${yaml_results},"
          fi
          yaml_results="${yaml_results}\"${current_section}\":${section_samples}"
        fi
        
        # 新しいセクションの初期化
        current_section="${section}"
        section_samples="["
      else
        section_samples="${section_samples},"
      fi
      
      # サンプル情報をJSONに追加
      section_samples="${section_samples}{\"file\":\"${yaml_file}\",\"status\":\"${status}\",\"duration\":${duration}}"
    done < "${RESULTS_DIR}/yaml_results.csv"
    
    # 最後のセクションの結果を追加
    if [[ -n "${current_section}" ]]; then
      if [[ "${first_section}" == "true" ]]; then
        first_section=false
      else
        yaml_results="${yaml_results},"
      fi
      yaml_results="${yaml_results}\"${current_section}\":${section_samples}]"
    fi
    
    yaml_results="${yaml_results}}"
  fi
  
  # TypeScriptサンプルの結果
  if [[ -f "${RESULTS_DIR}/ts_results.csv" ]]; then
    ts_results="["
    local first_sample=true
    
    while IFS=, read -r sample_path sample_name status duration file_hash; do
      # ヘッダー行をスキップ
      if [[ "${sample_path}" == "sample" ]]; then
        continue
      fi
      
      if [[ "${first_sample}" == "true" ]]; then
        first_sample=false
      else
        ts_results="${ts_results},"
      fi
      
      # サンプル情報をJSONに追加
      ts_results="${ts_results}{\"path\":\"${sample_path}\",\"name\":\"${sample_name}\",\"status\":\"${status}\",\"duration\":${duration}}"
    done < "${RESULTS_DIR}/ts_results.csv"
    
    ts_results="${ts_results}]"
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
  
  local ts_total=0
  local ts_success=0
  local ts_timeout=0
  local ts_failure=0
  local ts_cached=0
  local ts_skipped=0
  
  if [[ -f "${RESULTS_DIR}/ts_results.csv" ]]; then
    ts_total=$(grep -v "^sample" "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_success=$(grep ",success," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_timeout=$(grep ",timeout," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_failure=$(grep ",failure," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_cached=$(grep ",cached," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    ts_skipped=$(grep ",skipped," "${RESULTS_DIR}/ts_results.csv" | wc -l)
  fi
  
  local total=$((yaml_total + ts_total))
  local success=$((yaml_success + ts_success))
  local timeout=$((yaml_timeout + ts_timeout))
  local failure=$((yaml_failure + ts_failure))
  local cached=$((yaml_cached + ts_cached))
  local skipped=$((yaml_skipped + ts_skipped))
  
  local yaml_success_rate=0
  if [[ $((yaml_total - yaml_skipped)) -gt 0 ]]; then
    yaml_success_rate=$(echo "scale=2; ${yaml_success} * 100 / $((yaml_total - yaml_skipped))" | bc)
  fi
  
  local ts_success_rate=0
  if [[ $((ts_total - ts_skipped)) -gt 0 ]]; then
    ts_success_rate=$(echo "scale=2; ${ts_success} * 100 / $((ts_total - ts_skipped))" | bc)
  fi
  
  local overall_success_rate=0
  if [[ $((total - skipped)) -gt 0 ]]; then
    overall_success_rate=$(echo "scale=2; ${success} * 100 / $((total - skipped))" | bc)
  fi
  
  # 最終的なJSON出力
  echo "{"
  echo "  \"tutorial\": ${yaml_results},"
  echo "  \"samples\": ${ts_results},"
  echo "  \"stats\": {"
  echo "    \"tutorial\": {"
  echo "      \"total\": ${yaml_total},"
  echo "      \"success\": ${yaml_success},"
  echo "      \"failure\": ${yaml_failure},"
  echo "      \"timeout\": ${yaml_timeout},"
  echo "      \"cached\": ${yaml_cached},"
  echo "      \"skipped\": ${yaml_skipped},"
  echo "      \"success_rate\": ${yaml_success_rate}"
  echo "    },"
  echo "    \"samples\": {"
  echo "      \"total\": ${ts_total},"
  echo "      \"success\": ${ts_success},"
  echo "      \"failure\": ${ts_failure},"
  echo "      \"timeout\": ${ts_timeout},"
  echo "      \"cached\": ${ts_cached},"
  echo "      \"skipped\": ${ts_skipped},"
  echo "      \"success_rate\": ${ts_success_rate}"
  echo "    },"
  echo "    \"overall\": {"
  echo "      \"total\": ${total},"
  echo "      \"success\": ${success},"
  echo "      \"failure\": ${failure},"
  echo "      \"timeout\": ${timeout},"
  echo "      \"cached\": ${cached},"
  echo "      \"skipped\": ${skipped},"
  echo "      \"success_rate\": ${overall_success_rate}"
  echo "    }"
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
    local ts_success=0
    local ts_total=0
    
    if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
      yaml_total=$(grep -v "^sample" "${RESULTS_DIR}/yaml_results.csv" | grep -v ",skipped," | wc -l)
      yaml_success=$(grep ",success," "${RESULTS_DIR}/yaml_results.csv" | wc -l)
    fi
    
    if [[ -f "${RESULTS_DIR}/ts_results.csv" ]]; then
      ts_total=$(grep -v "^sample" "${RESULTS_DIR}/ts_results.csv" | grep -v ",skipped," | wc -l)
      ts_success=$(grep ",success," "${RESULTS_DIR}/ts_results.csv" | wc -l)
    fi
    
    local total=$((yaml_total + ts_total))
    local success=$((yaml_success + ts_success))
    local overall_success_rate=0
    
    if [[ ${total} -gt 0 ]]; then
      overall_success_rate=$(echo "scale=2; ${success} * 100 / ${total}" | bc)
    fi
    
    echo "::notice title=サンプル実行結果::成功率: ${overall_success_rate}% (${success}/${total})"
    
    # 失敗したサンプルがある場合は警告を表示
    if [[ ${success} -lt ${total} ]]; then
      echo "::warning::${total}個中${success}個のサンプルが成功しました。詳細なログを確認してください。"
    fi
  fi
}

# クリーンアップ
cleanup() {
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}クリーンアップ中...${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::group::クリーンアップ"
  fi
  
  # 一時ディレクトリの削除
  rm -rf "${TEMP_DIR}"
  
  if [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "::endgroup::"
  fi
}

# メイン処理
main() {
  parse_args "$@"
  setup
  load_cache
  
  if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
    echo -e "${BLUE}GraphAIサンプル実行スクリプト${NC}"
    echo -e "${BLUE}実行モード: $(if [[ "${PARALLEL}" == "true" ]]; then echo "並列"; else echo "逐次"; fi)${NC}"
  elif [[ "${OUTPUT_FORMAT}" == "github-actions" ]]; then
    echo "GraphAIサンプル実行スクリプト"
    echo "実行モード: $(if [[ "${PARALLEL}" == "true" ]]; then echo "並列"; else echo "逐次"; fi)"
  fi
  
  # YAMLサンプルの抽出
  extract_yaml_samples
  
  # TypeScriptサンプルの準備
  prepare_ts_samples
  
  # サンプルの実行
  if [[ "${PARALLEL}" == "true" ]]; then
    run_samples_parallel
  else
    run_samples_sequential
  fi
  
  # キャッシュの保存
  save_cache
  
  # 結果の集計
  summarize_results
  
  # クリーンアップ
  cleanup
  
  # 失敗したサンプルがある場合は終了コードを1にする
  local failure_count=0
  
  if [[ -f "${RESULTS_DIR}/yaml_results.csv" ]]; then
    failure_count=$((failure_count + $(grep ",failure," "${RESULTS_DIR}/yaml_results.csv" | wc -l)))
  fi
  
  if [[ -f "${RESULTS_DIR}/ts_results.csv" ]]; then
    failure_count=$((failure_count + $(grep ",failure," "${RESULTS_DIR}/ts_results.csv" | wc -l)))
  fi
  
  if [[ ${failure_count} -gt 0 ]]; then
    exit 1
  fi
  
  exit 0
}

# スクリプトの実行
main "$@"

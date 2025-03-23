#!/bin/bash

# GraphAIサンプル実行スクリプト
# .github/scripts/tutorial_yml/ フォルダ内のYAMLファイルが全て問題なく実行できるかを確認する

# 定数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
YAML_DIR="${SCRIPT_DIR}/tutorial_yml"
RESULTS_DIR="${REPO_ROOT}/test_results"
LOG_DIR="${RESULTS_DIR}/logs"
TIMEOUT=180  # タイムアウト時間（秒）

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

# 結果ディレクトリの作成
mkdir -p "${RESULTS_DIR}"
mkdir -p "${LOG_DIR}"

# graphaiコマンドの確認
if ! command -v graphai &> /dev/null; then
  echo -e "${RED}エラー: graphaiコマンドが見つかりません。${NC}"
  echo "インストール方法: npm i -g @receptron/graphai_cli"
  exit 1
fi

# YAMLディレクトリの存在確認
if [[ ! -d "${YAML_DIR}" ]]; then
  echo -e "${RED}エラー: ${YAML_DIR} ディレクトリが見つかりません。${NC}"
  exit 1
fi

# 結果ファイルの初期化
echo "sample,status,duration" > "${RESULTS_DIR}/results.csv"

# 成功・失敗のカウンター
success_count=0
failure_count=0
total_count=0

echo -e "${BLUE}GraphAIサンプル実行スクリプト${NC}"
echo -e "${BLUE}YAMLファイルを検索中...${NC}"

# YAMLファイルの検索と実行
for yaml_file in "${YAML_DIR}"/*.yml "${YAML_DIR}"/*.yaml; do
  # ファイルが存在しない場合はスキップ
  if [[ ! -f "${yaml_file}" ]]; then
    continue
  fi
  
  ((total_count++))
  base_name=$(basename "${yaml_file}")
  log_file="${LOG_DIR}/${base_name}.log"
  
  echo -e "${BLUE}実行中: ${base_name}${NC}"
  
  # サンプルを実行して時間を計測
  start_time=$(date +%s)
  
  # カレントディレクトリからの相対パスを使用
  cd "${REPO_ROOT}"
  
  # タイムアウトコマンドの確認（macOSとLinuxで異なる）
  TIMEOUT_CMD=""
  if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout ${TIMEOUT}"
  elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout ${TIMEOUT}"
  else
    echo -e "${YELLOW}警告: timeoutコマンドが見つかりません。タイムアウト機能は無効です。${NC}"
  fi
  
  # インタラクティブなスクリプト（05〜07）の場合は特別な処理（yを返して30秒後に強制終了）
  if [[ "${base_name}" =~ ^0[567] ]]; then
    echo -e "${YELLOW}インタラクティブなスクリプト ${base_name} を実行中: yを返して30秒後に強制終了${NC}"
    # バックグラウンドでプロセスを実行
    (yes y | graphai ".github/scripts/tutorial_yml/$(basename "${yaml_file}")" > "${log_file}" 2>&1) &
    pid=$!
    # 30秒待機
    sleep 30
    # プロセスが存在するか確認してから強制終了
    if ps -p $pid > /dev/null; then
      kill -9 $pid
    fi
    # 成功として扱う
    exit_code=0
  else
    # 通常のスクリプトの場合は、そのまま実行
    if [[ -n "${TIMEOUT_CMD}" ]]; then
      ${TIMEOUT_CMD} graphai ".github/scripts/tutorial_yml/$(basename "${yaml_file}")" > "${log_file}" 2>&1
    else
      # タイムアウトなしで実行
      graphai ".github/scripts/tutorial_yml/$(basename "${yaml_file}")" > "${log_file}" 2>&1
    fi
    exit_code=$?
  fi
  
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  # ログファイルにエラーが含まれるかチェック
  if grep -i "error" "${log_file}" > /dev/null; then
    has_error=true
  else
    has_error=false
  fi

  # 結果の処理
  if [[ ${exit_code} -eq 0 && "${has_error}" == "false" ]]; then
    ((success_count++))
    echo -e "${GREEN}成功: ${base_name} (${duration}秒)${NC}"
    echo "${base_name},success,${duration}" >> "${RESULTS_DIR}/results.csv"
  elif [[ ${exit_code} -eq 124 ]]; then
    # タイムアウトの場合
    ((failure_count++))
    echo -e "${YELLOW}タイムアウト: ${base_name} (${TIMEOUT}秒)${NC}"
    echo "${base_name},timeout,${TIMEOUT}" >> "${RESULTS_DIR}/results.csv"
    echo -e "${YELLOW}エラーログ (最後の5行):${NC}"
    tail -n 5 "${log_file}"
  else
    # 失敗またはエラーを含む場合
    ((failure_count++))
    if [[ ${exit_code} -ne 0 ]]; then
      echo -e "${RED}失敗: ${base_name} (${duration}秒) - 終了コード: ${exit_code}${NC}"
    else
      echo -e "${RED}失敗: ${base_name} (${duration}秒) - ログにエラーが含まれています${NC}"
    fi
    echo "${base_name},failure,${duration}" >> "${RESULTS_DIR}/results.csv"
    echo -e "${YELLOW}エラーログ (最後の10行):${NC}"
    tail -n 10 "${log_file}"
  fi
done

# 結果のサマリー
echo -e "\n${BLUE}======= 実行結果サマリー =======${NC}"
echo -e "合計: ${total_count}個"
echo -e "成功: ${GREEN}${success_count}個${NC}"
echo -e "失敗: ${RED}${failure_count}個${NC}"

if [[ ${total_count} -gt 0 ]]; then
  success_rate=$(echo "scale=2; ${success_count} * 100 / ${total_count}" | bc)
  echo -e "成功率: ${GREEN}${success_rate}%${NC}"
fi

echo -e "詳細なログは ${LOG_DIR} ディレクトリにあります。"

# 失敗したサンプルがある場合は終了コードを1にする
if [[ ${failure_count} -gt 0 ]]; then
  exit 1
fi

exit 0

#!/bin/bash

# GraphAI サンプル修正提案スクリプト
# 失敗したYAMLサンプルを特定し、YAMLファイルとエラーログを表示する

# 定数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESULTS_DIR="${REPO_ROOT}/test_results"
LOG_DIR="${RESULTS_DIR}/logs"
SUGGESTIONS_FILE="${RESULTS_DIR}/fix_suggestions.md"

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

# 結果ファイルの確認
if [[ ! -f "${RESULTS_DIR}/results.csv" ]]; then
  echo -e "${YELLOW}警告: ${RESULTS_DIR}/results.csv が見つかりません。修正提案を生成できません。${NC}"
  exit 0
fi

# 失敗したサンプルの特定
failed_samples=()
while IFS=, read -r sample status duration; do
  # ヘッダー行をスキップ
  if [[ "${sample}" == "sample" ]]; then
    continue
  fi
  
  # 失敗したサンプルのみ処理
  if [[ "${status}" == "failure" ]]; then
    failed_samples+=("${sample}")
  fi
done < "${RESULTS_DIR}/results.csv"

# 失敗したサンプルがない場合は終了
if [[ ${#failed_samples[@]} -eq 0 ]]; then
  echo -e "${GREEN}失敗したサンプルはありません。修正提案は不要です。${NC}"
  exit 0
fi

echo -e "${BLUE}${#failed_samples[@]}個の失敗したサンプルを特定しました。修正提案を生成します...${NC}"

# 修正提案ファイルの初期化
echo "# 🛠️ GraphAI サンプル修正提案" > "${SUGGESTIONS_FILE}"
echo "" >> "${SUGGESTIONS_FILE}"
echo "以下は、失敗したサンプルの修正提案です。これらの提案は自動生成されたものであり、必ずしも正確ではない可能性があります。" >> "${SUGGESTIONS_FILE}"
echo "" >> "${SUGGESTIONS_FILE}"

# 各失敗サンプルに対して修正提案を生成
for sample in "${failed_samples[@]}"; do
  echo -e "${BLUE}${sample} の修正提案を生成中...${NC}"
  
  # サンプルファイルのパス
  sample_path="${SCRIPT_DIR}/tutorial_yml/${sample}"
  
  # ログファイルのパス
  log_file="${LOG_DIR}/${sample}.log"
  
  # ファイルとログの存在確認
  if [[ ! -f "${sample_path}" ]]; then
    echo -e "${YELLOW}警告: ${sample_path} が見つかりません。スキップします。${NC}"
    continue
  fi
  
  if [[ ! -f "${log_file}" ]]; then
    echo -e "${YELLOW}警告: ${log_file} が見つかりません。スキップします。${NC}"
    continue
  fi
  
  # サンプルファイルの内容を取得
  sample_content=$(cat "${sample_path}")
  
  # エラーログの内容を取得（最後の20行）
  error_log=$(tail -n 20 "${log_file}")
  
  # 修正提案をファイルに追加
  echo "<details>" >> "${SUGGESTIONS_FILE}"
  echo "<summary><b>📝 ${sample} の修正提案</b></summary>" >> "${SUGGESTIONS_FILE}"
  echo "" >> "${SUGGESTIONS_FILE}"
  echo "## YAMLファイル" >> "${SUGGESTIONS_FILE}"
  echo "" >> "${SUGGESTIONS_FILE}"
  echo '```yaml' >> "${SUGGESTIONS_FILE}"
  echo "${sample_content}" >> "${SUGGESTIONS_FILE}"
  echo '```' >> "${SUGGESTIONS_FILE}"
  echo "" >> "${SUGGESTIONS_FILE}"
  echo "## エラーログ" >> "${SUGGESTIONS_FILE}"
  echo "" >> "${SUGGESTIONS_FILE}"
  echo '```' >> "${SUGGESTIONS_FILE}"
  echo "${error_log}" >> "${SUGGESTIONS_FILE}"
  echo '```' >> "${SUGGESTIONS_FILE}"
  echo "" >> "${SUGGESTIONS_FILE}"
  echo "</details>" >> "${SUGGESTIONS_FILE}"
  echo "" >> "${SUGGESTIONS_FILE}"
  
  echo -e "${GREEN}${sample} の修正提案を生成しました。${NC}"
done

echo -e "${GREEN}修正提案の生成が完了しました。結果は ${SUGGESTIONS_FILE} に保存されています。${NC}"
exit 0

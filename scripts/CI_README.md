# GraphAI CI Workflow

このディレクトリには、GraphAIのCIワークフローを実行するためのスクリプトが含まれています。

## CI ワークフローの概要

このCIワークフローは、PRが作成または更新されたときに実行され、以下の処理を行います：

1. すべてのサンプルコードを実行
2. 実行結果のレポートを生成
3. 仕様変更によるエラーが発生したサンプルを検出
4. LLMを使用して、エラーが発生したサンプルの修正案を生成
5. レポートと修正案をPRコメントとして追加

## 使用方法

### CI環境での実行

GitHub Actionsなどのワークフローで実行する場合：

```yaml
name: GraphAI Sample Tests

on:
  pull_request:
    branches: [ main ]
    paths:
      - 'packages/**'
      - '.github/workflows/sample-tests.yml'

jobs:
  test-samples:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: npm install
        
      - name: Run CI workflow
        run: |
          ./scripts/ci_workflow.sh \
            --pr-number ${{ github.event.pull_request.number }} \
            --repo-owner ${{ github.repository_owner }} \
            --repo-name ${{ github.repository.name }} \
            --openai-api-key ${{ secrets.OPENAI_API_KEY }}
            
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: reports
          path: artifacts/
```

### 手動実行

ローカル環境で手動実行する場合：

```bash
./scripts/ci_workflow.sh \
  --pr-number <PR番号> \
  --repo-owner <リポジトリオーナー> \
  --repo-name <リポジトリ名> \
  --openai-api-key <OpenAI APIキー>
```

## パラメータ

- `--pr-number` - PRの番号（必須）
- `--repo-owner` - リポジトリのオーナー（必須）
- `--repo-name` - リポジトリ名（必須）
- `--openai-api-key` - OpenAI APIキー（修正案生成に必要）

## 出力ファイル

- `sample_execution_report.md` - サンプル実行の詳細レポート
- `graphai_samples_report.md` - サンプル実行の要約レポート
- `failed_samples.txt` - 失敗したサンプルのリスト
- `fix_proposals.md` - 失敗したサンプルの修正案
- `pr_comment.md` - PRに投稿するコメントの内容

## 注意事項

- このスクリプトは `gh` CLIツールを使用してGitHubと通信します
- 修正案の生成にはOpenAI APIキーが必要です
- 実行には `jq` コマンドが必要です（JSONの処理に使用）

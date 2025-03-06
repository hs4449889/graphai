# GraphAI Sample Execution Scripts

このディレクトリには、GraphAIのサンプルを実行し、その結果をレポートするためのスクリプトが含まれています。

## スクリプトの概要

1. `run_samples.sh` - GraphAIのサンプルを実行し、実行結果を記録するスクリプト
2. `generate_report.sh` - 実行結果からMarkdownレポートを生成するスクリプト
3. `test_run_samples.sh` - サンプル実行スクリプトのテスト用スクリプト

## 使用方法

### サンプル実行

すべてのサンプルを実行し、レポートを生成するには：

```bash
./scripts/run_samples.sh
```

このスクリプトは以下の処理を行います：

1. GraphAIのYAMLサンプルを実行
2. GraphAIのTypeScriptサンプルを実行
3. 実行結果を `sample_execution_report.md` に記録
4. 最終レポートを `graphai_samples_report.md` に生成

### 注意事項

- サンプル実行には各種APIキー（OpenAI、Groq、Anthropicなど）が必要です
- APIキーは `.env` ファイルに設定する必要があります
- APIキーが設定されていない場合、ダミーのAPIキーが使用され、APIリクエストは失敗します

### .env ファイルの例

```
OPENAI_API_KEY=your_openai_api_key
GROQ_API_KEY=your_groq_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
GOOGLE_API_KEY=your_google_api_key
```

## レポート形式

生成されるレポートには以下の情報が含まれます：

1. 実行サンプルの総数
2. 成功したサンプルの数と一覧
3. 失敗したサンプルの数と一覧（エラーメッセージ付き）
4. タイムアウトしたサンプルの数と一覧
5. 各サンプルの詳細な実行結果

## カスタマイズ

スクリプト内の以下の変数を変更することで、動作をカスタマイズできます：

- `MAX_EXECUTION_TIME` - サンプル実行の最大時間（秒）
- `REPORT_FILE` - 実行結果の記録ファイル名
- `FINAL_REPORT` - 最終レポートのファイル名

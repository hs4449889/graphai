# GraphAI サンプル実行・テスト自動化スクリプト

このディレクトリには、GraphAIのサンプルコードを実行し、テストするための自動化スクリプト群が含まれています。

## スクリプト一覧

1. **サンプル実行スクリプト**
   - `run_samples.sh` - すべてのGraphAIサンプルを実行し、結果を記録
   - `test_run_samples.sh` - サンプル実行スクリプトのテスト用バージョン
   - `generate_report.md` - 実行結果からMarkdownレポートを生成

2. **CI/CD ワークフロースクリプト**
   - `ci_workflow.sh` - CI環境でサンプルを実行し、結果をPRコメントとして投稿
   - `fix_sample.sh` - 失敗したサンプルの修正案を生成

3. **GitHub Actions ワークフロー**
   - `.github/workflows/sample-tests.yml` - PRが作成/更新されたときに自動実行

## 主な機能

### サンプル実行の自動化

- YAMLおよびTypeScriptサンプルの自動実行
- 実行結果のMarkdownレポート生成
- タイムアウト処理によるハングアップ防止
- エラーハンドリングと詳細なログ記録

### CI/CD ワークフロー

- PRが作成/更新されたときに自動実行
- すべてのサンプルコードの実行と結果レポート
- 仕様変更によるエラーが発生したサンプルの検出
- LLMを使用した修正案の自動生成
- レポートと修正案のPRコメント投稿

## 使用方法

### サンプル実行

```bash
# すべてのサンプルを実行
./scripts/run_samples.sh

# テスト用に一部のサンプルのみ実行
./scripts/test_run_samples.sh
```

### CI/CD ワークフロー

```bash
# CI環境での実行
./scripts/ci_workflow.sh \
  --pr-number <PR番号> \
  --repo-owner <リポジトリオーナー> \
  --repo-name <リポジトリ名> \
  --openai-api-key <OpenAI APIキー>

# 特定のサンプルの修正案生成
./scripts/fix_sample.sh \
  --sample <サンプルファイルパス> \
  --openai-api-key <OpenAI APIキー> \
  --pr-diff <PRのdiffファイル> \
  --pr-description <PR説明ファイル>
```

## 詳細情報

各スクリプトの詳細な使用方法については、以下のREADMEファイルを参照してください：

- [サンプル実行スクリプト README](./README.md)
- [CI/CD ワークフロー README](./CI_README.md)

## 注意事項

- サンプル実行には各種APIキー（OpenAI、Groq、Anthropicなど）が必要です
- APIキーは `.env` ファイルに設定する必要があります
- CI/CDワークフローでは、OpenAI APIキーが修正案生成に必要です

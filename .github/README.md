# GitHub Actions ワークフロー

このディレクトリには、Supabaseの自動デプロイメント用のGitHub Actionsワークフローが含まれています。

## ワークフロー

### 1. `supabase-migration.yml`
- **トリガー**: `main`ブランチへのプッシュ、または`supabase/migrations/`の変更
- **処理**: Supabaseデータベースマイグレーションを自動実行
- **実行タイミング**: mainブランチにマージされた時、または手動実行

### 2. `supabase-functions.yml`
- **トリガー**: `main`ブランチへのプッシュ、または`supabase/functions/`の変更
- **処理**: Supabase Edge Functionsを自動デプロイ
- **実行タイミング**: mainブランチにマージされた時、または手動実行

## 必要なGitHub Secrets

以下のシークレットをGitHubリポジトリのSettings > Secrets and variables > Actionsに設定してください：

### 必須シークレット

1. **`SUPABASE_ACCESS_TOKEN`**
   - Supabase CLIの認証用トークン
   - 取得方法：
     1. [Supabase Dashboard](https://app.supabase.com/)にログイン
     2. アカウント設定 > Access Tokens に移動
     3. 新しいトークンを作成
     4. トークンをコピーしてGitHub Secretsに追加

2. **`SUPABASE_PROJECT_REF`**
   - Supabaseプロジェクトの参照ID
   - 取得方法：
     1. Supabase Dashboardでプロジェクトを開く
     2. プロジェクト設定 > General に移動
     3. Reference IDをコピー（例: `mvfcaafiehakuknqaqow`）
     4. GitHub Secretsに追加

### オプションシークレット

3. **`RAKUTEN_APPLICATION_ID`** (オプション)
   - Edge Functionsで使用する楽天APIのアプリケーションID
   - `rakuten-books`関数で使用されます
   - 設定しない場合、Edge Functionsのデプロイは実行されますが、シークレットの設定はスキップされます

## シークレットの設定手順

1. GitHubリポジトリのページに移動
2. **Settings** > **Secrets and variables** > **Actions** を開く
3. **New repository secret** をクリック
4. 各シークレットを追加：
   - Name: `SUPABASE_ACCESS_TOKEN`
   - Secret: （Supabase Dashboardから取得したトークン）
5. 同様に他のシークレットも追加

## ワークフローの実行

### 自動実行
- `main`ブランチに`supabase/migrations/`の変更がマージされると、マイグレーションワークフローが自動実行されます
- `main`ブランチに`supabase/functions/`の変更がマージされると、Edge Functionsワークフローが自動実行されます

### 手動実行
1. GitHubリポジトリの**Actions**タブを開く
2. 実行したいワークフローを選択
3. **Run workflow**ボタンをクリック
4. ブランチを選択して実行

## トラブルシューティング

### マイグレーションが失敗する場合
- `SUPABASE_ACCESS_TOKEN`が正しく設定されているか確認
- `SUPABASE_PROJECT_REF`が正しいプロジェクト参照IDか確認
- Supabase Dashboardでマイグレーション履歴を確認

### Edge Functionsのデプロイが失敗する場合
- `SUPABASE_ACCESS_TOKEN`が正しく設定されているか確認
- Edge Functionsのコードに構文エラーがないか確認
- ローカルで`supabase functions deploy rakuten-books`を実行してテスト

## セキュリティに関する注意

- シークレットは絶対にコードにコミットしないでください
- シークレットは定期的にローテーションすることを推奨します
- 必要最小限の権限を持つトークンを使用してください


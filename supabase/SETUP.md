# Supabase IaC セットアップガイド

このプロジェクトはSupabase CLIを使用してInfrastructure as Code (IaC)で管理されています。

## 前提条件

- Supabase CLIがインストールされていること
  ```bash
  # macOS
  brew install supabase/tap/supabase
  
  # その他のプラットフォーム
  # https://supabase.com/docs/guides/cli/getting-started を参照
  ```

## セットアップ手順

### 1. 既存のSupabaseプロジェクトとリンク

既存のSupabaseプロジェクトがある場合：

```bash
cd supabase
supabase link --project-ref your-project-ref
```

プロジェクト参照IDは、Supabaseダッシュボードのプロジェクト設定から取得できます。

### 2. ローカル開発環境の起動（オプション）

ローカルでSupabaseを起動して開発できます：

```bash
cd supabase
supabase start
```

これにより、以下のサービスが利用可能になります：
- API: http://localhost:54321
- Studio: http://localhost:54323
- Inbucket (Email): http://localhost:54324

### 3. マイグレーションの適用

#### 既存プロジェクトに適用する場合

```bash
cd supabase
supabase db push
```

#### ローカル環境に適用する場合

```bash
cd supabase
supabase migration up
```

### 4. Edge Functionsのデプロイ

```bash
cd supabase
supabase functions deploy rakuten-books
```

環境変数を設定する場合：

```bash
supabase secrets set RAKUTEN_APPLICATION_ID=your_rakuten_application_id
```

### 5. メールテンプレートの設定

メールテンプレートは`email_templates/`ディレクトリに保存されています。
Supabaseダッシュボードで設定する場合：

1. **Authentication > Templates**に移動
2. 対象テンプレート（Sign up / Magic link）の本文を、それぞれのHTMLファイルの内容で置き換え
3. 件名欄にファイル先頭の`Subject:`コメントの文言を設定

詳細は`email_templates/README.md`を参照してください。

## トラブルシューティング

### マイグレーションエラーが発生する場合

既存のデータベースにスキーマが存在する場合、マイグレーションファイルの`create table if not exists`により、エラーなく適用されます。

### ローカル環境が起動しない場合

```bash
cd supabase
supabase stop
supabase start
```

### 既存のデータベースからマイグレーションを抽出する場合

```bash
cd supabase
supabase db pull
```

これにより、既存のデータベーススキーマがマイグレーションファイルとして抽出されます。

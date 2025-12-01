# Book Memoly

読書ログ + メモアプリ

## 🎯 アプリ概要

- 書籍の検索（楽天ブックス API / Supabase Edge Functions 経由）
- 書籍の保存（未読 / 読書中 / 読了）
- 読書メモ（CRUD）
- アクションプラン（メモから抽出）
- 読書スピード記録
- 書籍 / メモ検索
- SupabaseとローカルDB（drift）の同期

- Supabase Edge Functions の楽天ブックス検索では `keyword` パラメータによる部分一致検索をデフォルトとし、ヒットしなかった場合は `title` 検索へフォールバックします。
- 全角スペース縮約やISBNのハイフン除去などを関数側で行うため、ユーザー入力の揺れを気にせず検索できます。
- 著者名と思われるクエリ（例：村上春樹）は自動的に `author` パラメータを使って検索し、ノイズを抑えています。
- オンライン検索は楽天 API の上限である1ページ最大30件まで取得でき、スクロールすると次ページを自動で読み込みます。

## 🏗 技術スタック

- Flutter 3.x
- Riverpod / hooks_riverpod
- go_router
- dio
- freezed / json_serializable
- drift（ローカルDB）
- supabase_flutter（バックアップ & 同期）

## 📁 ディレクトリ構成

```
lib/
├── core/           # コア機能（データベース、モデル、サービス、ユーティリティ）
├── features/       # 機能別モジュール
│   ├── books/
│   ├── memos/
│   ├── action_plans/
│   ├── reading_speed/
│   └── search/
└── shared/         # 共通ウィジェット、定数
```

## 🚀 セットアップ

### 1. Flutterプロジェクトの初期化（初回のみ）

このプロジェクトは基本的な構造が作成済みですが、Android/iOSのプラットフォーム固有のファイルが必要な場合は以下を実行：

```bash
flutter create . --org com.bookmemoly --project-name book_memoly_app
```

### 2. 依存関係のインストール

```bash
flutter pub get
```

### 2.5 Supabase の設定

Supabase の URL と anon key はリポジトリに含めず、`.env`ファイルに定義してください。

#### `.env`ファイルの作成

プロジェクトルートに`.env.example`をコピーして`.env`ファイルを作成し、実際の値を設定してください：

```bash
cp .env.example .env
# .envファイルを編集して実際の値を設定
```

`.env`ファイルには以下の設定が必要です：

```bash
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_REDIRECT_URL=com.bookmemoly.app://  # メール認証用のリダイレクトURL
RAKUTEN_APPLICATION_ID=your_rakuten_application_id  # Edge Functions用
```

**重要**: `SUPABASE_REDIRECT_URL`はメール認証リンクがアプリにリダイレクトされるために必要です。モバイルアプリではカスタムURLスキーム（`com.bookmemoly.app://`）を設定してください。

**注意**: `.env`ファイルは`.gitignore`に含まれているため、リポジトリにはコミットされません。

#### Supabase CLI のセットアップ

このプロジェクトはSupabase CLIを使用してInfrastructure as Code (IaC)で管理されています。

##### Supabase CLI のインストール

```bash
# macOS
brew install supabase/tap/supabase

# その他のプラットフォーム
# https://supabase.com/docs/guides/cli/getting-started を参照
```

##### 既存プロジェクトとのリンク

既存のSupabaseプロジェクトがある場合、リンクします：

```bash
cd supabase
supabase link --project-ref your-project-ref
```

プロジェクト参照IDは、Supabaseダッシュボードのプロジェクト設定から取得できます。

##### ローカル開発環境の起動

ローカルでSupabaseを起動して開発できます：

```bash
cd supabase
supabase start
```

これにより、ローカルのSupabaseインスタンスが起動し、以下のサービスが利用可能になります：
- API: http://localhost:54321
- Studio: http://localhost:54323
- Inbucket (Email): http://localhost:54324

##### データベースマイグレーションの適用

既存のSupabaseプロジェクトにマイグレーションを適用する場合：

```bash
cd supabase
supabase db push
```

ローカル環境にマイグレーションを適用する場合（`supabase start`後）：

```bash
cd supabase
supabase migration up
```

##### 既存データベースからマイグレーションを抽出

既存のSupabaseプロジェクトからスキーマを抽出してマイグレーションを作成する場合：

```bash
cd supabase
supabase db pull
```

##### Edge Functions のデプロイ

Edge Functionsをデプロイする場合：

```bash
cd supabase
supabase functions deploy rakuten-books
```

環境変数を設定する場合：

```bash
supabase secrets set RAKUTEN_APPLICATION_ID=your_rakuten_application_id
```

##### メールテンプレートの設定

メールテンプレートは`supabase/email_templates/`に保存されています。Supabaseダッシュボードで設定する場合：

1. **Authentication > Templates**に移動
2. 対象テンプレート（Sign up / Magic link）の本文を、それぞれのHTMLファイルの内容で置き換え
3. 件名欄にファイル先頭の`Subject:`コメントの文言を設定

詳細は`supabase/email_templates/README.md`を参照してください。

#### Supabaseダッシュボードの設定（IaC未使用の場合）

メール認証を正しく動作させるため、Supabaseダッシュボードで以下を設定してください：

1. **認証 > URL設定**に移動
2. **リダイレクトURL**に以下を追加：
   ```
   com.bookmemoly.app://
   com.bookmemoly.app://login-callback
   com.bookmemoly.app://auth/callback
   ```
3. **サイトURL**を確認：
   - モバイルアプリのみを使用する場合: `com.bookmemoly.app://` または空欄
   - Webアプリも使用する場合: WebアプリのURL（例: `https://yourdomain.com`）
   - ⚠️ `localhost:3000`が設定されている場合、メール認証リンクが`localhost:3000`にリダイレクトされます

**注意**: `supabase/config.toml`で認証設定を管理している場合、`supabase db push`で設定を適用できます。

**トラブルシューティング**: メール認証リンクが`localhost:3000`にリダイレクトする場合は、`supabase/config.toml`の`site_url`と`additional_redirect_urls`を確認してください。

#### アプリの実行

`.env`ファイルを読み込んでアプリを実行するには、`run.sh`スクリプトを使用してください：

```bash
./run.sh
```

または、通常の`flutter run`コマンドに追加の引数を渡すこともできます：

```bash
./run.sh -d chrome
./run.sh -d macos
```

手動で`--dart-define`を指定する場合：

```bash
flutter run \
  --dart-define=SUPABASE_URL=your_project_url \
  --dart-define=SUPABASE_ANON_KEY=your_public_anon_key
```

アプリ起動時に Supabase を初期化し、`health_checks` テーブルへの軽量なクエリで API 応答を確認します。

本番ビルドでも同様に `--dart-define` で値を渡します。CI などで秘密情報として保持し、ビルドコマンドに注入してください（例）。

```bash
# Android AppBundle
flutter build appbundle \
  --dart-define=SUPABASE_URL=your_project_url \
  --dart-define=SUPABASE_ANON_KEY=your_public_anon_key

# iOS Archive
flutter build ipa \
  --dart-define=SUPABASE_URL=your_project_url \
  --dart-define=SUPABASE_ANON_KEY=your_public_anon_key
```

`flutter build` は `--dart-define-from-file` もサポートするため、CI では一時ファイルにシークレットを書き出して指定しても構いません。

```bash
cat > /tmp/supabase.env <<'EOF'
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_public_anon_key
EOF

flutter build appbundle --dart-define-from-file=/tmp/supabase.env
```

### 3. コード生成

FreezedとDriftのコード生成を実行：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. アプリの実行

```bash
flutter run
```

## 📝 開発メモ

### Flutter開発

- コード生成が必要なファイルを変更した場合は、`flutter pub run build_runner build --delete-conflicting-outputs` を実行してください
- ウォッチモードで自動生成する場合: `flutter pub run build_runner watch`
- 生成されるファイル（`*.g.dart`, `*.freezed.dart`, `*.drift.dart`）は`.gitignore`に含まれています

### Supabase開発

- データベーススキーマの変更は`supabase/migrations/`ディレクトリにマイグレーションファイルとして追加してください
- 新しいマイグレーションを作成する場合: `cd supabase && supabase migration new migration_name`
- ローカル環境でマイグレーションをテストする場合: `cd supabase && supabase start && supabase migration up`
- Edge Functionsは`supabase/functions/`ディレクトリに配置されています
- ローカルでEdge Functionsをテストする場合: `cd supabase && supabase functions serve rakuten-books`
- 詳細なセットアップ手順は`supabase/SETUP.md`を参照してください

### CI/CD (GitHub Actions)

- `main`ブランチにマージされると、SupabaseマイグレーションとEdge Functionsが自動デプロイされます
- **初回セットアップ**: 必要なGitHub Secretsの設定方法は`.github/SECRETS_SETUP.md`を参照してください
- ワークフローファイル:
  - `.github/workflows/supabase-migration.yml`: データベースマイグレーション
  - `.github/workflows/supabase-functions.yml`: Edge Functionsデプロイ
- 詳細は`.github/README.md`を参照してください

## ✅ 受け入れ条件

- ✅ プロジェクトが起動すること
- ✅ Freezed / Drift コード生成が成功すること

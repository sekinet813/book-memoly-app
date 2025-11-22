# Book Memoly App

読書ログ + メモアプリ

## 🎯 アプリ概要

- 書籍の検索（Google Books API）
- 書籍の保存（未読 / 読書中 / 読了）
- 読書メモ（CRUD）
- アクションプラン（メモから抽出）
- 読書スピード記録
- 書籍 / メモ検索
- SupabaseとローカルDB（drift）の同期

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

Supabase の URL と anon key はリポジトリに含めず、起動時に `--dart-define` で注入してください。

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

- コード生成が必要なファイルを変更した場合は、`flutter pub run build_runner build --delete-conflicting-outputs` を実行してください
- ウォッチモードで自動生成する場合: `flutter pub run build_runner watch`
- 生成されるファイル（`*.g.dart`, `*.freezed.dart`, `*.drift.dart`）は`.gitignore`に含まれています

## ✅ 受け入れ条件

- ✅ プロジェクトが起動すること
- ✅ Freezed / Drift コード生成が成功すること

# Supabase 認証メールテンプレート

Supabase ダッシュボードの **Authentication > Templates** で、以下の内容をコピー＆ペーストして利用できます。
件名はファイル先頭の `Subject` コメントを使用してください。

## ファイル構成
- `signup_confirmation.html`: 新規登録時の確認メール。メールアドレス確認リンク用。
- `login_magic_link.html`: ログイン用リンクメール。

## 変数について
Supabase で使用できる GoTrue のテンプレート変数を利用しています。
主に以下を差し替えます。

- `{{ .Email }}`: 送信先のメールアドレス
- `{{ .ConfirmationURL }}`: メール内の認証/ログインリンク
- `{{ .SiteURL }}`: プロジェクトに設定しているサイトURL

## 使い方
1. Supabase ダッシュボードで **Authentication > Templates** を開きます。
2. 対象テンプレート（Sign up / Magic link）の本文を、それぞれの HTML ファイルの内容で置き換えます。
3. 件名欄に `Subject:` 行の文言を設定します（例: `Book Memoly | 新規登録のご案内`）。
4. テンプレートを保存し、テストメールで表示を確認してください。

これらのテンプレートはモバイルアプリを想定し、リンクをクリックした際に設定済みのリダイレクトURLへ遷移する前提になっています。

# GitHub Secrets セットアップガイド

このプロジェクトのGitHub Actionsワークフローを実行するには、以下のシークレットを設定する必要があります。

## 必要なシークレット

### 1. SUPABASE_ACCESS_TOKEN

Supabase CLIの認証用トークンです。

#### 取得方法

1. [Supabase Dashboard](https://app.supabase.com/)にログイン
2. 右上のアカウントアイコンをクリック
3. **Account Settings** > **Access Tokens** に移動
4. **Generate new token** をクリック
5. トークンに名前を付けて（例: "GitHub Actions"）生成
6. 表示されたトークンをコピー（一度しか表示されないので注意）

#### GitHub Secretsへの追加

1. GitHubリポジトリのページに移動
2. **Settings** > **Secrets and variables** > **Actions** を開く
3. **New repository secret** をクリック
4. Name: `SUPABASE_ACCESS_TOKEN`
5. Secret: （コピーしたトークンを貼り付け）
6. **Add secret** をクリック

### 2. SUPABASE_PROJECT_REF

Supabaseプロジェクトの参照IDです。

#### 取得方法

1. [Supabase Dashboard](https://app.supabase.com/)でプロジェクトを開く
2. 左サイドバーの **Settings** (歯車アイコン) をクリック
3. **General** タブを開く
4. **Reference ID** をコピー（例: `mvfcaafiehakuknqaqow`）

または、プロジェクトのURLから取得：
- URL: `https://app.supabase.com/project/mvfcaafiehakuknqaqow`
- この場合、`mvfcaafiehakuknqaqow`がプロジェクト参照IDです

#### GitHub Secretsへの追加

1. **New repository secret** をクリック
2. Name: `SUPABASE_PROJECT_REF`
3. Secret: （プロジェクト参照IDを貼り付け）
4. **Add secret** をクリック

### 3. RAKUTEN_APPLICATION_ID (オプション)

Edge Functionsで使用する楽天APIのアプリケーションIDです。
設定しない場合、Edge Functionsのデプロイは実行されますが、シークレットの設定はスキップされます。

#### 取得方法

1. [楽天アフィリエイト](https://affiliate.rakuten.co.jp/)にログイン
2. **アプリ登録** から新しいアプリケーションIDを取得

#### GitHub Secretsへの追加

1. **New repository secret** をクリック
2. Name: `RAKUTEN_APPLICATION_ID`
3. Secret: （楽天アプリケーションIDを貼り付け）
4. **Add secret** をクリック

## シークレットの確認

設定したシークレットは、GitHubリポジトリの **Settings** > **Secrets and variables** > **Actions** で確認できます。

## トラブルシューティング

### ワークフローが失敗する場合

1. シークレットが正しく設定されているか確認
2. `SUPABASE_ACCESS_TOKEN`が有効か確認（期限切れの可能性）
3. `SUPABASE_PROJECT_REF`が正しいプロジェクトを指しているか確認
4. GitHub Actionsのログを確認してエラーメッセージを確認

### トークンの権限

Supabase Access Tokenには、プロジェクトへの読み書き権限が必要です。
トークンを作成する際に、適切な権限が付与されているか確認してください。

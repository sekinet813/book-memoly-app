# アーカイブされたSQLファイル

このディレクトリにあった以下のSQLファイルは、Supabase CLIのマイグレーション形式に変換されました：

- `goals_table.sql` → `migrations/20240101000040_create_goals_table.sql`
- `notes_search.sql` → `migrations/20240101000070_add_notes_search.sql`

これらのファイルは、マイグレーションファイルに統合されたため、削除またはアーカイブできます。

## マイグレーションの適用方法

既存のSupabaseプロジェクトにマイグレーションを適用する場合：

```bash
cd supabase
supabase link --project-ref your-project-ref
supabase db push
```

ローカル環境でテストする場合：

```bash
cd supabase
supabase start
supabase migration up
```


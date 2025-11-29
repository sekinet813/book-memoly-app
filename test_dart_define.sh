#!/bin/bash
set -a
source .env
set +a
echo "Testing dart-define:"
echo "--dart-define=SUPABASE_URL=$SUPABASE_URL"
echo "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:0:20}..."

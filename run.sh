#!/bin/bash

# Script to run Flutter app with Supabase configuration from .env file

set -e  # Exit on error

# Load environment variables from .env file
if [ -f .env ]; then
  # Read .env file and export variables (ignoring comments and empty lines)
  set -a
  source .env
  set +a
else
  echo "❌ Error: .env file not found!"
  echo ""
  echo "Please create a .env file based on .env.example:"
  echo "  cp .env.example .env"
  echo ""
  echo "Then edit .env and fill in your Supabase credentials."
  exit 1
fi

# Check if required environment variables are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "❌ Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file"
  echo ""
  echo "Please check your .env file and ensure both values are set."
  exit 1
fi

# Build dart-define arguments
DART_DEFINE_ARGS=(
  "--dart-define=SUPABASE_URL=$SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
)

# Add SUPABASE_FUNCTION_URL if it's set
if [ -n "$SUPABASE_FUNCTION_URL" ]; then
  DART_DEFINE_ARGS+=("--dart-define=SUPABASE_FUNCTION_URL=$SUPABASE_FUNCTION_URL")
fi

# Add SUPABASE_REDIRECT_URL if it's set
if [ -n "$SUPABASE_REDIRECT_URL" ]; then
  DART_DEFINE_ARGS+=("--dart-define=SUPABASE_REDIRECT_URL=$SUPABASE_REDIRECT_URL")
fi

# Add DEBUG_EMAIL and DEBUG_UID if they're set (for debug mode)
if [ -n "$DEBUG_EMAIL" ]; then
  DART_DEFINE_ARGS+=("--dart-define=DEBUG_EMAIL=$DEBUG_EMAIL")
fi

if [ -n "$DEBUG_UID" ]; then
  DART_DEFINE_ARGS+=("--dart-define=DEBUG_UID=$DEBUG_UID")
fi

echo "🚀 Running Flutter app with Supabase configuration..."
echo "   SUPABASE_URL: ${SUPABASE_URL:0:30}..."
echo ""

# Run Flutter with dart-define arguments
flutter run "${DART_DEFINE_ARGS[@]}" "$@"

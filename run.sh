#!/bin/bash

# Script to run Flutter app with Supabase configuration from .env file
# Usage:
#   ./run.sh                    # Run Flutter app
#   ./run.sh --deploy          # Deploy Supabase Edge Functions and run Flutter app
#   ./run.sh --deploy-only     # Only deploy Supabase Edge Functions (don't run app)

set -e  # Exit on error

# Check for deploy flag
DEPLOY_FUNCTIONS=false
DEPLOY_ONLY=false

for arg in "$@"; do
  case $arg in
    --deploy)
      DEPLOY_FUNCTIONS=true
      shift
      ;;
    --deploy-only)
      DEPLOY_FUNCTIONS=true
      DEPLOY_ONLY=true
      shift
      ;;
    *)
      # Keep other arguments for flutter run
      ;;
  esac
done

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
# Use individual --dart-define arguments for better Android compatibility
DART_DEFINE_ARGS=(
  "--dart-define=SUPABASE_URL=$SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
)

# Add optional variables if they're set
if [ -n "$SUPABASE_FUNCTION_URL" ]; then
  DART_DEFINE_ARGS+=("--dart-define=SUPABASE_FUNCTION_URL=$SUPABASE_FUNCTION_URL")
fi

if [ -n "$SUPABASE_REDIRECT_URL" ]; then
  DART_DEFINE_ARGS+=("--dart-define=SUPABASE_REDIRECT_URL=$SUPABASE_REDIRECT_URL")
fi

if [ -n "$DEBUG_EMAIL" ]; then
  DART_DEFINE_ARGS+=("--dart-define=DEBUG_EMAIL=$DEBUG_EMAIL")
fi

if [ -n "$DEBUG_UID" ]; then
  DART_DEFINE_ARGS+=("--dart-define=DEBUG_UID=$DEBUG_UID")
fi

# Deploy Supabase Edge Functions if requested
if [ "$DEPLOY_FUNCTIONS" = true ]; then
  echo "🚀 Deploying Supabase Edge Functions..."
  echo ""
  
  # Check if supabase CLI is installed
  if ! command -v supabase &> /dev/null; then
    echo "❌ Error: Supabase CLI is not installed"
    echo ""
    echo "Please install Supabase CLI:"
    echo "  brew install supabase/tap/supabase"
    echo ""
    echo "Or visit: https://supabase.com/docs/guides/cli/getting-started"
    exit 1
  fi
  
  # Check if we're in the right directory or supabase directory exists
  if [ ! -d "supabase" ]; then
    echo "❌ Error: supabase directory not found"
    echo "   Please run this script from the project root directory"
    exit 1
  fi
  
  # Deploy rakuten-books function
  cd supabase
  echo "📦 Deploying rakuten-books Edge Function..."
  if supabase functions deploy rakuten-books; then
    echo ""
    echo "✅ Edge Function deployed successfully!"
    echo ""
  else
    echo ""
    echo "❌ Failed to deploy Edge Function"
    echo ""
    echo "Troubleshooting tips:"
    echo "  1. Make sure you're logged in: supabase login"
    echo "  2. Link your project: cd supabase && supabase link --project-ref your-project-ref"
    echo "  3. Check your Supabase project settings"
    exit 1
  fi
  
  cd ..
  echo ""
  
  # If deploy-only, exit here
  if [ "$DEPLOY_ONLY" = true ]; then
    echo "✅ Deployment complete. Exiting."
    exit 0
  fi
fi

echo "🚀 Running Flutter app with Supabase configuration..."
echo "   SUPABASE_URL: ${SUPABASE_URL:0:30}..."
echo "   SUPABASE_ANON_KEY length: ${#SUPABASE_ANON_KEY}"
echo "   SUPABASE_REDIRECT_URL: $SUPABASE_REDIRECT_URL"
echo ""
echo "📋 Dart define arguments:"
for arg in "${DART_DEFINE_ARGS[@]}"; do
  # Mask sensitive values
  if [[ "$arg" == *"SUPABASE_ANON_KEY"* ]]; then
    echo "   ${arg%%=*}=***"
  else
    echo "   $arg"
  fi
done
echo ""

# Check for Android devices using adb
echo "📱 Checking for Android devices..."

# Find adb command (check common Android SDK locations)
ADB_CMD=""
if command -v adb &> /dev/null; then
  ADB_CMD="adb"
elif [ -f "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
  ADB_CMD="$HOME/Library/Android/sdk/platform-tools/adb"
elif [ -f "$HOME/Android/Sdk/platform-tools/adb" ]; then
  ADB_CMD="$HOME/Android/Sdk/platform-tools/adb"
fi

ANDROID_DEVICE=""
OFFLINE_DEVICES=""
if [ -n "$ADB_CMD" ]; then
  echo "Using adb: $ADB_CMD"
  
  # Check adb devices status
  ADB_OUTPUT=$($ADB_CMD devices 2>/dev/null || echo "")
  
  # Check for offline devices
  OFFLINE_DEVICES=$(echo "$ADB_OUTPUT" | grep "offline" | awk '{print $1}' || echo "")
  if [ -n "$OFFLINE_DEVICES" ]; then
    echo ""
    echo "⚠️  Android device(s) detected but offline:"
    echo "$OFFLINE_DEVICES" | while read -r device_id; do
      echo "   - $device_id (offline)"
    done
    echo ""
    echo "💡 Attempting to fix connection..."
    # Try to restart adb server
    $ADB_CMD kill-server 2>/dev/null || true
    sleep 1
    $ADB_CMD start-server 2>/dev/null || true
    sleep 2
    
    # Check again
    ADB_OUTPUT=$($ADB_CMD devices 2>/dev/null || echo "")
    OFFLINE_DEVICES=$(echo "$ADB_OUTPUT" | grep "offline" | awk '{print $1}' || echo "")
    
    if [ -n "$OFFLINE_DEVICES" ]; then
      echo "❌ Device still offline. Troubleshooting tips:"
      echo "   1. Check if USB debugging is enabled on your Android device"
      echo "   2. Check if you've authorized this computer (look for a popup on your device)"
      echo "   3. Try unplugging and replugging the USB cable"
      echo "   4. On your Android device, revoke USB debugging authorizations and reconnect"
      echo ""
    else
      echo "✅ Connection restored!"
      echo ""
    fi
  fi
  
  # Check for authorized devices (status: device)
  ANDROID_CONNECTED=$(echo "$ADB_OUTPUT" | grep -v "List of devices" | grep -c "device$" || echo "0")
  if [ "$ANDROID_CONNECTED" -gt 0 ]; then
    echo "✅ Android device(s) connected and authorized via USB"
    echo ""
    # Show available Flutter devices
    echo "Available Flutter devices:"
    flutter devices || true
    echo ""
    
    # Use flutter devices --machine (JSON) to reliably grab the first Android mobile/tablet device ID
    ANDROID_DEVICE=$(
      cat <<'PY' | python3 || true
import json, subprocess

try:
    result = subprocess.run(
        ["flutter", "devices", "--machine"],
        check=True,
        capture_output=True,
        text=True,
    )
    raw = result.stdout.strip()
except Exception:
    raw = ""

if raw:
    try:
        devices = json.loads(raw)
    except json.JSONDecodeError:
        devices = []
else:
    devices = []

def is_android(dev):
    platform = (dev.get("targetPlatform") or "").lower()
    return "android" in platform

def is_mobile(dev):
    category = (dev.get("deviceCategory") or "").lower()
    return category in {"mobile", "phone", "tablet"}

android_devices = [d for d in devices if is_android(d) and is_mobile(d)]
if not android_devices:
    android_devices = [d for d in devices if is_android(d)]

if android_devices:
    device_id = android_devices[0].get("deviceId") or ""
    if device_id:
        print(device_id.strip(), end="")
PY
    )
    
    # If not found in flutter devices, try to get from adb directly
    if [ -z "$ANDROID_DEVICE" ]; then
      ANDROID_DEVICE=$(echo "$ADB_OUTPUT" | grep "device$" | head -n 1 | awk '{print $1}' || echo "")
    fi
  else
    # Check if any device is listed (even if offline or unauthorized)
    ANY_DEVICE=$(echo "$ADB_OUTPUT" | grep -v "List of devices" | grep -v "^$" | wc -l | tr -d ' ' || echo "0")
    if [ "$ANY_DEVICE" -gt 0 ] && [ -z "$OFFLINE_DEVICES" ]; then
      echo "⚠️  Android device detected but not authorized"
      echo "   Please authorize this computer on your Android device"
      echo ""
    fi
  fi
else
  echo "⚠️  adb command not found"
  echo "   Please install Android SDK or add platform-tools to your PATH"
  echo ""
fi

# If Android device found, use it; otherwise use default
if [ -n "$ANDROID_DEVICE" ]; then
  echo "🚀 Running on Android device: $ANDROID_DEVICE"
  echo ""
  echo "🔧 Executing: flutter run -d \"$ANDROID_DEVICE\" ${DART_DEFINE_ARGS[*]}"
  echo ""
  flutter run -d "$ANDROID_DEVICE" "${DART_DEFINE_ARGS[@]}" "$@"
else
  if [ -n "$OFFLINE_DEVICES" ]; then
    echo "❌ Cannot run on offline Android device."
    echo ""
    echo "Please fix the connection and try again, or run on another device."
    echo ""
    echo "Available Flutter devices:"
    flutter devices || true
    echo ""
    echo "To run on a different device, use:"
    echo "  flutter run -d <device-id> ${DART_DEFINE_ARGS[*]}"
    exit 1
  fi
  echo "⚠️  No authorized Android device found. Checking Flutter devices..."
  echo ""
  flutter devices || true
  echo ""
  echo "Running on default device..."
  echo ""
  echo "🔧 Executing: flutter run ${DART_DEFINE_ARGS[*]}"
  echo ""
  flutter run "${DART_DEFINE_ARGS[@]}" "$@"
fi

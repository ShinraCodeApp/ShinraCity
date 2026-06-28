#!/usr/bin/env bash
# Start Firebase emulators and Flutter app with emulator flag
# Usage: bash scripts/emulators.sh [android|ios|web] [--seed]

set -e

PLATFORM=${1:-android}
SEED=false
for arg in "$@"; do
  [[ "$arg" == "--seed" ]] && SEED=true
done

echo "🔥 Starting Firebase emulators..."
firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data &
EMULATOR_PID=$!

echo "⏳ Waiting for emulators to be ready..."
sleep 5

if [ "$SEED" = true ]; then
  echo "🌱 Seeding emulator with test data..."
  (cd functions && npm run seed)
  echo "✅ Seed complete."
fi

echo "📱 Starting Flutter on $PLATFORM with emulators enabled..."
flutter run \
  --dart-define=USE_EMULATORS=true \
  -d "$PLATFORM"

kill $EMULATOR_PID 2>/dev/null || true

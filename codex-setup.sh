#!/usr/bin/env bash
set -e

FLUTTER_VERSION=3.24.0
CMDLINE_TOOLS_VERSION=11076708

ANDROID_SDK="$HOME/Android/Sdk"

echo "[setup] Starting Flutter + Android setup"

# --- Flutter (idempotent) ----------------------------------------
if [ ! -d "$HOME/development/flutter" ]; then
  echo "[setup] Installing Flutter..."
  mkdir -p "$HOME/development"
  cd "$HOME/development"
  wget -q "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar xf "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
else
  echo "[setup] Flutter already present, skipping download."
fi

# --- Android SDK + cmdline tools (idempotent) ---------------------
mkdir -p "$ANDROID_SDK/cmdline-tools"
cd "$ANDROID_SDK/cmdline-tools"

if [ ! -d latest ]; then
  echo "[setup] Installing Android cmdline tools..."
  wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  unzip -q "commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  mv cmdline-tools latest
  rm "commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
else
  echo "[setup] Android cmdline tools already present, skipping download."
fi

# --- Env vars: append once to .bashrc -----------------------------
if ! grep -q "Flutter SDK" "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ''
    echo '# Flutter SDK'
    echo 'export PATH="$PATH:$HOME/development/flutter/bin"'
  } >> "$HOME/.bashrc"
fi

if ! grep -q "Android SDK" "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ''
    echo '# Android SDK'
    echo 'export ANDROID_HOME="$HOME/Android/Sdk"'
    echo 'export ANDROID_SDK_ROOT="$HOME/Android/Sdk"'
    echo 'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"'
  } >> "$HOME/.bashrc"
fi

export PATH="$PATH:$HOME/development/flutter/bin"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

# --- Licenses + minimal packages ---------------------------------
mkdir -p "$ANDROID_SDK/licenses"
echo "24333f8a63b6825ea9c5514f83c02fb9ac33a3078f4ff8913416123d1db5b742" > "$ANDROID_SDK/licenses/android-sdk-license"

"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  --sdk_root="$ANDROID_SDK" \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0"

echo "[setup] Flutter + Android setup finished."
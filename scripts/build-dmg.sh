#!/bin/bash
set -e

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"
APP_PATH="build/Build/Products/Release/OffKey.app"
DMG_PATH="$PROJECT_DIR/OffKey.dmg"
STAGING_DIR="$PROJECT_DIR/dmg-staging"

echo "======================================"
echo " OffKey — сборка DMG"
echo "======================================"
echo "Папка: $PROJECT_DIR"
echo

if [ ! -f "OffKey.xcodeproj/project.pbxproj" ]; then
  echo "ОШИБКА: запусти скрипт из папки с OffKey.xcodeproj"
  exit 1
fi

echo "[1/4] Сборка OffKey.app ..."
xcodebuild \
  -scheme OffKey \
  -configuration Release \
  -derivedDataPath build

if [ ! -d "$APP_PATH" ]; then
  echo
  echo "ОШИБКА: приложение не найдено:"
  echo "$PROJECT_DIR/$APP_PATH"
  exit 1
fi
echo "OK: приложение собрано"
echo

echo "[2/4] Подготовка dmg-staging ..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

if [ ! -d "$STAGING_DIR/OffKey.app" ]; then
  echo "ОШИБКА: OffKey.app не скопировался в dmg-staging"
  exit 1
fi
echo "OK: dmg-staging готов"
echo

echo "[3/4] Создание OffKey.dmg ..."
rm -f "$DMG_PATH" "$PROJECT_DIR/OffKey.zip"
find "$STAGING_DIR" -name .DS_Store -delete

DMG_OK=0

# Способ 1 — простой
if hdiutil create -volname "OffKey" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" 2>/dev/null; then
  echo "OK: DMG создан (способ 1)"
  DMG_OK=1
else
  echo "Способ 1 не сработал, пробую способ 2 ..."
  TEMP_DMG="/tmp/OffKey-temp-$$.dmg"
  MOUNT_DIR="/Volumes/OffKey-$$"

  rm -f "$TEMP_DMG"
  if hdiutil create -size 64m -fs HFS+ -volname "OffKey" "$TEMP_DMG" 2>/dev/null \
    && hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse 2>/dev/null; then
    ditto "$STAGING_DIR/OffKey.app" "$MOUNT_DIR/OffKey.app"
    ln -sf /Applications "$MOUNT_DIR/Applications"
    hdiutil detach "$MOUNT_DIR" 2>/dev/null
    if hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_PATH" -ov 2>/dev/null; then
      echo "OK: DMG создан (способ 2)"
      DMG_OK=1
    fi
    rm -f "$TEMP_DMG"
  fi
fi

echo
echo "[4/4] Проверка ..."

if [ "$DMG_OK" -eq 1 ] && [ -f "$DMG_PATH" ]; then
  echo
  echo "======================================"
  echo " ГОТОВО: DMG"
  echo "======================================"
  ls -lh "$DMG_PATH"
  echo
  echo "Файл: $DMG_PATH"
  open -R "$DMG_PATH"
  exit 0
fi

echo "DMG не удалось создать. Делаю ZIP (тоже можно раздавать) ..."
ditto -c -k --keepParent "$STAGING_DIR/OffKey.app" "$PROJECT_DIR/OffKey.zip"

if [ ! -f "$PROJECT_DIR/OffKey.zip" ]; then
  echo "ОШИБКА: не получилось ни DMG, ни ZIP"
  exit 1
fi

echo
echo "======================================"
echo " ГОТОВО: ZIP (вместо DMG)"
echo "======================================"
ls -lh "$PROJECT_DIR/OffKey.zip"
echo
echo "Файл: $PROJECT_DIR/OffKey.zip"
echo "Распакуй ZIP → перетащи OffKey.app в Программы"
open -R "$PROJECT_DIR/OffKey.zip"

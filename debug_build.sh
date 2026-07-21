#!/bin/bash
set -x

echo "=== Gradle Version ==="
gradle --version

echo "=== Java Version ==="
java -version

echo "=== Checking Android SDK ==="
ls -la $ANDROID_HOME/

echo "=== Flutter Doctor ==="
flutter doctor -v

echo "=== Build verbose output ==="
cd android
./gradlew assembleRelease -i 2>&1 | head -200

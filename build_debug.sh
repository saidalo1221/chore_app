#!/bin/bash
cd android
echo "=== Running Gradle with full stacktrace ==="
./gradlew assembleRelease --stacktrace 2>&1

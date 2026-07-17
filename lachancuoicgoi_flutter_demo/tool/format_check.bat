@echo off
REM Wrapper cho dart format check — dùng trên Windows cho dev local.
REM Mirror CI step "Verify formatting" trong .github/workflows/ci.yml.
dart format --output=none --set-exit-if-changed lib/ test/

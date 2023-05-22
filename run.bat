@echo off

pushd "%~dp0"

set /p "token=Enter token: "
telegram_bot.exe %token%

popd

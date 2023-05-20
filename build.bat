@echo off
nasm -f win64 -o main.obj main.asm
LINK main.obj /SUBSYSTEM:console /OUT:telegram_bot.exe /NOLOGO kernel32.lib legacy_stdio_definitions.lib msvcrt.lib libucrt.lib Wininet.lib

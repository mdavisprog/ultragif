@ECHO OFF

SETLOCAL ENABLEDELAYEDEXPANSION
PUSHD "%~dp0"

CALL clean.bat

PUSHD ..

zig build -Dshipping=true -Doptimize=ReleaseFast

POPD
POPD
ENDLOCAL

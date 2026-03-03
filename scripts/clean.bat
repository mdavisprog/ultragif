@ECHO OFF

SETLOCAL ENABLEDELAYEDEXPANSION
PUSHD "%~dp0"
PUSHD ..

SET CACHE=.zig-cache
SET OUT=zig-out
SET EXTERNAL=external

SET DIRS=%CACHE%^
    %OUT%^
    %EXTERNAL%\clay\%CACHE%^
    %EXTERNAL%\raylib\%CACHE%

ECHO Cleaning...
FOR %%A in (%DIRS%) do (
    IF EXIST %%A (
        ECHO Cleaning %%A
        RMDIR /S /Q %%A
    )
)

POPD
POPD
ENDLOCAL

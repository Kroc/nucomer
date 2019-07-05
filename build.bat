@ECHO OFF
CLS & TITLE Building Nucomer...
CD %~dp0

REM # convert the article text into C64 text codes
REM ============================================================================
SET LUA="bin\lua\lua53.exe"
SET LUA_TXT2C64=%LUA% "scripts\txt2c64.lua"

%LUA_TXT2C64% "scripts\lorem-ipsum.txt" "build\lorem-ipsum.nu"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # assemble the outfit
REM ============================================================================

SET ACME="bin\acme\acme.exe" ^
    --format cbm ^
    --color ^
     -v9 ^
     -I "src"

ECHO ?

%ACME% ^
     --format plain ^
     "src\petscii_font.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

%ACME% ^
    --outfile   "build\nucomer.prg" ^
                "src\nucomer.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # TODO: package disks
REM ============================================================================
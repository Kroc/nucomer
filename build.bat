@ECHO OFF
CLS & TITLE Building Nucomer...
CD %~dp0

SET LUA="bin\lua\lua53.exe"
SET LUA_TXT2C64=%LUA% "issues\txt2c64.lua"

SET ACME="bin\acme\acme.exe" ^
    --format cbm ^
    --color ^
     -v1 ^
     -I "src"

SET C1541="bin\vice\c1541.exe"


REM # convert the article text into C64 text codes
REM ============================================================================

%LUA_TXT2C64% "issues\lorem-ipsum.txt" "build\article.nu"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # assemble the outfit
REM ============================================================================

%ACME% ^
     --format plain ^
     "src\petscii_font.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

%ACME% ^
    --outfile   "build\nucomer.prg" ^
                "src\nucomer.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # package disks
REM ============================================================================

DEL "build\nucomer.d64"

%C1541% ^
     -format "nucomer,nu" d64 "build\nucomer.d64" ^
     -write "build\nucomer.prg" "nucomer" ^
     -write "build\article.nu" "lorem-ipsum"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

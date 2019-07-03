@ECHO OFF
CLS & TITLE Building Nucomer...
::==============================================================================
CD %~dp0

SET ACME="bin\acme\acme.exe" ^
    --format cbm ^
    --color ^
     -v9 ^
     -I "src"

%ACME% ^
    --outfile   "build\nucomer.prg" ^
                "src\nucomer.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
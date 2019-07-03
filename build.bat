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
     --format plain ^
     "src\petscii_font.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

%ACME% ^
    --outfile   "build\nucomer.prg" ^
                "src\nucomer.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
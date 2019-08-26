@ECHO OFF
CLS & TITLE Building Nucomer...
CD %~dp0

SET LUA="bin\lua\lua53.exe"
SET LUA_ARTICLE=%LUA% "scripts\article.lua"

SET ACME=bin\acme\acme.exe -I "src"
SET EXOMIZER="bin\exomizer.exe"
SET C1541="bin\vice\c1541.exe"

REM # assemble BSOD64 debugger
REM ============================================================================
ECHO:
ECHO BSOD64
ECHO ----------------------------------------
PUSHD src\bsod64

REM # assemble BSOD64 into its own folder as its a sub-project

..\..\%ACME% -v1 ^
     --format cbm ^
     -Wtype-mismatch ^
          "bsod64.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
POPD

REM # convert the article text into C64 text codes
REM ============================================================================

%LUA% "scripts\issue.lua"
IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # assemble the outfit
REM ============================================================================
ECHO ----------------------------------------
<NUL (SET /P "$=Assemble Outfit...                  ")

REM # assemble the ASCII map used to embed the nücomer logo
%ACME% ^
     --format plain ^
          "src\petscii_font.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%ACME% ^
     --format cbm ^
     --report "build\nucomer.txt" ^
     --outfile "build\nucomer.prg" ^
          "src\nucomer.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)
ECHO [OK]

REM # exomize content:
REM ============================================================================
<NUL (SET /P "$=Exomize...                          ")

%EXOMIZER% sfx "sys" -n -q ^
     -o "build\nucomer-exo.prg" ^
     -- "build\nucomer.prg" ^
        "src\bsod64\bsod64.prg"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)
ECHO [OK]

REM # package disks
REM ============================================================================
<NUL (SET /P "$=Create D64...                       ")

IF EXIST "build\nucomer.d64" DEL "build\nucomer.d64"

REM # prepare the disk image
%C1541% ^
     -silent -verbose off ^
     -format "nucomer,00" d64 "build\nucomer.d64" ^
     -write "build\nucomer-exo.prg"     "nucomer" ^
     -write "src\bsod64\bsod64.prg"     "bsod64" ^
     1>NUL

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # walk through the list of articles and add them to the disk
FOR /F "eol=* delims=; tokens=1,2" %%A IN (build\i00.lst) DO (
     REM # add the C64-compressed article data to the disk image
     %C1541% "build\nucomer.d64" ^
          -silent -verbose off ^
          -write "%%A" "%%B" ^
          1>NUL
     
     IF ERRORLEVEL 1 (
          ECHO FAIL
          EXIT /B %ERRORLEVEL%
     )
)
ECHO [OK]

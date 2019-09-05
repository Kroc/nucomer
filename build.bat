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

REM # assemble fonts
REM ----------------------------------------------------------------------------
%ACME% "src\fonts\admiral64.acme"
%ACME% "src\fonts\wax-lyrics.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the ASCII maps
REM ----------------------------------------------------------------------------
%ACME% ^
     --format plain ^
          "src\fonts\scr_nucomer.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%ACME% ^
     --format plain ^
          "src\fonts\scr_logo.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the disk bootstrap
REM ----------------------------------------------------------------------------
%ACME% ^
     --format cbm ^
     --outfile "build\boot.prg" ^
          "src\prg_boot.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the intro
REM ----------------------------------------------------------------------------

REM # test build the fast-loader
%ACME% ^
     --format cbm ^ --setpc $0800 ^
     --outfile "build\fload.prg" ^
          "src\load\load_cfg_all.acme" ^
          "src\load\load.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%ACME% ^
     --format cbm ^
     --outfile "build\intro.prg" ^
          "src\prg_intro.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the main outfit
REM ----------------------------------------------------------------------------
%ACME% ^
     --format cbm ^
     --report "build\nucomer.txt" ^
     --outfile "build\nucomer.prg" ^
          "src\prg_nucomer.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)
ECHO [OK]

REM # exomize content:
REM ============================================================================
<NUL (SET /P "$=Exomize...                          ")

%EXOMIZER% sfx $0800 -n -q ^
     -o "build\nucomer-exo.prg" ^
     -- "build\nucomer.prg" ^
        "src\bsod64\bsod64.prg" ^
        "build\admiral64.prg"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)
ECHO [OK]

REM # package disks
REM ============================================================================
<NUL (SET /P "$=Create D64...                       ")

REM # TODO: build the disk commands in the Lua scripts,
REM #       i.e. c1541 < commands.txt

IF EXIST "build\nucomer.d64" DEL "build\nucomer.d64"

REM # prepare the disk image
%C1541% ^
     -silent -verbose off ^
     -format "nucomer,00" d64 "build\nucomer.d64" ^
     -write "build\boot.prg"            "boot" ^
     -write "build\intro.prg"           "intro" ^
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

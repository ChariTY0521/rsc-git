@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Place this file in the root of rsc-git, beside rustdesk.json and the PEM keys.
cd /d "%~dp0"

set "MANIFEST=rustdesk.json"
set "SIGNATURE=rustdesk.json.sig"
set "PRIVATE_KEY=rsc-manifest-private.pem"
set "PUBLIC_KEY=rsc-manifest-public.pem"
set "TO_SIGN=rustdesk.json.to-sign"
set "SIGNATURE_BIN=rustdesk.json.sig.bin"
set "COMMIT_MESSAGE=Update signed RustDesk manifest"
if not "%~1"=="" set "COMMIT_MESSAGE=%~1"

where git >nul 2>&1 || goto :missing_git
where openssl >nul 2>&1 || goto :missing_openssl
git rev-parse --is-inside-work-tree >nul 2>&1 || goto :not_repository

if not exist "%MANIFEST%" goto :missing_manifest
if not exist "%PRIVATE_KEY%" goto :missing_private_key
if not exist "%PUBLIC_KEY%" goto :missing_public_key

rem The staged JSON is the exact byte sequence published by Git.
git check-attr eol -- "%MANIFEST%" | findstr /c:"eol: lf" >nul || goto :bad_attributes
git check-attr text -- "%SIGNATURE%" | findstr /c:"text: unset" >nul || goto :bad_attributes
git add --renormalize "%MANIFEST%" || goto :failed
git cat-file blob :%MANIFEST% > "%TO_SIGN%" || goto :failed

openssl dgst -sha256 -sign "%PRIVATE_KEY%" -out "%SIGNATURE_BIN%" "%TO_SIGN%" || goto :failed
openssl base64 -A -in "%SIGNATURE_BIN%" -out "%SIGNATURE%" || goto :failed
openssl base64 -d -A -in "%SIGNATURE%" -out "%SIGNATURE_BIN%" || goto :failed
openssl dgst -sha256 -verify "%PUBLIC_KEY%" -signature "%SIGNATURE_BIN%" "%TO_SIGN%" || goto :failed

del /q "%TO_SIGN%" "%SIGNATURE_BIN%" >nul 2>&1
git add -f "%SIGNATURE%" || goto :failed
git diff --cached --quiet -- "%MANIFEST%" "%SIGNATURE%"
if errorlevel 2 goto :failed
if errorlevel 1 goto :commit

echo Manifest unchanged; nothing to deploy.
goto :success

:commit
git commit -m "%COMMIT_MESSAGE%" -- "%MANIFEST%" "%SIGNATURE%" || goto :failed
git push origin main || goto :failed
echo Manifest deployed.
goto :success

:missing_git
echo Git was not found in PATH.
goto :error
:missing_openssl
echo OpenSSL was not found in PATH.
goto :error
:not_repository
echo Run this script from the rsc-git repository root.
goto :error
:missing_manifest
echo Missing %MANIFEST%.
goto :error
:missing_private_key
echo Missing %PRIVATE_KEY%.
goto :error
:missing_public_key
echo Missing %PUBLIC_KEY%.
goto :error
:bad_attributes
echo .gitattributes must contain:
echo %MANIFEST% text eol=lf
echo %SIGNATURE% -text
goto :error
:failed
del /q "%TO_SIGN%" "%SIGNATURE_BIN%" >nul 2>&1
echo Signing or deployment failed.
goto :error
:success
endlocal
exit /b 0
:error
endlocal
exit /b 1

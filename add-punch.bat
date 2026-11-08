@echo off
setlocal DisableDelayedExpansion
if "%~2"=="" (
    echo Usage: add-punch.bat EMPLOYEE_CODE "YYYY-MM-DD HH:MM:SS" 1>&2
    exit /b 2
)
set "PUNCH_EMPLOYEE=%~1"
set "PUNCH_TIMESTAMP=%~2"
powershell.exe -NoProfile -Command "$timestamp = [datetime]::MinValue; if ($env:PUNCH_EMPLOYEE -notmatch '^[0-9]+$' -or -not [datetime]::TryParseExact($env:PUNCH_TIMESTAMP, 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$timestamp)) { [Console]::Error.WriteLine('Expected a numeric employee code and a valid YYYY-MM-DD HH:MM:SS timestamp.'); exit 2 }; $line = (@($env:PUNCH_EMPLOYEE, $env:PUNCH_TIMESTAMP, '0', '1', '0', '0') -join [char]9) + [char]10; $line | curl.exe --silent --show-error --fail-with-body --insecure --header 'Content-Type: text/plain' --data-binary '@-' 'https://10.245.115.50/iclock/cdata?SN=3686172560011&table=ATTLOG&Stamp=9999'; exit $LASTEXITCODE"
exit /b %errorlevel%

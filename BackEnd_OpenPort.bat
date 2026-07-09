@echo off
netsh advfirewall firewall add rule name="Backend_FastAPI_3000" dir=in action=allow protocol=TCP localport=3000
echo.
echo EXIT_CODE=%ERRORLEVEL%
pause
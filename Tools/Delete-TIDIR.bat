@echo off
set arg1=%1
set wd=%~dp0
rem start /wait "" "%wd%AdvancedRun.exe" /EXEFilename "%systemroot%\System32\cmd.exe" /
rem start /wait cmd.exe /c "del /Q /F %wd%temp.cfg"
echo [General]>%wd%temp.cfg
echo EXEFilename=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe>>%wd%temp.cfg
echo CommandLine="Remove-Item -LiteralPath "%arg1%" -Recurse -Force">>%wd%temp.cfg
echo WaitProcess=1>>%wd%temp.cfg
echo WindowState=1>>%wd%temp.cfg
echo RunAs=8>>%wd%temp.cfg
echo AutoRun=1>>%wd%temp.cfg


rem [General]
rem EXEFilename=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
rem CommandLine="Remove-Item -LiteralPath "C:\Users\tomo\Desktop\build\build-test\mount\Windows\SysWOW64" -Recurse -Force"
rem WaitProcess=1
rem WindowState=1
rem RunAs=8
rem AutoRun=1
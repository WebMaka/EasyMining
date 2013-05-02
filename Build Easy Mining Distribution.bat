@echo off

set ThisPath=%CD%
echo Detected current path as "%ThisPath%"
echo Clearing distribution folder...

set CAT=%ThisPath%\distribution
dir "%%CAT%%"/s/b/a | sort /r >> %TEMP%\files2del.txt
for /f "delims=;" %%D in (%TEMP%\files2del.txt) do (del /q "%%D" & rd "%%D")
del /q %TEMP%\files2del.txt

echo Copying cgminer from "%ThisPath%\cgminer\"...
xcopy "%ThisPath%\cgminer" "%ThisPath%\distribution\cgminer" /a /e /h /i

echo Copying cpuminer-x32...
xcopy "%ThisPath%\cpuminer-x32" "%ThisPath%\distribution\cpuminer-x32" /a /e /h /i

echo Copying cpuminer-x64...
xcopy "%ThisPath%\cpuminer-x64" "%ThisPath%\distribution\cpuminer-x64" /a /e /h /i

echo Copying cudaminer...
xcopy "%ThisPath%\cudaminer" "%ThisPath%\distribution\cudaminer" /a /e /h /i

echo Copying stratum proxy...
xcopy "%ThisPath%\stratumproxy" "%ThisPath%\distribution\stratumproxy" /a /e /h /i

echo Copying docs...
xcopy "%ThisPath%\docs" "%ThisPath%\distribution\docs" /a /e /h /i

echo Copying INI file...
copy "%ThisPath%\easy_mining_blank.ini" "%ThisPath%\distribution\easy_mining.ini"

echo Copying Easy Mining executable...
copy "%ThisPath%\EasyMining.exe" "%ThisPath%\distribution"

echo Copying Easy Mining Source...
mkdir "%ThisPath%\distribution\easymining_source
xcopy "%ThisPath%\*.ico" "%ThisPath%\distribution\easymining_source"
xcopy "%ThisPath%\*.ini" "%ThisPath%\distribution\easymining_source"
xcopy "%ThisPath%\*.dpr" "%ThisPath%\distribution\easymining_source"
xcopy "%ThisPath%\*.res" "%ThisPath%\distribution\easymining_source"
xcopy "%ThisPath%\*.dfm" "%ThisPath%\distribution\easymining_source"
xcopy "%ThisPath%\*.pas" "%ThisPath%\distribution\easymining_source"

echo Done!
pause

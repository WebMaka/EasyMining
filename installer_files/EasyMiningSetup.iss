[Icons]
Name: {group}\Easy Mining; Filename: {app}\EasyMining.exe; WorkingDir: {app}; IconIndex: 0
Name: {group}\Getting Started; Filename: {app}\docs\getting_started.htm; WorkingDir: {app}
Name: {group}\About Easy Mining; Filename: {app}\docs\about.htm; WorkingDir: {app}
[Setup]
OutputDir=F:\easy_mining\easy_mining_source\installer_files
AppCopyright=© 2013+ by ManWitDaPlan
AppName=Easy Mining
AppVerName=Easy Mining BETA
DefaultDirName={pf}\EasyMining
DefaultGroupName=Easy Mining
OutputBaseFilename=EasyMining_setup
InfoBeforeFile=F:\easy_mining\easy_mining_source\malware_warning.rtf
LicenseFile=F:\easy_mining\easy_mining_source\license.txt
[Dirs]
Name: {app}\docs
Name: {app}\docs\images
Name: {app}\easymining_source
Name: {app}\stratumproxy
Name: {app}\cgminer
Name: {app}\cgminer\bitstreams
Name: {app}\cpuminer-x32
Name: {app}\cpuminer-x64
Name: {app}\cudaminer
[Files]
Source: ..\distribution\docs\images\cc-sa-ba-88x31.png; DestDir: {app}\docs\images
Source: ..\distribution\docs\images\easy_mining_logo.png; DestDir: {app}\docs\images
Source: ..\distribution\docs\images\em_configuration.png; DestDir: {app}\docs\images
Source: ..\distribution\docs\about.htm; DestDir: {app}\docs\
Source: ..\distribution\docs\getting_started.htm; DestDir: {app}\docs\
Source: ..\distribution\easymining_source\EasyMining.dpr; DestDir: {app}\easymining_source\
Source: ..\distribution\easymining_source\EasyMining.res; DestDir: {app}\easymining_source\
Source: ..\distribution\easymining_source\easy_mining.ico; DestDir: {app}\easymining_source\
Source: ..\distribution\easymining_source\easy_mining.ini; DestDir: {app}\easymining_source\
Source: ..\distribution\easymining_source\easy_mining_blank.ini; DestDir: {app}\easymining_source\
Source: ..\distribution\easymining_source\MainUnit.dfm; DestDir: {app}\easymining_source\
Source: ..\distribution\easymining_source\MainUnit.pas; DestDir: {app}\easymining_source\
Source: ..\distribution\easymining_source\MonitorThreadUnit.pas; DestDir: {app}\easymining_source\
Source: ..\distribution\stratumproxy\mining_proxy.exe; DestDir: {app}\stratumproxy\
Source: ..\distribution\easy_mining.ini; DestDir: {app}
Source: ..\distribution\EasyMining.exe; DestDir: {app}
Source: ..\distribution\cgminer\bitstreams\COPYING_fpgaminer; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\COPYING_ztex; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\fpgaminer_top_fixed7_197MHz.ncd; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\ztex_ufm1_15b1.bit; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\ztex_ufm1_15d1.bit; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\ztex_ufm1_15d3.bit; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\ztex_ufm1_15d4.bin; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\ztex_ufm1_15d4.bit; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\ztex_ufm1_15y1.bin; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\bitstreams\ztex_ufm1_15y1.bit; DestDir: {app}\cgminer\bitstreams
Source: ..\distribution\cgminer\api-example.c; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\api-example.php; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\API-README.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\API.class; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\API.java; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\AUTHORS.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\cgminer-fpgaonly.exe; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\cgminer.exe; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\ChangeLog.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\COPYING.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\diablo130302.cl; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\diakgcn121016.cl; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\example.conf; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\FPGA-README.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\libcurl.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\libeay32.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\libidn-11.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\librtmp.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\libssh2.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\libusb-1.0.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\linux-usb-cgminer.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\miner.php; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\NEWS.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\phatk121016.cl; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\poclbm130302.cl; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\README.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\SCRYPT-README.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\scrypt130302.cl; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\ssleay32.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\windows-build.txt; DestDir: {app}\cgminer\
Source: ..\distribution\cgminer\zlib1.dll; DestDir: {app}\cgminer\
Source: ..\distribution\cpuminer-x32\libcurl-4.dll; DestDir: {app}\cpuminer-x32\
Source: ..\distribution\cpuminer-x32\minerd.exe; DestDir: {app}\cpuminer-x32\
Source: ..\distribution\cpuminer-x32\pthreadGC2.dll; DestDir: {app}\cpuminer-x32\
Source: ..\distribution\cpuminer-x64\libcurl-4.dll; DestDir: {app}\cpuminer-x64\
Source: ..\distribution\cpuminer-x64\minerd.exe; DestDir: {app}\cpuminer-x64\
Source: ..\distribution\cpuminer-x64\pthreadGC2.dll; DestDir: {app}\cpuminer-x64\
Source: ..\distribution\cudaminer\create_helpfile.bat; DestDir: {app}\cudaminer\
Source: ..\distribution\cudaminer\cudaminer-src-2013.04.22.zip; DestDir: {app}\cudaminer\
Source: ..\distribution\cudaminer\cudaminer.exe; DestDir: {app}\cudaminer\
Source: ..\distribution\cudaminer\cudart32_50_35.dll; DestDir: {app}\cudaminer\
Source: ..\distribution\cudaminer\help.txt; DestDir: {app}\cudaminer\
Source: ..\distribution\cudaminer\LICENSE.txt; DestDir: {app}\cudaminer\
Source: ..\distribution\cudaminer\pthreadVC2.dll; DestDir: {app}\cudaminer\
Source: ..\distribution\cudaminer\README.txt; DestDir: {app}\cudaminer\

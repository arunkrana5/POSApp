@echo off
title 1-Click Mobile App Auto-Installer
color 0A
echo ========================================================
echo    1-CLICK STORE POS MOBILE APP AUTO-INSTALLER
echo ========================================================
echo.

set ADB="C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe"
set TARGET=192.168.137.230:41179
set APK="D:\VillageShop_Mobile\VillageShop.apk"

echo 1. Connecting to phone over Wireless Wi-Fi...
%ADB% connect %TARGET%

echo.
echo 2. Setting up API Port Tunnels...
%ADB% -s %TARGET% reverse tcp:5000 tcp:5000
%ADB% -s %TARGET% reverse tcp:8080 tcp:8080

echo.
echo 3. Installing Store POS App on phone...
%ADB% -s %TARGET% install -r -d -g %APK%

echo.
echo 4. Launching Store POS App on phone screen...
%ADB% -s %TARGET% shell am start -n com.retailpos.mobile.app/com.example.villageshop_mobile.MainActivity

echo.
echo ========================================================
echo    SUCCESS! APP IS INSTALLED AND OPEN ON YOUR PHONE!
echo ========================================================
pause

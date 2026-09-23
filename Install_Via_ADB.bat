@echo off
echo ========================================================
echo   VillageShop - ADB Developer Mode Installer
echo ========================================================

"C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe" devices

"C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe" install -r -d "D:\VillageShop_Mobile\VillageShop.apk"
pause

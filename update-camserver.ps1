
# https://stackoverflow.com/a/9949909/4862220
# $ErrorActionPreference = "Stop"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (!(Test-Path "C:\Zins\ZinsCamServer")) {
    New-Item "C:\Zins\ZinsCamServer" -ItemType Directory
}

Write-Host "Baixando CamServer..."
Invoke-WebRequest "http://f.zins.com.br/updates/zins/ZinsCamServer.zip" -UseBasicParsing -OutFile "C:\Zins\ZinsCamServer\_download.zip"

Write-Host "Parando CamServer..."
net stop ZinsCamServer

# Write-Host "Parando nginx..."
# taskkill /IM "nginx.exe" /F

timeout 3

Write-Host "Extraindo arquivos..."
Expand-Archive "C:\Zins\ZinsCamServer\_download.zip" "C:\Zins\ZinsCamServer\_ZinsCamServerExtTemp" -Force
Remove-Item "C:\Zins\ZinsCamServer\*.dll"
Remove-Item "C:\Zins\ZinsCamServer\*.exe"
xcopy "C:\Zins\ZinsCamServer\_ZinsCamServerExtTemp" "C:\Zins\ZinsCamServer" /q/d/s/y
Remove-Item "C:\Zins\ZinsCamServer\_ZinsCamServerExtTemp" -Recurse -Force

Write-Host "Iniciando CamServer..."
net start ZinsCamServer

Start-Process "http://localhost:9981/home/versao"

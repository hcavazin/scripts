
# https://stackoverflow.com/a/9949909/4862220
# $ErrorActionPreference = "Stop"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$downloadPath = "C:\Zins\_ZinsCamServer-download.zip"
$tempExtractPath = "C:\Zins\ZinsCamServer-new"
$finalPath = "C:\Zins\ZinsCamServer"

# limpar artefatos de execucoes anteriores que possam ter falhado no meio
if (Test-Path $tempExtractPath) {
    Remove-Item $tempExtractPath -Recurse -Force
}
if (Test-Path $downloadPath) {
    Remove-Item $downloadPath -Force
}

Write-Host "Baixando CamServer..."
Invoke-WebRequest "http://f.zins.com.br/updates/zins/ZinsCamServer.zip" -UseBasicParsing -OutFile $downloadPath

Write-Host "Extraindo arquivos..."
Expand-Archive $downloadPath $tempExtractPath -Force

Write-Host "Parando CamServer..."
net stop ZinsCamServer

# Write-Host "Parando nginx..."
# taskkill /IM "nginx.exe" /F

timeout 3

# swap atomico: remove pasta antiga e renomeia -new -> nome final
if (Test-Path $finalPath) {
    Remove-Item $finalPath -Recurse -Force
}
Rename-Item -Path $tempExtractPath -NewName (Split-Path $finalPath -Leaf)

Remove-Item $downloadPath -Force

Write-Host "Iniciando CamServer..."
net start ZinsCamServer

Start-Process "http://localhost:9981/home/versao"

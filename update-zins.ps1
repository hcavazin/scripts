
param (
    [Parameter(Mandatory=$true)]
    [string]$Version
)

# ir para diretorio C:\Zins
Set-Location C:\Zins

# baixar 7za
$7zaUrl = "https://zinspublic.blob.core.windows.net/updates/utils/7za_x64.exe"
$7zaPath = "C:\Zins\7za.exe"
Invoke-WebRequest -Uri $7zaUrl -OutFile $7zaPath

# remover pastas antigas: Processor2, Transceiver2 e Workstation2
Remove-Item -Path "C:\Zins\Processor2" -Recurse -Force
Remove-Item -Path "C:\Zins\Transceiver2" -Recurse -Force
Remove-Item -Path "C:\Zins\Workstation2" -Recurse -Force

# remover pastas novas: ZinsProcessor, ZinsTransceiver, ZinsWorkstation
Remove-Item -Path "C:\Zins\ZinsProcessor" -Recurse -Force
Remove-Item -Path "C:\Zins\ZinsTransceiver" -Recurse -Force
Remove-Item -Path "C:\Zins\ZinsWorkstation" -Recurse -Force

$baseUrlTransceiver = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsTransceiver-$Version.7z"
$baseUrlProcessor = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsProcessor-$Version.7z"
$baseUrlWorkstation = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsWorkstation-$Version.7z"
$baseUrlCamServer = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsCamServer-$Version.7z"

$downloadPathTransceiver = "C:\Zins\ZinsTransceiver-$Version.7z"
$downloadPathProcessor = "C:\Zins\ZinsProcessor-$Version.7z"
$downloadPathWorkstation = "C:\Zins\ZinsWorkstation-$Version.7z"
$downloadPathCamServer = "C:\Zins\ZinsCamServer-$Version.7z"

# download
Invoke-WebRequest -Uri $baseUrlTransceiver -OutFile $downloadPathTransceiver
Invoke-WebRequest -Uri $baseUrlProcessor -OutFile $downloadPathProcessor
Invoke-WebRequest -Uri $baseUrlWorkstation -OutFile $downloadPathWorkstation
Invoke-WebRequest -Uri $baseUrlCamServer -OutFile $downloadPathCamServer

# parar servico ZinsCamServer
Stop-Service -Name ZinsCamServer

# extrair arquivos
$unzipPath = "C:\Zins"
& $7zaPath x $downloadPathTransceiver -o$unzipPath -y
& $7zaPath x $downloadPathProcessor -o$unzipPath -y
& $7zaPath x $downloadPathWorkstation -o$unzipPath -y
& $7zaPath x $downloadPathCamServer -o$unzipPath -y

# unzip
$unzipPath = "C:\Zins"
Expand-Archive -Path $downloadPath -DestinationPath $unzipPath

# remove zip
Remove-Item $downloadPath

# iniciar servico ZinsCamServer
Start-Service -Name ZinsCamServer

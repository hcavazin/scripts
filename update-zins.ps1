
# exemplos de como chamar o script

# $Version = "1.2.3.4"; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest https://raw.githubusercontent.com/hcavazin/scripts/master/update-zins.ps1 -UseBasicParsing | Invoke-Expression;

# $Version = "1.2.3.4"; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest http://127.0.0.1:5500//update-zins.ps1 -UseBasicParsing | Invoke-Expression;


# verificar se variavel $Version foi definida, se nao foi exibir mensagem e parar execucao do script
if (-not $Version) {
    Write-Host "Variável 'Version' não está definida. Por favor, defina-a antes de executar este script."
    return
}

# stop on error
$ErrorActionPreference = "Stop"

# baixar arquivo https://raw.githubusercontent.com/hcavazin/scripts/master/index.html
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hcavazin/scripts/master/index.html" -OutFile "C:\Zins\index.html"

# ir para diretorio C:\Zins
Set-Location C:\Zins

# write info
Write-Host "Updating Zins to version $Version"

# baixar 7za
$7zaUrl = "https://zinspublic.blob.core.windows.net/updates/utils/7za_x64.exe"
$7zaPath = "C:\Zins\7za.exe"
Invoke-WebRequest -Uri $7zaUrl -OutFile $7zaPath

# funcao para remover diretorio, caso exista
function Remove-Directory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }
}

# remover pastas antigas: Processor2, Transceiver2 e Workstation2
Remove-Directory -Path "C:\Zins\Processor2"
Remove-Directory -Path "C:\Zins\Transceiver2"
Remove-Directory -Path "C:\Zins\Workstation2"

# remover pastas novas: ZinsProcessor, ZinsTransceiver, ZinsWorkstation
Remove-Directory -Path "C:\Zins\ZinsProcessor"
Remove-Directory -Path "C:\Zins\ZinsTransceiver"
Remove-Directory -Path "C:\Zins\ZinsWorkstation"

$baseUrlTransceiver = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsTransceiver-$Version.7z"
$baseUrlProcessor = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsProcessor-$Version.7z"
$baseUrlWorkstation = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsWorkstation-$Version.7z"
$baseUrlCamServer = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsCamServer-$Version.7z"

$downloadPathTransceiver = "C:\Zins\ZinsTransceiver-$Version.7z"
$downloadPathProcessor = "C:\Zins\ZinsProcessor-$Version.7z"
$downloadPathWorkstation = "C:\Zins\ZinsWorkstation-$Version.7z"
$downloadPathCamServer = "C:\Zins\ZinsCamServer-$Version.7z"


# download
Write-Host "Downloading $baseUrlTransceiver"
Invoke-WebRequest -Uri $baseUrlTransceiver -OutFile $downloadPathTransceiver

Write-Host "Downloading $baseUrlProcessor"
Invoke-WebRequest -Uri $baseUrlProcessor -OutFile $downloadPathProcessor

Write-Host "Downloading $baseUrlWorkstation"
Invoke-WebRequest -Uri $baseUrlWorkstation -OutFile $downloadPathWorkstation

Write-Host "Downloading $baseUrlCamServer"
Invoke-WebRequest -Uri $baseUrlCamServer -OutFile $downloadPathCamServer

# Stop ZinsCamServer service if it is running
if (Get-Service -Name ZinsCamServer -ErrorAction SilentlyContinue) {
    Stop-Service -Name ZinsCamServer
}

# pegar todos os processos nginx.exe que estão na pasta C:\Zins\, imprimir caminho completo dos processos e matar
Get-Process | Where-Object { $_.ProcessName -eq 'nginx' -and $_.Path -like 'C:\Zins\*' } | ForEach-Object { Write-Host $_.Path; Stop-Process -Id $_.Id -Force }

# extrair arquivos
& $7zaPath x $downloadPathTransceiver -o"C:\Zins" -y
& $7zaPath x $downloadPathProcessor -o"C:\Zins" -y
& $7zaPath x $downloadPathWorkstation -o"C:\Zins" -y
& $7zaPath x $downloadPathCamServer -o"C:\Zins" -y

# Start ZinsCamServer service if it is not running
if (Get-Service -Name ZinsCamServer -ErrorAction SilentlyContinue) {
    Start-Service -Name ZinsCamServer
}

# remover arquivos baixados
Remove-Item -Path $downloadPathTransceiver
Remove-Item -Path $downloadPathProcessor
Remove-Item -Path $downloadPathWorkstation
Remove-Item -Path $downloadPathCamServer

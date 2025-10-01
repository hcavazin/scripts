# exemplos de como chamar o script

# $Version = "1.2.3.4"; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest https://raw.githubusercontent.com/hcavazin/scripts/master/update-zins.ps1 -UseBasicParsing | Invoke-Expression;

# $Version = "1.2.3.4"; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest http://127.0.0.1:5500//update-zins.ps1 -UseBasicParsing | Invoke-Expression;


# verificar se variavel $Version foi definida, se nao foi exibir mensagem e parar execucao do script
if (-not $Version)
{
    Write-Host "Variável 'Version' não está definida. Por favor, defina-a antes de executar este script."
    return
}

# stop on error
$ErrorActionPreference = "Stop"

# Verifica privilégios de administrador
$principal = New-Object Security.Principal.WindowsPrincipal(
[Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
{
    throw "Este script precisa ser executado como Administrador."
}

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
function Remove-Directory
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path $Path)
    {
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
if (Get-Service -Name ZinsCamServer -ErrorAction SilentlyContinue)
{
    Stop-Service -Name ZinsCamServer
}

# pegar todos os processos nginx.exe que estão na pasta C:\Zins\, imprimir caminho completo dos processos e matar
Get-Process | Where-Object { $_.ProcessName -eq 'nginx' -and $_.Path -like 'C:\Zins\*' } | ForEach-Object { Write-Host $_.Path; Stop-Process -Id $_.Id -Force }

# extrair arquivos
& $7zaPath x $downloadPathTransceiver -o"C:\Zins" -y
& $7zaPath x $downloadPathProcessor -o"C:\Zins" -y
& $7zaPath x $downloadPathWorkstation -o"C:\Zins" -y
& $7zaPath x $downloadPathCamServer -o"C:\Zins" -y

# remover arquivo ZinsCamServer\ZinsCamServerProxy.runtimeconfig.json
$runtimeConfigPath = "C:\Zins\ZinsCamServer\ZinsCamServerProxy.runtimeconfig.json"
if (Test-Path $runtimeConfigPath)
{
    Remove-Item -Path $runtimeConfigPath -Force
}

# Start ZinsCamServer service if it is not running
if (Get-Service -Name ZinsCamServer -ErrorAction SilentlyContinue)
{
    Start-Service -Name ZinsCamServer
}

# remover arquivos baixados
Remove-Item -Path $downloadPathTransceiver
Remove-Item -Path $downloadPathProcessor
Remove-Item -Path $downloadPathWorkstation
Remove-Item -Path $downloadPathCamServer

# === configuracao iis gzip inicio

# Local do appcmd.exe
$appcmd = Join-Path $env:windir 'System32\inetsrv\appcmd.exe'
if (-not (Test-Path $appcmd))
{
    throw "Não foi encontrado '$appcmd'. O IIS (Web Server) e suas ferramentas não parecem instalados."
}

# Local do appcmd.exe
$appcmd = Join-Path $env:windir 'System32\inetsrv\appcmd.exe'
if (-not (Test-Path $appcmd))
{
    throw "Não foi encontrado '$appcmd'. O IIS (Web Server) e suas ferramentas não parecem instalados."
}

function Run-AppCmd
{
    param([Parameter(Mandatory)][string[]]$Args)

    & $appcmd $Args
    if ($LASTEXITCODE -ne 0)
    {
        throw "Falha ao executar: $( $Args -join ' ' )"
    }
}

Write-Host "Desbloqueando seção (opcional)..." -ForegroundColor Cyan
Run-AppCmd @('unlock', 'config', '-section:system.webServer/httpCompression')

Write-Host "Atualizando staticTypes em httpCompression..." -ForegroundColor Cyan
# application/octet-stream
Run-AppCmd @('set', 'config', '-section:httpCompression',
'/-"staticTypes.[mimeType=''application/octet-stream'']"', '/commit:apphost')
Run-AppCmd @('set', 'config', '-section:httpCompression',
'/+"staticTypes.[mimeType=''application/octet-stream'',enabled=''true'']"', '/commit:apphost')

# application/x-ms-application
Run-AppCmd @('set', 'config', '-section:httpCompression',
'/-"staticTypes.[mimeType=''application/x-ms-application'']"', '/commit:apphost')
Run-AppCmd @('set', 'config', '-section:httpCompression',
'/+"staticTypes.[mimeType=''application/x-ms-application'',enabled=''true'']"', '/commit:apphost')

# application/x-ms-manifest
Run-AppCmd @('set', 'config', '-section:httpCompression',
'/-"staticTypes.[mimeType=''application/x-ms-manifest'']"', '/commit:apphost')
Run-AppCmd @('set', 'config', '-section:httpCompression',
'/+"staticTypes.[mimeType=''application/x-ms-manifest'',enabled=''true'']"', '/commit:apphost')

Write-Host "Garantindo flags de compressão (estática e dinâmica)..." -ForegroundColor Cyan
Run-AppCmd @('set', 'config', '-section:urlCompression',
'/doStaticCompression:True', '/doDynamicCompression:True', '/commit:apphost')

Write-Host "Ajustando serverRuntime..." -ForegroundColor Cyan
Run-AppCmd @('set', 'config', '-section:system.webServer/serverRuntime', '-frequentHitThreshold:1')
Run-AppCmd @('set', 'config', '-section:system.webServer/serverRuntime', '-frequentHitTimePeriod:00:01:00')

# === configuracao iis gzip fim

Write-Host "Concluído com sucesso." -ForegroundColor Green

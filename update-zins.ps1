# exemplos de como chamar o script

# forcar UTF-8 no console para acentos saírem corretos (Windows PowerShell 5.1
# por padrão usa a code page ANSI do sistema e quebra caracteres não-ASCII)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# verificar se variavel $Version foi definida, se nao foi exibir mensagem e parar execucao do script
if (-not $Version)
{
    Write-Host "Variavel 'Version' nao esta definida. Por favor, defina-a antes de executar este script."
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

Invoke-WebRequest -Uri "https://zinspublic.blob.core.windows.net/updates/script/index.html" -OutFile "C:\Zins\index.html"

# ir para diretorio C:\Zins
Set-Location C:\Zins

# write info
Write-Host "Updating Zins to version $Version"

# baixar 7za
$7zaUrl = "https://zinspublic.blob.core.windows.net/updates/utils/7za_x64.exe"
$7zaPath = "C:\Zins\7za.exe"
Invoke-WebRequest -Uri $7zaUrl -OutFile $7zaPath

# funcao para remover diretorio, caso exista
# usar cmd /c rmdir em vez de Remove-Item -Recurse: Remove-Item tem bug
# conhecido com diretorios profundos/ClickOnce ("directory is not empty")
function Remove-Directory
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path $Path)
    {
        cmd /c rmdir /s /q "`"$Path`""
        if ($LASTEXITCODE -ne 0 -or (Test-Path $Path))
        {
            throw "Falha ao remover '$Path' (rmdir exit code $LASTEXITCODE)."
        }
    }
}

# remover pastas antigas: Processor2, Transceiver2 e Workstation2
Remove-Directory -Path "C:\Zins\Processor2"
Remove-Directory -Path "C:\Zins\Transceiver2"
Remove-Directory -Path "C:\Zins\Workstation2"

# remover pastas temp de execucoes anteriores que possam ter falhado no meio
Remove-Directory -Path "C:\Zins\ZinsProcessor-new"
Remove-Directory -Path "C:\Zins\ZinsTransceiver-new"
Remove-Directory -Path "C:\Zins\ZinsWorkstation-new"
Remove-Directory -Path "C:\Zins\ZinsCamServer-new"

$baseUrlTransceiver = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsTransceiver-$Version.7z"
$baseUrlProcessor = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsProcessor-$Version.7z"
$baseUrlWorkstation = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsWorkstation-$Version.7z"
$baseUrlCamServer = "https://zinspublic.blob.core.windows.net/updates/zins/ZinsCamServer-$Version.7z"

# pasta de cache para .7z baixados — mantem C:\Zins\ limpa
$cacheDir = "C:\Zins\_update-cache"
if (-not (Test-Path $cacheDir)) { New-Item -Path $cacheDir -ItemType Directory | Out-Null }

# limpar versoes antigas do cache antes de baixar — libera espaco e evita
# acumulo se a execucao falhar antes do final
Get-ChildItem -Path $cacheDir -Filter "Zins*-*.7z" | Where-Object {
    $_.Name -notlike "*-$Version.7z"
} | Remove-Item -Force

$downloadPathTransceiver = "$cacheDir\ZinsTransceiver-$Version.7z"
$downloadPathProcessor = "$cacheDir\ZinsProcessor-$Version.7z"
$downloadPathWorkstation = "$cacheDir\ZinsWorkstation-$Version.7z"
$downloadPathCamServer = "$cacheDir\ZinsCamServer-$Version.7z"


# download com cache: se o .7z dessa versao ja existe, pula
# baixa para .tmp e renomeia ao final — assim um download interrompido
# nao deixa um .7z aparentemente valido para a proxima execucao usar
function Invoke-CachedDownload
{
    param (
        [Parameter(Mandatory = $true)] [string]$Url,
        [Parameter(Mandatory = $true)] [string]$Destination
    )

    if (Test-Path $Destination)
    {
        Write-Host "Cache hit: $Destination"
        return
    }

    $tmp = "$Destination.tmp"
    if (Test-Path $tmp) { Remove-Item $tmp -Force }

    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $tmp
    Rename-Item -Path $tmp -NewName (Split-Path $Destination -Leaf)
}

Invoke-CachedDownload -Url $baseUrlTransceiver -Destination $downloadPathTransceiver
Invoke-CachedDownload -Url $baseUrlProcessor   -Destination $downloadPathProcessor
Invoke-CachedDownload -Url $baseUrlWorkstation -Destination $downloadPathWorkstation
Invoke-CachedDownload -Url $baseUrlCamServer   -Destination $downloadPathCamServer

# extrair em pastas temp (-new) — assim, se outro update rodar concorrente,
# nao ve estado parcial nas pastas finais (Zins* sao ClickOnce)
# $ErrorActionPreference=Stop nao captura exit code de exe nativo, entao checa manualmente
# se o .7z tem raiz interna com mesmo nome (ex.: ZinsCamServer/ dentro do zip),
# achata para evitar caminho duplicado tipo C:\Zins\ZinsCamServer\ZinsCamServer\
function Invoke-7zExtract
{
    param (
        [Parameter(Mandatory = $true)] [string]$Archive,
        [Parameter(Mandatory = $true)] [string]$Destination
    )
    & $7zaPath x $Archive -o"$Destination" -y
    if ($LASTEXITCODE -ne 0)
    {
        throw "Falha ao extrair '$Archive' (7za exit code $LASTEXITCODE)."
    }

    # achatar raiz duplicada: se Destination contem subpasta com nome igual ao
    # "nome final" (Destination sem o sufixo -new), promove o conteudo dela.
    # Faz: move subpasta para Destination-flatten (nivel acima) -> apaga Destination -> renomeia flatten
    $finalName = (Split-Path $Destination -Leaf) -replace '-new$', ''
    $duplicated = Join-Path $Destination $finalName
    if (Test-Path $duplicated)
    {
        $tempFlatten = "$Destination-flatten"
        if (Test-Path $tempFlatten) { Remove-Directory -Path $tempFlatten }
        Move-Item -Path $duplicated -Destination $tempFlatten
        Remove-Directory -Path $Destination
        Rename-Item -Path $tempFlatten -NewName (Split-Path $Destination -Leaf)
    }
}

Invoke-7zExtract -Archive $downloadPathTransceiver -Destination "C:\Zins\ZinsTransceiver-new"
Invoke-7zExtract -Archive $downloadPathProcessor   -Destination "C:\Zins\ZinsProcessor-new"
Invoke-7zExtract -Archive $downloadPathWorkstation -Destination "C:\Zins\ZinsWorkstation-new"
Invoke-7zExtract -Archive $downloadPathCamServer   -Destination "C:\Zins\ZinsCamServer-new"

# remover arquivo ZinsCamServerProxy.runtimeconfig.json antes do swap
$runtimeConfigPath = "C:\Zins\ZinsCamServer-new\ZinsCamServerProxy.runtimeconfig.json"
if (Test-Path $runtimeConfigPath)
{
    Remove-Item -Path $runtimeConfigPath -Force
}

# Stop ZinsCamServer service if it is running (necessario antes de renomear pasta)
# Stop-Service retorna antes do processo realmente sair — esperar status Stopped
# para evitar erro de "arquivo em uso" no swap abaixo
$camService = Get-Service -Name ZinsCamServer -ErrorAction SilentlyContinue
if ($camService)
{
    Stop-Service -Name ZinsCamServer -Force
    $camService.WaitForStatus('Stopped', '00:00:30')
}

# pegar todos os processos nginx.exe que estão na pasta C:\Zins\, imprimir caminho completo dos processos e matar
Get-Process | Where-Object { $_.ProcessName -eq 'nginx' -and $_.Path -like 'C:\Zins\*' } | ForEach-Object { Write-Host $_.Path; Stop-Process -Id $_.Id -Force }

# swap atomico: remove pasta antiga e renomeia -new -> nome final
# usar cmd /c rmdir em vez de Remove-Item -Recurse: Remove-Item tem bug
# conhecido com diretorios profundos/ClickOnce ("directory is not empty")
function Swap-Directory
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$FinalPath,
        [Parameter(Mandatory = $true)]
        [string]$NewPath
    )

    if (Test-Path $FinalPath)
    {
        cmd /c rmdir /s /q "`"$FinalPath`""
        if ($LASTEXITCODE -ne 0 -or (Test-Path $FinalPath))
        {
            throw "Falha ao remover '$FinalPath' (rmdir exit code $LASTEXITCODE)."
        }
    }
    Rename-Item -Path $NewPath -NewName (Split-Path $FinalPath -Leaf)
}

Swap-Directory -FinalPath "C:\Zins\ZinsTransceiver" -NewPath "C:\Zins\ZinsTransceiver-new"
Swap-Directory -FinalPath "C:\Zins\ZinsProcessor"   -NewPath "C:\Zins\ZinsProcessor-new"
Swap-Directory -FinalPath "C:\Zins\ZinsWorkstation" -NewPath "C:\Zins\ZinsWorkstation-new"
Swap-Directory -FinalPath "C:\Zins\ZinsCamServer"   -NewPath "C:\Zins\ZinsCamServer-new"

# Start ZinsCamServer service if it is not running
if (Get-Service -Name ZinsCamServer -ErrorAction SilentlyContinue)
{
    Start-Service -Name ZinsCamServer
}

# === configuracao iis gzip inicio

# Local do appcmd.exe
$appcmd = Join-Path $env:windir 'System32\inetsrv\appcmd.exe'
if (-not (Test-Path $appcmd))
{
    throw "Nao foi encontrado '$appcmd'. O IIS (Web Server) e suas ferramentas nao parecem instalados."
}

# (Opcional) garantir que a seção não está bloqueada para sites
& $appcmd unlock config -section:system.webServer/httpCompression

# Adicionar tipos estáticos (sem duplicar)
& $appcmd set config -section:httpCompression /-"staticTypes.[mimeType='application/octet-stream']" /commit:apphost
& $appcmd set config -section:httpCompression /+"staticTypes.[mimeType='application/octet-stream',enabled='true']" /commit:apphost

& $appcmd set config -section:httpCompression /-"staticTypes.[mimeType='application/x-ms-application']" /commit:apphost
& $appcmd set config -section:httpCompression /+"staticTypes.[mimeType='application/x-ms-application',enabled='true']" /commit:apphost

& $appcmd set config -section:httpCompression /-"staticTypes.[mimeType='application/x-ms-manifest']" /commit:apphost
& $appcmd set config -section:httpCompression /+"staticTypes.[mimeType='application/x-ms-manifest',enabled='true']" /commit:apphost

# (Opcional) garantir flags de compressão
& $appcmd set config -section:urlCompression /doStaticCompression:"True" /doDynamicCompression:"True" /commit:apphost

# Configurar frequentHitThreshold
& $appcmd set config -section:system.webServer/serverRuntime -frequentHitThreshold:1

# Configurar frequentHitTimePeriod
& $appcmd set config -section:system.webServer/serverRuntime -frequentHitTimePeriod:00:01:00

# === configuracao iis gzip fim

Clear-Host
Write-Host "Concluido com sucesso." -ForegroundColor Green

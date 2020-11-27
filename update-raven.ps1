
# https://stackoverflow.com/a/9949909/4862220
# $ErrorActionPreference = "Stop"

$versaoRaven = "5.1.0"
Write-Host "Versao RavenDB: $versaoRaven"

if (!(Test-Path "c:\ravendb")) {
    New-Item "c:\ravendb" -ItemType Directory
}

Write-Host "Baixando RavenDB..."
Invoke-WebRequest "https://daily-builds.s3.amazonaws.com/RavenDB-$versaoRaven-windows-x64.zip" -UseBasicParsing -OutFile "c:\ravendb\_download.zip"

Write-Host "Parando Zins Processor..."
taskkill /F /T /IM ZinsProcessor.exe

Write-Host "Parando RavenDB..."
net stop ravendb
taskkill /F /T /IM Raven.Server.exe
timeout 3

# https://stackoverflow.com/a/52143053/4862220
Write-Host "Removendo arquivos antigos..."
Get-ChildItem "C:\ravendb\Server" -Exclude settings.json, *.pfx, RavenData, Logs, Packages | Remove-Item -Force -Recurse

Write-Host "Extraindo arquivos..."
Expand-Archive "c:\ravendb\_download.zip" "c:\ravendb" -Force

[System.Environment]::SetEnvironmentVariable('RAVEN_Http_Protocols', 'Http1', [System.EnvironmentVariableTarget]::Machine)

Write-Host "Iniciando RavenDB..."
net start ravendb

Write-Host "Iniciando Zins Processor..."
Start-Process "$env:LOCALAPPDATA\ZinsProcessor2\ZinsProcessor.exe"

Write-Host "Baixando scripts..."
Invoke-WebRequest "https://raw.githubusercontent.com/hcavazin/scripts/master/adicionar-no-update.zip" -UseBasicParsing -OutFile "c:\ravendb\_adicionar-no-update.zip"
Expand-Archive "c:\ravendb\_adicionar-no-update.zip" "c:\ravendb" -Force

Start-Process "https://a.generic.ravendb.zinsc.com:883/studio/index.html#databases/documents?&database=Zins2"

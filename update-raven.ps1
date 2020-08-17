
# https://stackoverflow.com/a/9949105
# $ErrorActionPreference = "Stop"

$versaoRaven = "5.0.2"

if (!(Test-Path "c:\ravendb")) {
    New-Item "c:\ravendb" -ItemType Directory
}

Set-Location "c:\ravendb"

Write-Host "Baixando RavenDB"
Invoke-WebRequest "https://daily-builds.s3.amazonaws.com/RavenDB-$versaoRaven-windows-x64.zip" -OutFile "_download.zip"

Write-Host "Parando Zins Processor"
taskkill /F /T /IM ZinsProcessor.exe

Write-Host "Parando RavenDB"
net stop ravendb
taskkill /F /T /IM Raven.Server.exe
timeout 3

Write-Host "Extraindo arquivos"
Expand-Archive "c:\ravendb\_download.zip" -DestinationPath "c:\ravendb" -Force

[System.Environment]::SetEnvironmentVariable('RAVEN_Http_Protocols', 'Http1', [System.EnvironmentVariableTarget]::Machine)

Write-Host "Iniciando RavenDB"
net start ravendb

Write-Host "Iniciando Zins Processor"
Start-Process "$env:LOCALAPPDATA\ZinsProcessor2\ZinsProcessor.exe"

Start-Process "https://a.generic.ravendb.zinsc.com:883/studio/index.html#databases/documents?&database=Zins2"

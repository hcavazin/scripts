
# https://stackoverflow.com/a/9949909/4862220
# $ErrorActionPreference = "Stop"

$versaoRaven = "5.0.2"

# https://stackoverflow.com/a/51754442/4862220
function Unzip($zipfile, $outdir) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipfile)
    try {
        foreach ($entry in $archive.Entries) {
            $entryTargetFilePath = [System.IO.Path]::Combine($outdir, $entry.FullName)
            $entryDir = [System.IO.Path]::GetDirectoryName($entryTargetFilePath)

            #Ensure the directory of the archive entry exists
            if (!(Test-Path $entryDir )) {
                New-Item -ItemType Directory -Path $entryDir | Out-Null
            }

            #If the entry is not a directory entry, then extract entry
            if (!$entryTargetFilePath.EndsWith("\")) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryTargetFilePath, $true);
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

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
Unzip "c:\ravendb\_download.zip" "c:\ravendb"

[System.Environment]::SetEnvironmentVariable('RAVEN_Http_Protocols', 'Http1', [System.EnvironmentVariableTarget]::Machine)

Write-Host "Iniciando RavenDB"
net start ravendb

Write-Host "Iniciando Zins Processor"
Start-Process "$env:LOCALAPPDATA\ZinsProcessor2\ZinsProcessor.exe"

Start-Process "https://a.generic.ravendb.zinsc.com:883/studio/index.html#databases/documents?&database=Zins2"

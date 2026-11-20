$ErrorActionPreference = 'Stop'
try {
    $runtime = Join-Path $PSScriptRoot 'runtime'
    $downloads = Join-Path $PSScriptRoot '.downloads'
    New-Item -ItemType Directory -Force -Path $downloads | Out-Null
    $python = Join-Path $runtime 'python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        Write-Host 'Downloading Python 3.12.10...'
        $archive = Join-Path $downloads 'python.zip'
        Invoke-WebRequest 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip' -OutFile $archive
        Expand-Archive -LiteralPath $archive -DestinationPath $runtime -Force
    }
    @('python312.zip','.','Lib\site-packages','..','import site') | Set-Content -Encoding ascii -LiteralPath (Join-Path $runtime 'python312._pth')
    if (-not (Test-Path -LiteralPath (Join-Path $runtime 'Lib\site-packages\pip'))) {
        $bootstrap = Join-Path $downloads 'get-pip.py'
        Invoke-WebRequest 'https://bootstrap.pypa.io/get-pip.py' -OutFile $bootstrap
        & $python $bootstrap --no-warn-script-location
        if ($LASTEXITCODE -ne 0) { throw 'Python package installer failed.' }
    }
    & $python -m pip install -r (Join-Path $PSScriptRoot 'requirements-lock.txt') --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { throw 'Package installation failed.' }
    Write-Host 'Downloading models (about 5.1 GB)...'
    & $python (Join-Path $PSScriptRoot 'download_models.py')
    if ($LASTEXITCODE -ne 0) { throw 'Model download failed. Run the installer again to retry.' }
    Write-Host 'Ready! Start the program with Starta.vbs.'
    Write-Host 'For the context menu, run Installera-hogerklick.cmd.'
} catch {
    Write-Host ('Installation failed: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

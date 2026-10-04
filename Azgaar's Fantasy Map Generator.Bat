@echo off
setlocal
set "AFMG_INSTALLER_SELF=%~f0"
set "AFMG_INSTALLER_DIR=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$raw=[System.IO.File]::ReadAllText($env:AFMG_INSTALLER_SELF); $marker=('#'+'==POWERSHELL=='); $i=$raw.IndexOf($marker); if($i -lt 0){throw 'Embedded PowerShell payload not found.'}; $code=$raw.Substring($i+$marker.Length); Invoke-Expression $code"
set "AFMG_EXIT=%ERRORLEVEL%"
endlocal & exit /b %AFMG_EXIT%
#==POWERSHELL==

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:RepoUrl = 'https://github.com/Azgaar/Fantasy-Map-Generator.git'
$script:RepoZipUrl = 'https://github.com/Azgaar/Fantasy-Map-Generator/archive/refs/heads/master.zip'
$script:DefaultInstallDir = "C:\Azgaar's Fantasy Map"
$script:InstallerSelf = [IO.Path]::GetFullPath($env:AFMG_INSTALLER_SELF)
$script:SourceDir = [IO.Path]::GetFullPath($env:AFMG_INSTALLER_DIR).TrimEnd([IO.Path]::DirectorySeparatorChar)
$script:Mode = 'Install'
$script:InstallDir = $script:DefaultInstallDir
$script:NpmInstalled = $false
$script:PendingDelete = $null
$script:RepairBackup = $null

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show($Message, "Azgaar's Fantasy Map Generator", 'OK', 'Error') | Out-Null
}

function Show-Info([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show($Message, "Azgaar's Fantasy Map Generator", 'OK', 'Information') | Out-Null
}

function Confirm-Action([string]$Message) {
    $r = [System.Windows.Forms.MessageBox]::Show($Message, "Azgaar's Fantasy Map Generator", 'YesNo', 'Warning')
    return $r -eq [System.Windows.Forms.DialogResult]::Yes
}

function Normalize-Path([string]$Path) {
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if ([string]::IsNullOrWhiteSpace($expanded)) { return $script:DefaultInstallDir }
    return [IO.Path]::GetFullPath($expanded).TrimEnd([IO.Path]::DirectorySeparatorChar)
}

function Test-PathInside([string]$Child, [string]$Parent) {
    $childFull = ([IO.Path]::GetFullPath($Child)).TrimEnd('\') + '\'
    $parentFull = ([IO.Path]::GetFullPath($Parent)).TrimEnd('\') + '\'
    return $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-WritableInstallPath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    $probe = Join-Path $Path ('.afmg-write-test-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($probe, 'test')
    } finally {
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    }
}

function Test-RepoRoot([string]$Path) {
    $pkg = Join-Path $Path 'package.json'
    if (-not (Test-Path -LiteralPath $pkg)) { return $false }
    try {
        $json = Get-Content -LiteralPath $pkg -Raw | ConvertFrom-Json
        return $json.name -eq 'fantasy-map-generator'
    } catch {
        return $false
    }
}

function Invoke-RobocopyTree([string]$Source, [string]$Destination, [string[]]$ExtraExcludeDirs = @()) {
    if (-not (Test-Path -LiteralPath $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }
    $args = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:2', '/W:1', '/NFL', '/NDL', '/NP')
    $exclude = @('node_modules', 'runtime', '.vite', 'dist', 'dist-electron') + $ExtraExcludeDirs
    if ($exclude.Count -gt 0) {
        $args += '/XD'
        $args += $exclude
    }
    & robocopy.exe @args | Out-Null
    $code = $LASTEXITCODE
    if ($code -ge 8) { throw "Robocopy failed with exit code $code." }
}

function Download-RepoTo([string]$Destination) {
    $zip = Join-Path $env:TEMP ('afmg-repo-' + [guid]::NewGuid().ToString('N') + '.zip')
    $extract = Join-Path $env:TEMP ('afmg-repo-' + [guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $script:RepoZipUrl -OutFile $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
        $root = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
        if (-not $root) { throw 'Downloaded repository archive did not contain a source directory.' }
        Invoke-RobocopyTree $root.FullName $Destination
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Copy-InstallerToTarget([string]$Destination) {
    $destFile = Join-Path $Destination "Azgaar's Fantasy Map Generator.Bat"
    if (-not $script:InstallerSelf.Equals($destFile, [StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $script:InstallerSelf -Destination $destFile -Force
    }
}

function Ensure-ApplicationFiles([string]$Destination, [bool]$PreferFreshDownload) {
    Assert-WritableInstallPath $Destination

    $manifestPath = Join-Path $Destination '.afmg-installer.json'
    $existingItems = @(Get-ChildItem -LiteralPath $Destination -Force -ErrorAction SilentlyContinue)
    $sameAsSource = $script:SourceDir.Equals($Destination, [StringComparison]::OrdinalIgnoreCase)
    if ($existingItems.Count -gt 0 -and -not (Test-RepoRoot $Destination) -and -not (Test-Path -LiteralPath $manifestPath) -and -not $sameAsSource) {
        if (-not (Confirm-Action "The selected folder is not empty and is not recognized as an existing Fantasy Map Generator installation:`n`n$Destination`n`nInstalling here may overwrite files. Continue?")) {
            throw 'Installation cancelled.'
        }
    }

    if ($PreferFreshDownload) {
        try {
            Download-RepoTo $Destination
        } catch {
            if ((Test-RepoRoot $script:SourceDir) -and -not $script:SourceDir.Equals($Destination, [StringComparison]::OrdinalIgnoreCase)) {
                Invoke-RobocopyTree $script:SourceDir $Destination
            } elseif (-not (Test-RepoRoot $Destination)) {
                throw
            }
        }
    } elseif (Test-RepoRoot $script:SourceDir) {
        if (-not $script:SourceDir.Equals($Destination, [StringComparison]::OrdinalIgnoreCase)) {
            if (Test-PathInside $Destination $script:SourceDir) {
                Download-RepoTo $Destination
            } else {
                Invoke-RobocopyTree $script:SourceDir $Destination
            }
        }
    } elseif (-not (Test-RepoRoot $Destination)) {
        Download-RepoTo $Destination
    }

    if (-not (Test-RepoRoot $Destination)) {
        throw 'The selected installation directory does not contain a valid Fantasy Map Generator repository.'
    }

    Copy-InstallerToTarget $Destination
}

function Backup-UserData([string]$Destination) {
    $backup = Join-Path $env:TEMP ('afmg-repair-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null

    $dirs = @('UserData', 'user-data', 'maps', 'assets', 'user-assets', 'custom-assets', '_user_assets')
    foreach ($name in $dirs) {
        $src = Join-Path $Destination $name
        if (Test-Path -LiteralPath $src) {
            $dst = Join-Path $backup $name
            Invoke-RobocopyTree $src $dst @()
        }
    }

    if (Test-Path -LiteralPath $Destination) {
        $mapRoot = Join-Path $backup '__map_files'
        Get-ChildItem -LiteralPath $Destination -Filter '*.map' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(node_modules|runtime|\.git)\\' } |
            ForEach-Object {
                $relative = $_.FullName.Substring($Destination.Length).TrimStart('\')
                $target = Join-Path $mapRoot $relative
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $target -Force
            }
    }
    return $backup
}

function Restore-UserData([string]$Destination, [string]$Backup) {
    if (-not $Backup -or -not (Test-Path -LiteralPath $Backup)) { return }
    Get-ChildItem -LiteralPath $Backup -Directory | Where-Object { $_.Name -ne '__map_files' } | ForEach-Object {
        Invoke-RobocopyTree $_.FullName (Join-Path $Destination $_.Name) @()
    }
    $mapRoot = Join-Path $Backup '__map_files'
    if (Test-Path -LiteralPath $mapRoot) {
        Get-ChildItem -LiteralPath $mapRoot -Filter '*.map' -File -Recurse | ForEach-Object {
            $relative = $_.FullName.Substring($mapRoot.Length).TrimStart('\')
            $target = Join-Path $Destination $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
    }
}

function Prepare-Repair([string]$Destination) {
    if (-not (Test-RepoRoot $Destination)) {
        throw 'Repair requires an existing Fantasy Map Generator installation in the selected folder.'
    }

    $script:RepairBackup = Backup-UserData $Destination
    Remove-Item -LiteralPath (Join-Path $Destination 'node_modules') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $Destination 'runtime') -Recurse -Force -ErrorAction SilentlyContinue

    Ensure-ApplicationFiles $Destination $true
    Restore-UserData $Destination $script:RepairBackup
}

function Get-LocalNodeInfo([string]$Destination) {
    $node = Join-Path $Destination 'runtime\node\node.exe'
    $npm = Join-Path $Destination 'runtime\node\npm.cmd'
    if (-not (Test-Path -LiteralPath $node) -or -not (Test-Path -LiteralPath $npm)) {
        return [pscustomobject]@{ Valid=$false; Version=$null; Major=0; Node=$node; Npm=$npm }
    }
    try {
        $version = (& $node --version 2>$null).Trim()
        $major = [int](($version.TrimStart('v')).Split('.')[0])
        return [pscustomobject]@{ Valid=($major -ge 24); Version=$version; Major=$major; Node=$node; Npm=$npm }
    } catch {
        return [pscustomobject]@{ Valid=$false; Version=$null; Major=0; Node=$node; Npm=$npm }
    }
}

function Install-LocalNode([string]$Destination) {
    $runtime = Join-Path $Destination 'runtime'
    $nodeDir = Join-Path $runtime 'node'
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null
    Remove-Item -LiteralPath $nodeDir -Recurse -Force -ErrorAction SilentlyContinue

    $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
    $release = $index | Where-Object { $_.version -match '^v24\.' } | Select-Object -First 1
    if (-not $release) { throw 'Could not find a Node.js 24.x release from nodejs.org.' }

    $arch = 'x64'
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { $arch = 'arm64' }
    $file = "node-$($release.version)-win-$arch.zip"
    $base = "https://nodejs.org/dist/$($release.version)"
    $zip = Join-Path $env:TEMP ('afmg-node-' + [guid]::NewGuid().ToString('N') + '.zip')
    $sumFile = Join-Path $env:TEMP ('afmg-node-' + [guid]::NewGuid().ToString('N') + '.txt')
    $extract = Join-Path $env:TEMP ('afmg-node-' + [guid]::NewGuid().ToString('N'))

    try {
        Invoke-WebRequest -UseBasicParsing -Uri "$base/$file" -OutFile $zip
        Invoke-WebRequest -UseBasicParsing -Uri "$base/SHASUMS256.txt" -OutFile $sumFile
        $expectedLine = Get-Content -LiteralPath $sumFile | Where-Object { $_ -match "\s+$([regex]::Escape($file))$" } | Select-Object -First 1
        if (-not $expectedLine) { throw 'Could not locate Node.js archive checksum.' }
        $expected = ($expectedLine -split '\s+')[0].ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expected -ne $actual) { throw 'Node.js archive checksum verification failed.' }

        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
        $root = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
        if (-not $root) { throw 'Node.js archive did not contain the expected directory.' }
        New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null
        Get-ChildItem -LiteralPath $root.FullName -Force | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination $nodeDir -Force
        }
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $sumFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    }

    $info = Get-LocalNodeInfo $Destination
    if (-not $info.Valid) { throw 'Node.js was extracted, but version verification failed.' }
    return $info
}

function Ensure-Node24([string]$Destination) {
    $info = Get-LocalNodeInfo $Destination
    if ($info.Valid) { return $info }
    return Install-LocalNode $Destination
}

function New-NpmInstallCommand([string]$Destination) {
    $info = Get-LocalNodeInfo $Destination
    if (-not $info.Valid) { throw 'Local Node.js 24+ is not installed.' }
    $cmd = Join-Path $env:TEMP ('afmg-npm-' + [guid]::NewGuid().ToString('N') + '.cmd')
    $nodeDir = Split-Path -Parent $info.Node
    $content = @"
@echo off
setlocal
title Azgaar's Fantasy Map Generator - Installing dependencies
set "PATH=$nodeDir;%PATH%"
cd /d "$Destination"
echo.
echo Installing npm dependencies in:
echo   $Destination
echo.
call "$($info.Npm)" install
set "AFMG_NPM_EXIT=%ERRORLEVEL%"
echo.
if not "%AFMG_NPM_EXIT%"=="0" (
  echo npm install failed with exit code %AFMG_NPM_EXIT%.
  echo Review the messages above.
  pause
)
exit /b %AFMG_NPM_EXIT%
"@
    Set-Content -LiteralPath $cmd -Value $content -Encoding ASCII
    return $cmd
}

function Run-NpmInstall([string]$Destination) {
    $cmd = New-NpmInstallCommand $Destination
    try {
        $p = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/c',('"' + $cmd + '"')) -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "npm install failed with exit code $($p.ExitCode)." }
    } finally {
        Remove-Item -LiteralPath $cmd -Force -ErrorAction SilentlyContinue
    }
}

function Write-RunLauncher([string]$Destination) {
    $info = Get-LocalNodeInfo $Destination
    if (-not $info.Valid) { throw 'Cannot create launcher because local Node.js 24+ is unavailable.' }
    $runBat = Join-Path $Destination "Run Azgaar's Fantasy Map Generator.bat"
    $nodeDir = Split-Path -Parent $info.Node
    $content = @"
@echo off
setlocal
set "PATH=$nodeDir;%PATH%"
cd /d "$Destination"
title Azgaar's Fantasy Map Generator
call "$($info.Npm)" run dev
set "AFMG_DEV_EXIT=%ERRORLEVEL%"
echo.
if not "%AFMG_DEV_EXIT%"=="0" echo Development server exited with code %AFMG_DEV_EXIT%.
pause
exit /b %AFMG_DEV_EXIT%
"@
    Set-Content -LiteralPath $runBat -Value $content -Encoding ASCII
    return $runBat
}

function Write-InstallManifest([string]$Destination) {
    $pkg = Get-Content -LiteralPath (Join-Path $Destination 'package.json') -Raw | ConvertFrom-Json
    $node = Get-LocalNodeInfo $Destination
    $manifest = [ordered]@{
        product = "Azgaar's Fantasy Map Generator"
        appVersion = $pkg.version
        nodeVersion = $node.Version
        installedAt = (Get-Date).ToString('o')
        installRoot = $Destination
        repository = $script:RepoUrl
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Destination '.afmg-installer.json') -Encoding UTF8
}

function Start-DevServer([string]$Destination) {
    $runBat = Join-Path $Destination "Run Azgaar's Fantasy Map Generator.bat"
    if (-not (Test-Path -LiteralPath $runBat)) { $runBat = Write-RunLauncher $Destination }
    Start-Process -FilePath $env:ComSpec -WorkingDirectory $Destination -ArgumentList @('/d','/k',('"' + $runBat + '"')) | Out-Null
}

function Invoke-Uninstall([string]$Destination) {
    if (-not (Test-Path -LiteralPath $Destination)) { return }
    $manifestPath = Join-Path $Destination '.afmg-installer.json'
    if (-not (Test-RepoRoot $Destination) -and -not (Test-Path -LiteralPath $manifestPath)) {
        throw 'Safety stop: the selected folder is not recognized as a Fantasy Map Generator installation. Uninstall will not delete it.'
    }
    if (-not (Confirm-Action "This will remove the repository, node_modules, the local Node.js runtime, and all other files under:`n`n$Destination`n`nContinue?")) {
        throw 'Uninstall cancelled.'
    }

    $selfInside = Test-PathInside $script:InstallerSelf $Destination
    if ($selfInside) {
        Get-ChildItem -LiteralPath $Destination -Force | Where-Object {
            -not $_.FullName.Equals($script:InstallerSelf, [StringComparison]::OrdinalIgnoreCase)
        } | Remove-Item -Recurse -Force -ErrorAction Stop
        $script:PendingDelete = $Destination
    } else {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
}

function Schedule-PendingDelete {
    if (-not $script:PendingDelete) { return }
    $target = $script:PendingDelete
    $cmd = 'ping 127.0.0.1 -n 3 >nul & rmdir /s /q "' + $target.Replace('"','') + '"'
    Start-Process -FilePath $env:ComSpec -WindowStyle Hidden -ArgumentList @('/d','/c',$cmd) | Out-Null
}

# --- GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Azgaar's Fantasy Map Generator Setup"
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(820, 560)
$form.MinimumSize = New-Object System.Drawing.Size(820, 560)
$form.MaximizeBox = $false
$form.FormBorderStyle = 'FixedDialog'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$header = New-Object System.Windows.Forms.Label
$header.Location = New-Object System.Drawing.Point(28, 18)
$header.Size = New-Object System.Drawing.Size(750, 34)
$header.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$header.Text = "Azgaar's Fantasy Map Generator Setup"
$form.Controls.Add($header)

$stepLabel = New-Object System.Windows.Forms.Label
$stepLabel.Location = New-Object System.Drawing.Point(31, 58)
$stepLabel.Size = New-Object System.Drawing.Size(740, 22)
$stepLabel.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($stepLabel)

$line = New-Object System.Windows.Forms.Label
$line.BorderStyle = 'Fixed3D'
$line.Location = New-Object System.Drawing.Point(30, 88)
$line.Size = New-Object System.Drawing.Size(748, 2)
$form.Controls.Add($line)

$panelHost = New-Object System.Windows.Forms.Panel
$panelHost.Location = New-Object System.Drawing.Point(30, 105)
$panelHost.Size = New-Object System.Drawing.Size(748, 350)
$form.Controls.Add($panelHost)

$backButton = New-Object System.Windows.Forms.Button
$backButton.Text = '< Back'
$backButton.Location = New-Object System.Drawing.Point(548, 472)
$backButton.Size = New-Object System.Drawing.Size(105, 34)
$form.Controls.Add($backButton)

$nextButton = New-Object System.Windows.Forms.Button
$nextButton.Text = 'Next >'
$nextButton.Location = New-Object System.Drawing.Point(665, 472)
$nextButton.Size = New-Object System.Drawing.Size(105, 34)
$form.Controls.Add($nextButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Location = New-Object System.Drawing.Point(30, 472)
$cancelButton.Size = New-Object System.Drawing.Size(105, 34)
$form.Controls.Add($cancelButton)

$panels = @()
for ($i=0; $i -lt 5; $i++) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = 'Fill'
    $p.Visible = $false
    $panelHost.Controls.Add($p)
    $panels += $p
}

# Page 1
$p1Title = New-Object System.Windows.Forms.Label
$p1Title.Text = 'Choose an action'
$p1Title.Location = New-Object System.Drawing.Point(0, 8)
$p1Title.Size = New-Object System.Drawing.Size(700, 30)
$p1Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[0].Controls.Add($p1Title)

$installRadio = New-Object System.Windows.Forms.RadioButton
$installRadio.Text = 'Install'
$installRadio.Location = New-Object System.Drawing.Point(10, 58)
$installRadio.Size = New-Object System.Drawing.Size(200, 28)
$installRadio.Checked = $true
$panels[0].Controls.Add($installRadio)

$installDesc = New-Object System.Windows.Forms.Label
$installDesc.Text = 'Copy or download the repository, install a private Node.js 24.x runtime, and install npm dependencies.'
$installDesc.Location = New-Object System.Drawing.Point(35, 87)
$installDesc.Size = New-Object System.Drawing.Size(680, 45)
$installDesc.ForeColor = [System.Drawing.Color]::DimGray
$panels[0].Controls.Add($installDesc)

$repairRadio = New-Object System.Windows.Forms.RadioButton
$repairRadio.Text = 'Repair'
$repairRadio.Location = New-Object System.Drawing.Point(10, 142)
$repairRadio.Size = New-Object System.Drawing.Size(200, 28)
$panels[0].Controls.Add($repairRadio)

$repairDesc = New-Object System.Windows.Forms.Label
$repairDesc.Text = 'Refresh application files and reinstall Node/npm dependencies while preserving user maps and common user-asset folders.'
$repairDesc.Location = New-Object System.Drawing.Point(35, 171)
$repairDesc.Size = New-Object System.Drawing.Size(680, 48)
$repairDesc.ForeColor = [System.Drawing.Color]::DimGray
$panels[0].Controls.Add($repairDesc)

$uninstallRadio = New-Object System.Windows.Forms.RadioButton
$uninstallRadio.Text = 'Uninstall'
$uninstallRadio.Location = New-Object System.Drawing.Point(10, 230)
$uninstallRadio.Size = New-Object System.Drawing.Size(200, 28)
$panels[0].Controls.Add($uninstallRadio)

$uninstallDesc = New-Object System.Windows.Forms.Label
$uninstallDesc.Text = 'Remove the selected installation folder, including the repository, node_modules, and the locally installed Node.js runtime.'
$uninstallDesc.Location = New-Object System.Drawing.Point(35, 259)
$uninstallDesc.Size = New-Object System.Drawing.Size(680, 48)
$uninstallDesc.ForeColor = [System.Drawing.Color]::DimGray
$panels[0].Controls.Add($uninstallDesc)

# Page 2
$p2Title = New-Object System.Windows.Forms.Label
$p2Title.Text = 'Choose installation directory'
$p2Title.Location = New-Object System.Drawing.Point(0, 8)
$p2Title.Size = New-Object System.Drawing.Size(700, 30)
$p2Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[1].Controls.Add($p2Title)

$p2Desc = New-Object System.Windows.Forms.Label
$p2Desc.Text = 'The repository, local Node.js runtime, and npm dependencies will live inside this folder.'
$p2Desc.Location = New-Object System.Drawing.Point(0, 48)
$p2Desc.Size = New-Object System.Drawing.Size(700, 45)
$panels[1].Controls.Add($p2Desc)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(0, 110)
$pathBox.Size = New-Object System.Drawing.Size(610, 28)
$pathBox.Text = $script:DefaultInstallDir
$panels[1].Controls.Add($pathBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Browse...'
$browseButton.Location = New-Object System.Drawing.Point(620, 107)
$browseButton.Size = New-Object System.Drawing.Size(105, 32)
$panels[1].Controls.Add($browseButton)

$p2Note = New-Object System.Windows.Forms.Label
$p2Note.Text = "Default: $($script:DefaultInstallDir)`nTip: if Windows blocks writing to C:\, choose a folder under your user profile or rerun the installer as Administrator."
$p2Note.Location = New-Object System.Drawing.Point(0, 160)
$p2Note.Size = New-Object System.Drawing.Size(720, 70)
$p2Note.ForeColor = [System.Drawing.Color]::DimGray
$panels[1].Controls.Add($p2Note)

# Page 3
$p3Title = New-Object System.Windows.Forms.Label
$p3Title.Text = 'Node.js 24+ runtime'
$p3Title.Location = New-Object System.Drawing.Point(0, 8)
$p3Title.Size = New-Object System.Drawing.Size(700, 30)
$p3Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[2].Controls.Add($p3Title)

$nodeStatus = New-Object System.Windows.Forms.Label
$nodeStatus.Location = New-Object System.Drawing.Point(0, 58)
$nodeStatus.Size = New-Object System.Drawing.Size(720, 80)
$nodeStatus.Text = 'The setup will check for Node.js 24+ inside the installation root.'
$panels[2].Controls.Add($nodeStatus)

$nodeButton = New-Object System.Windows.Forms.Button
$nodeButton.Text = 'Install / Verify Node.js 24+'
$nodeButton.Location = New-Object System.Drawing.Point(0, 150)
$nodeButton.Size = New-Object System.Drawing.Size(235, 36)
$panels[2].Controls.Add($nodeButton)

$nodeNote = New-Object System.Windows.Forms.Label
$nodeNote.Text = 'This does not install Node system-wide. It downloads the official Windows ZIP from nodejs.org, verifies SHA-256, and extracts it under runtime\node.'
$nodeNote.Location = New-Object System.Drawing.Point(0, 205)
$nodeNote.Size = New-Object System.Drawing.Size(710, 70)
$nodeNote.ForeColor = [System.Drawing.Color]::DimGray
$panels[2].Controls.Add($nodeNote)

# Page 4
$p4Title = New-Object System.Windows.Forms.Label
$p4Title.Text = 'Install dependencies'
$p4Title.Location = New-Object System.Drawing.Point(0, 8)
$p4Title.Size = New-Object System.Drawing.Size(700, 30)
$p4Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[3].Controls.Add($p4Title)

$p4Desc = New-Object System.Windows.Forms.Label
$p4Desc.Location = New-Object System.Drawing.Point(0, 53)
$p4Desc.Size = New-Object System.Drawing.Size(715, 90)
$p4Desc.Text = "Setup will open a terminal and run:`n`n    npm install`n`nThe development server is started later with the Run button so the installer can finish normally."
$panels[3].Controls.Add($p4Desc)

$npmButton = New-Object System.Windows.Forms.Button
$npmButton.Text = 'Open Terminal and Install'
$npmButton.Location = New-Object System.Drawing.Point(0, 170)
$npmButton.Size = New-Object System.Drawing.Size(220, 38)
$panels[3].Controls.Add($npmButton)

$npmStatus = New-Object System.Windows.Forms.Label
$npmStatus.Location = New-Object System.Drawing.Point(0, 230)
$npmStatus.Size = New-Object System.Drawing.Size(710, 70)
$npmStatus.ForeColor = [System.Drawing.Color]::DimGray
$npmStatus.Text = 'Not started.'
$panels[3].Controls.Add($npmStatus)

# Page 5
$p5Title = New-Object System.Windows.Forms.Label
$p5Title.Text = 'Setup complete'
$p5Title.Location = New-Object System.Drawing.Point(0, 8)
$p5Title.Size = New-Object System.Drawing.Size(700, 30)
$p5Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[4].Controls.Add($p5Title)

$finishText = New-Object System.Windows.Forms.Label
$finishText.Location = New-Object System.Drawing.Point(0, 58)
$finishText.Size = New-Object System.Drawing.Size(715, 100)
$panels[4].Controls.Add($finishText)

$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = 'Run'
$runButton.Location = New-Object System.Drawing.Point(0, 180)
$runButton.Size = New-Object System.Drawing.Size(130, 40)
$panels[4].Controls.Add($runButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = 'Exit'
$exitButton.Location = New-Object System.Drawing.Point(145, 180)
$exitButton.Size = New-Object System.Drawing.Size(130, 40)
$panels[4].Controls.Add($exitButton)

$currentPage = 0

function Refresh-Page3 {
    if ($script:Mode -eq 'Uninstall') {
        $nodeStatus.Text = 'Node.js is not required for uninstall. Continue to the removal step.'
        $nodeButton.Enabled = $false
        return
    }
    $nodeButton.Enabled = $true
    $info = Get-LocalNodeInfo $script:InstallDir
    if ($info.Valid) {
        $nodeStatus.Text = "Node.js $($info.Version) is already installed in:`n$($info.Node)"
    } elseif (Test-Path -LiteralPath $info.Node) {
        $nodeStatus.Text = 'A local Node.js runtime exists, but it is older than version 24 or could not be verified. Setup will replace it.'
    } else {
        $nodeStatus.Text = 'Node.js 24+ is not installed in this installation root yet.'
    }
}

function Refresh-Page4 {
    $script:NpmInstalled = $false
    if ($script:Mode -eq 'Uninstall') {
        $p4Title.Text = 'Remove installation'
        $p4Desc.Text = "Setup will remove the selected installation folder:`n`n    $($script:InstallDir)`n`nClose any running Fantasy Map Generator development server first."
        $npmButton.Text = 'Uninstall Now'
        $npmStatus.Text = 'Not started.'
    } else {
        $p4Title.Text = 'Install dependencies'
        $p4Desc.Text = "Setup will open a terminal and run:`n`n    npm install`n`nThe development server is started later with the Run button so the installer can finish normally."
        $npmButton.Text = 'Open Terminal and Install'
        $npmStatus.Text = 'Not started.'
    }
}

function Show-Page([int]$Index) {
    $script:currentPage = $Index
    for ($i=0; $i -lt $panels.Count; $i++) { $panels[$i].Visible = ($i -eq $Index) }
    $stepLabel.Text = "Step $($Index + 1) of 5"
    $backButton.Visible = $Index -gt 0 -and $Index -lt 4
    $nextButton.Visible = $Index -lt 4
    $cancelButton.Visible = $Index -lt 4

    if ($Index -eq 2) { Refresh-Page3 }
    if ($Index -eq 3) { Refresh-Page4 }
    if ($Index -eq 4) {
        $backButton.Visible = $false
        $nextButton.Visible = $false
        $cancelButton.Visible = $false
        if ($script:Mode -eq 'Uninstall') {
            $runButton.Visible = $false
            $finishText.Text = if ($script:PendingDelete) {
                "Uninstall is complete except for the installer file currently in use. Click Exit to finish removing:`n`n$($script:InstallDir)"
            } else {
                "Uninstall completed successfully.`n`nRemoved: $($script:InstallDir)"
            }
        } else {
            $runButton.Visible = $true
            $finishText.Text = "Installation is ready.`n`nRun starts a terminal in $($script:InstallDir) and executes npm run dev. A reusable Run Azgaar's Fantasy Map Generator.bat launcher was also created in the installation folder."
        }
    }
}

$browseButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Choose the installation directory'
    $dlg.SelectedPath = $pathBox.Text
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $pathBox.Text = $dlg.SelectedPath }
})

$nodeButton.Add_Click({
    if ($script:Mode -eq 'Uninstall') { return }
    try {
        $nodeButton.Enabled = $false
        $nodeStatus.Text = 'Downloading and verifying Node.js 24.x...'
        [System.Windows.Forms.Application]::DoEvents()
        $info = Ensure-Node24 $script:InstallDir
        $nodeStatus.Text = "Node.js $($info.Version) is ready in:`n$($info.Node)"
    } catch {
        Show-Error $_.Exception.Message
        Refresh-Page3
    } finally {
        $nodeButton.Enabled = $true
    }
})

$npmButton.Add_Click({
    try {
        $npmButton.Enabled = $false
        if ($script:Mode -eq 'Uninstall') {
            $npmStatus.Text = 'Removing installation...'
            [System.Windows.Forms.Application]::DoEvents()
            Invoke-Uninstall $script:InstallDir
            $npmStatus.Text = 'Uninstall step completed.'
            $script:NpmInstalled = $true
        } else {
            $info = Ensure-Node24 $script:InstallDir
            $npmStatus.Text = "Opening terminal for npm install using Node.js $($info.Version)..."
            [System.Windows.Forms.Application]::DoEvents()
            Run-NpmInstall $script:InstallDir
            Write-RunLauncher $script:InstallDir | Out-Null
            Write-InstallManifest $script:InstallDir
            $npmStatus.Text = 'npm install completed successfully.'
            $script:NpmInstalled = $true
        }
    } catch {
        $npmStatus.Text = 'Action failed.'
        Show-Error $_.Exception.Message
    } finally {
        $npmButton.Enabled = $true
    }
})

$backButton.Add_Click({
    if ($script:currentPage -gt 0) { Show-Page ($script:currentPage - 1) }
})

$nextButton.Add_Click({
    try {
        switch ($script:currentPage) {
            0 {
                if ($repairRadio.Checked) { $script:Mode = 'Repair' }
                elseif ($uninstallRadio.Checked) { $script:Mode = 'Uninstall' }
                else { $script:Mode = 'Install' }
                Show-Page 1
            }
            1 {
                $script:InstallDir = Normalize-Path $pathBox.Text
                $pathBox.Text = $script:InstallDir
                if ($script:Mode -ne 'Uninstall') { Assert-WritableInstallPath $script:InstallDir }

                if ($script:Mode -eq 'Install') {
                    Ensure-ApplicationFiles $script:InstallDir $false
                } elseif ($script:Mode -eq 'Repair') {
                    Prepare-Repair $script:InstallDir
                }
                Show-Page 2
            }
            2 {
                if ($script:Mode -ne 'Uninstall') {
                    $info = Ensure-Node24 $script:InstallDir
                    $nodeStatus.Text = "Node.js $($info.Version) is ready in:`n$($info.Node)"
                }
                Show-Page 3
            }
            3 {
                if (-not $script:NpmInstalled) {
                    if ($script:Mode -eq 'Uninstall') {
                        Invoke-Uninstall $script:InstallDir
                        $script:NpmInstalled = $true
                    } else {
                        Run-NpmInstall $script:InstallDir
                        Write-RunLauncher $script:InstallDir | Out-Null
                        Write-InstallManifest $script:InstallDir
                        $script:NpmInstalled = $true
                    }
                }
                Show-Page 4
            }
        }
    } catch {
        Show-Error $_.Exception.Message
    }
})

$cancelButton.Add_Click({ $form.Close() })

$runButton.Add_Click({
    try {
        Start-DevServer $script:InstallDir
        $form.Close()
    } catch {
        Show-Error $_.Exception.Message
    }
})

$exitButton.Add_Click({
    Schedule-PendingDelete
    $form.Close()
})

$form.Add_FormClosed({
    if ($script:RepairBackup) { Remove-Item -LiteralPath $script:RepairBackup -Recurse -Force -ErrorAction SilentlyContinue }
})

Show-Page 0
[void]$form.ShowDialog()

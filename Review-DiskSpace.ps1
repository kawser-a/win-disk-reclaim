<#
.SYNOPSIS
    Interactive disk cleanup for Windows.
    Lists the biggest files and folders in a location, largest first, and lets you
    review each one: keep it, open it in Explorer, drill into it, or send it to the
    Recycle Bin. Nothing is ever deleted without you choosing it.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1
    powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1 -Path C:\ -Top 30 -MinSizeMB 100
    powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1 -Path $env:LOCALAPPDATA -Top 25 -MinSizeMB 200

.NOTES
    - Deleted items go to the Recycle Bin, so they still use space until you empty it.
      Empty the Recycle Bin once you're sure.
    - Items too large for the Recycle Bin make Windows ask whether to delete permanently.
    - Core system locations (Windows, Program Files, ProgramData, page/hibernation files,
      your profile root, AppData roots) are protected and can only be browsed, not deleted.
    - Every deletion is recorded in cleanup-log.txt next to this script.
#>
param(
    [string]$Path = $env:USERPROFILE,
    [int]$Top = 20,
    [int]$MinSizeMB = 50
)

Add-Type -AssemblyName Microsoft.VisualBasic

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $HOME }
$LogFile   = Join-Path $ScriptDir 'cleanup-log.txt'
$script:Freed = [int64]0

# Never deletable, and nothing inside them is deletable either.
$ProtectedTrees = @(
    $env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData,
    'C:\System Volume Information', 'C:\$Recycle.Bin', 'C:\Recovery', 'C:\Boot'
) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\').ToLower() }

# These exact paths can't be deleted, but you can browse inside them.
$ProtectedExact = @(
    'C:\', 'C:\Users', $env:USERPROFILE, "$env:USERPROFILE\AppData",
    $env:LOCALAPPDATA, $env:APPDATA, "$env:USERPROFILE\AppData\LocalLow",
    'C:\pagefile.sys', 'C:\hiberfil.sys', 'C:\swapfile.sys'
) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\').ToLower() }

function Test-Protected([string]$p) {
    $p = $p.TrimEnd('\').ToLower()
    if ($ProtectedExact -contains $p) { return $true }
    foreach ($t in $ProtectedTrees) {
        if ($p -eq $t -or $p.StartsWith("$t\")) { return $true }
    }
    return $false
}

function Format-Size([int64]$bytes) {
    if ($bytes -ge 1GB) { return '{0:N2} GB' -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return '{0:N1} MB' -f ($bytes / 1MB) }
    return '{0:N0} KB' -f ($bytes / 1KB)
}

function Get-ItemSize($item) {
    if (-not $item.PSIsContainer) { return [int64]$item.Length }
    $sum = (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if ($sum) { return [int64]$sum } else { return [int64]0 }
}

function Remove-ToRecycleBin($item) {
    $fs = [Microsoft.VisualBasic.FileIO.FileSystem]
    $ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
    $rb = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
    if ($item.PSIsContainer) { $fs::DeleteDirectory($item.FullName, $ui, $rb) }
    else                     { $fs::DeleteFile($item.FullName, $ui, $rb) }
}

function Review-Folder([string]$folder) {
    Write-Host "`nScanning $folder ..." -ForegroundColor Cyan

    $children = @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })

    $n = 0
    $entries = foreach ($c in $children) {
        $n++
        Write-Progress -Activity "Measuring $folder" -Status $c.Name -PercentComplete (100 * $n / [Math]::Max($children.Count, 1))
        [pscustomobject]@{ Item = $c; Size = (Get-ItemSize $c) }
    }
    Write-Progress -Activity "Measuring $folder" -Completed

    $entries = @($entries | Where-Object { $_.Size -ge ($MinSizeMB * 1MB) } |
                 Sort-Object Size -Descending | Select-Object -First $Top)

    if ($entries.Count -eq 0) {
        Write-Host "Nothing larger than $MinSizeMB MB here." -ForegroundColor DarkGray
        return
    }

    Write-Host "`nLargest items in ${folder}:" -ForegroundColor Cyan
    $i = 0
    foreach ($e in $entries) {
        $i++
        $kind = if ($e.Item.PSIsContainer) { 'DIR ' } else { 'FILE' }
        Write-Host ('{0,3}. {1}  {2,10}  {3}' -f $i, $kind, (Format-Size $e.Size), $e.Item.Name)
    }

    $i = 0
    foreach ($e in $entries) {
        $i++
        $it = $e.Item
        $isProtected = Test-Protected $it.FullName
        Write-Host ''
        Write-Host ("[{0}/{1}] {2}" -f $i, $entries.Count, $it.FullName) -ForegroundColor Yellow
        Write-Host ("        Size: {0}   Last modified: {1:yyyy-MM-dd}   Type: {2}" -f (Format-Size $e.Size), $it.LastWriteTime, $(if ($it.PSIsContainer) { 'Folder' } else { 'File' }))
        if ($isProtected) { Write-Host '        (protected system location: browse only)' -ForegroundColor DarkYellow }

        $done = $false
        while (-not $done) {
            $prompt = '[K]eep  [D]elete to Recycle Bin  [O]pen in Explorer'
            if ($it.PSIsContainer) { $prompt += '  [E]nter folder' }
            $prompt += '  [Q]uit'
            $choice = (Read-Host $prompt).Trim().ToUpper()

            switch ($choice) {
                'K' { $done = $true }
                ''  { $done = $true }
                'O' {
                    if ($it.PSIsContainer) { Start-Process explorer.exe -ArgumentList "`"$($it.FullName)`"" }
                    else { Start-Process explorer.exe -ArgumentList "/select,`"$($it.FullName)`"" }
                }
                'E' {
                    if ($it.PSIsContainer) {
                        $r = Review-Folder $it.FullName
                        if ($r -eq 'quit') { return 'quit' }
                        Write-Host "`nBack in $folder" -ForegroundColor Cyan
                        Write-Host ("[{0}/{1}] {2}" -f $i, $entries.Count, $it.FullName) -ForegroundColor Yellow
                    } else {
                        Write-Host 'That is a file, not a folder.'
                    }
                }
                'D' {
                    if ($isProtected) {
                        Write-Host 'Refusing: this is a protected system location.' -ForegroundColor Red
                    } else {
                        $confirm = Read-Host "Send '$($it.Name)' ($(Format-Size $e.Size)) to the Recycle Bin? (y/n)"
                        if ($confirm -match '^(y|yes)$') {
                            try {
                                Remove-ToRecycleBin $it
                                $script:Freed += $e.Size
                                Add-Content -LiteralPath $LogFile -Value ("{0:yyyy-MM-dd HH:mm}`t{1}`t{2}" -f (Get-Date), (Format-Size $e.Size), $it.FullName)
                                Write-Host 'Moved to Recycle Bin.' -ForegroundColor Green
                                $done = $true
                            } catch {
                                Write-Host "Could not delete: $($_.Exception.Message)" -ForegroundColor Red
                                Write-Host 'It may be in use. Close the app using it, or skip it.' -ForegroundColor DarkGray
                            }
                        }
                    }
                }
                'Q' { return 'quit' }
                default { Write-Host 'Please type K, D, O, E or Q.' }
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $Path)) { Write-Host "Path not found: $Path" -ForegroundColor Red; exit 1 }

$drive = Get-PSDrive -Name ($Path.Substring(0, 1))
Write-Host ("Free space on {0}: before: {1}" -f $drive.Name, (Format-Size ([int64]$drive.Free))) -ForegroundColor Cyan

Review-Folder (Resolve-Path -LiteralPath $Path).Path | Out-Null

Write-Host ''
Write-Host ("Sent {0} to the Recycle Bin this session." -f (Format-Size $script:Freed)) -ForegroundColor Green
Write-Host 'Empty the Recycle Bin to actually free that space.' -ForegroundColor Green
if ($script:Freed -gt 0) { Write-Host "Log: $LogFile" -ForegroundColor DarkGray }

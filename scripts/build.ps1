param([string]$TD = 'C:/Anlogic/TD_Release_2026.1_SP2.200.067/bin/td_commands_prompt.exe')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$env:BRAILLE_PROJECT_ROOT = $root.Replace('\','/')
$started = Get-Date
New-Item -ItemType Directory -Force "$root/reports" | Out-Null
$result = & $TD "$PSScriptRoot/build.tcl".Replace('\','/')
$exitCode = $LASTEXITCODE
$result | Tee-Object "$root/reports/build.log"
if ($exitCode -ne 0 -or $result -match 'ERROR:') { throw 'TD build failed; inspect reports/build.log' }
$physical = "$root/build/braille_modes_demo_Runs/phy_1"
$bit = Get-Item "$physical/braille_modes_demo.bit"
if ($bit.LastWriteTime -lt $started) { throw 'No fresh bitstream generated' }
$timing = Get-Content "$physical/braille_modes_demo_pr.timing" -Raw
foreach ($name in @('SWNS','HWNS')) {
    $match = [regex]::Match($timing, "$name`: (-?[0-9.]+)ns")
    if (!$match.Success -or [double]::Parse($match.Groups[1].Value,[cultureinfo]::InvariantCulture) -lt 0) {
        throw "Timing not closed: $name"
    }
}
Copy-Item "$physical/braille_modes_demo_pr.timing" "$root/reports/timing.txt" -Force
Copy-Item "$physical/braille_modes_demo_phy.area" "$root/reports/resource.txt" -Force
Write-Output "PASS build: $($bit.FullName)"

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
$importOutput = & $godotPath --headless --editor --path $projectRoot --import --quit 2>&1
$importExit = $LASTEXITCODE
if ($importExit -ne 0 -or ($importOutput -match 'SCRIPT ERROR:|^ERROR:')) {
    $importOutput | Write-Output
    throw 'Content import failed'
}
$validationOutput = & $godotPath --headless --path $projectRoot --quit-after 120 (Join-Path $projectRoot 'debug/ValidateContent.tscn') 2>&1
$validationExit = $LASTEXITCODE
$validationOutput | Write-Output
if ($validationExit -ne 0 -or ($validationOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($validationOutput -match 'CONTENT VALIDATION valid=true')) { throw 'Content validation failed' }

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
$importOutput = & $godotPath --headless --editor --path $projectRoot --import --quit 2>&1
$importExit = $LASTEXITCODE
$importOutput | Write-Output
if ($importExit -ne 0 -or ($importOutput -match 'SCRIPT ERROR:|^ERROR:')) { throw 'Godot import failed' }
$invalidContentOutput = & $godotPath --headless --path $projectRoot --quit-after 120 (Join-Path $projectRoot 'tests/content_validation_runtime.tscn') -- --validator-exit-check 2>&1
$invalidContentExit = $LASTEXITCODE
$invalidContentOutput | Write-Output
if ($invalidContentExit -ne 1 -or ($invalidContentOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($invalidContentOutput -match 'CONTENT VALIDATION valid=false')) { throw 'Invalid content did not fail validation cleanly' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'build/content-validation.json') -Destination (Join-Path $projectRoot 'build/content-validation-invalid.json')
$validContentOutput = & $godotPath --headless --path $projectRoot --quit-after 120 (Join-Path $projectRoot 'debug/ValidateContent.tscn') 2>&1
$validContentExit = $LASTEXITCODE
$validContentOutput | Write-Output
if ($validContentExit -ne 0 -or ($validContentOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($validContentOutput -match 'CONTENT VALIDATION valid=true')) { throw 'Authored content validation failed' }
$testOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 1800 (Join-Path $projectRoot 'tests/test_runner.tscn') 2>&1
$testExit = $LASTEXITCODE
$testOutput | Write-Output
if ($testExit -ne 0 -or ($testOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($testOutput -match 'RESULT: .*; 0 failed')) { throw 'Tests failed' }
$demoOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 300 (Join-Path $projectRoot 'tests/demo_completion_runtime.tscn') 2>&1
$demoExit = $LASTEXITCODE
$demoOutput | Write-Output
if ($demoExit -ne 0 -or ($demoOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($demoOutput -match 'DEMO COMPLETION RUNTIME .*verified=true')) { throw 'Demo completion checks failed' }
$footstepOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 600 (Join-Path $projectRoot 'tests/footstep_runtime.tscn') 2>&1
$footstepExit = $LASTEXITCODE
$footstepOutput | Write-Output
if ($footstepExit -ne 0 -or ($footstepOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($footstepOutput -match 'FOOTSTEPS RUNTIME .*verified=true')) { throw 'Footstep movement/audio routing checks failed' }
$combatAudioOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 1600 (Join-Path $projectRoot 'tests/combat_audio_runtime.tscn') 2>&1
$combatAudioExit = $LASTEXITCODE
$combatAudioOutput | Write-Output
if ($combatAudioExit -ne 0 -or ($combatAudioOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($combatAudioOutput -match 'COMBAT AUDIO RUNTIME .*verified=true')) { throw 'Combat audio routing checks failed' }
$readabilityOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 300 (Join-Path $projectRoot 'tests/combat_readability_runtime.tscn') 2>&1
$readabilityExit = $LASTEXITCODE
$readabilityOutput | Write-Output
if ($readabilityExit -ne 0 -or ($readabilityOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($readabilityOutput -match 'COMBAT READABILITY RUNTIME verified=true')) { throw 'Combat readability lifecycle checks failed' }
$avoidanceOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 1200 (Join-Path $projectRoot 'tests/hazard_avoidance_runtime.tscn') 2>&1
$avoidanceExit = $LASTEXITCODE
$avoidanceOutput | Write-Output
if ($avoidanceExit -ne 0 -or ($avoidanceOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($avoidanceOutput -match 'HAZARD AVOIDANCE RUNTIME verified=true')) { throw 'Hazard avoidance checks failed' }
$journeyOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 21800 (Join-Path $projectRoot 'tests/journey_runtime.tscn') 2>&1
$journeyExit = $LASTEXITCODE
$journeyOutput | Write-Output
if ($journeyExit -ne 0 -or ($journeyOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($journeyOutput -match 'JOURNEY RUNTIME .*verified=true')) { throw 'First journey runtime failed' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'build/journey-runtime.json') -Destination (Join-Path $projectRoot 'build/journey-headless.json')
$tooltipOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 750 (Join-Path $projectRoot 'tests/render_tooltips.tscn') 2>&1
$tooltipExit = $LASTEXITCODE
$tooltipOutput | Write-Output
if ($tooltipExit -ne 0 -or ($tooltipOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($tooltipOutput -match 'CONTEXT TOOLTIP RENDER COMPLETE verified=true')) { throw 'Contextual tooltip input checks failed' }
$statusKeyboardOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 1800 (Join-Path $projectRoot 'tests/status_keyboard_runtime.tscn') 2>&1
$statusKeyboardExit = $LASTEXITCODE
$statusKeyboardOutput | Write-Output
if ($statusKeyboardExit -ne 0 -or ($statusKeyboardOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($statusKeyboardOutput -match 'STATUS KEYBOARD RUNTIME checks=28 verified=true')) { throw 'Status keyboard inspection failed' }
$navigationOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 2100 (Join-Path $projectRoot 'tests/navigation_runtime.tscn') 2>&1
$navigationExit = $LASTEXITCODE
$navigationOutput | Write-Output
if ($navigationExit -ne 0 -or ($navigationOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($navigationOutput -match 'NAVIGATION RUNTIME .*verified=true')) { throw 'Navigation runtime checks failed' }
$layoutOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 4300 (Join-Path $projectRoot 'tests/layout_runtime.tscn') 2>&1
$layoutExit = $LASTEXITCODE
$layoutOutput | Write-Output
if ($layoutExit -ne 0 -or ($layoutOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($layoutOutput -match 'LAYOUT RUNTIME .*verified=true')) { throw 'Authored layout traversal failed' }
$collapseOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 1100 (Join-Path $projectRoot 'tests/companion_defeat_motion.tscn') -- --all-companions 2>&1
$collapseExit = $LASTEXITCODE
$collapseOutput | Write-Output
if ($collapseExit -ne 0 -or ($collapseOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($collapseOutput -match 'COMPANION DEFEAT .*verified=true')) { throw 'Companion collapse runtime failed' }
foreach ($corpseKind in @('boss','wild')) {
    $corpseOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 400 (Join-Path $projectRoot 'tests/corpse_pause_runtime.tscn') -- "--corpse-kind=$corpseKind" 2>&1
    $corpseExit = $LASTEXITCODE
    $corpseOutput | Write-Output
    if ($corpseExit -ne 0 -or ($corpseOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($corpseOutput -match 'CORPSE PAUSE .*verified=true')) { throw "Corpse pause runtime failed: $corpseKind" }
}
foreach ($guardianMode in @('directions','profile')) {
    $guardianArgs = @()
    if ($guardianMode -eq 'profile') { $guardianArgs = @('--','--profile') }
    $guardianOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 650 (Join-Path $projectRoot 'tests/guardian_directions_motion.tscn') @guardianArgs 2>&1
    $guardianExit = $LASTEXITCODE
    $guardianOutput | Write-Output
    if ($guardianExit -ne 0 -or ($guardianOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($guardianOutput -match 'GUARDIAN DIRECTIONS .*verified=true')) { throw "Guardian motion runtime failed: $guardianMode" }
}
$stressOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 3600 (Join-Path $projectRoot 'tests/stress.tscn') -- --stress-seconds=1 --stress-output=duration-headless 2>&1
$stressExit = $LASTEXITCODE
$stressOutput | Write-Output
if ($stressExit -ne 0 -or ($stressOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($stressOutput -match 'DURATION STRESS COMPLETE fixture_valid=true')) { throw 'Duration stress fixture failed' }
foreach ($exitMode in @('menu','window')) {
    $exitOutput = & $godotPath --headless --path $projectRoot --fixed-fps 60 --quit-after 180 (Join-Path $projectRoot 'tests/exit_runtime.tscn') -- "--exit-mode=$exitMode" 2>&1
    $exitCode = $LASTEXITCODE
    $exitOutput | Write-Output
    if ($exitCode -ne 0 -or ($exitOutput -match 'SCRIPT ERROR:|^ERROR:') -or -not ($exitOutput -match 'EXIT RUNTIME failure_preserves_game=true') -or -not ($exitOutput -match 'EXIT RUNTIME successful_retry=true')) { throw "Save-and-quit runtime failed: $exitMode" }
}

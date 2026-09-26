$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64.exe'
$buildId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)
$packageName = 'Emberwild-Windows-x86_64'
$relativeRoot = "build/releases/$buildId"
$releaseRoot = Join-Path $projectRoot $relativeRoot
$payload = Join-Path $releaseRoot $packageName
$qa = Join-Path $releaseRoot 'verification'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempParent "Emberwild-package-$buildId"))
if (Test-Path -LiteralPath $testRoot) { throw 'Package verification directory already exists' }
New-Item -ItemType Directory -Path $payload, $qa, $testRoot | Out-Null

function Run-CheckedProcess([string]$file, [string]$directory, [string[]]$arguments, [string]$label) {
    # Arguments are internal ASCII relative paths/tokens; WorkingDirectory and
    # executable paths are passed separately to preserve spaces and Cyrillic.
    $stdout = Join-Path $qa "$label.stdout.log"
    $stderr = Join-Path $qa "$label.stderr.log"
    $process = Start-Process -FilePath $file -WorkingDirectory $directory -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "$label exceeded its 60-second deadline; verification retained at $qa"
    }
    $exitCode = $process.ExitCode
    $process.Dispose()
    $output = [IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr)
    if ($exitCode -ne 0 -or $output -match 'SCRIPT ERROR:|(?m)^ERROR:') {
        throw "$label failed (exit $exitCode). See $stdout and $stderr"
    }
    return $output
}

Write-Output 'PACKAGE: running source tests'
& (Join-Path $PSScriptRoot 'test.ps1') *> (Join-Path $qa 'tests.log')
$tests = [IO.File]::ReadAllText((Join-Path $qa 'tests.log'))
$testResult = [regex]::Match($tests, 'RESULT: (\d+) passed; 0 failed')
if (-not $testResult.Success) { throw 'Source test completion marker is missing' }

Write-Output 'PACKAGE: exporting Windows release template'
$exportOutput = Run-CheckedProcess $engine $projectRoot @('--headless', '--editor', '--export-release', 'Windows', "$relativeRoot/$packageName/Emberwild.exe") 'export'
foreach ($file in @('Emberwild.exe', 'Emberwild.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $payload $file))) { throw "Missing exported artifact: $file" }
}
$noticeOutput = Run-CheckedProcess $engine $projectRoot @('--headless', '--script', 'tools/export_notices.gd', '--', "$relativeRoot/$packageName/Godot-NOTICES.txt") 'notices'
if ($noticeOutput -notmatch 'ENGINE NOTICES exported=true') { throw 'Engine notices were not exported' }
$version = (Run-CheckedProcess $engine $projectRoot @('--version') 'version').Trim()
$readme = @'
EMBERWILD — ХРАНИТЕЛИ РОЩИ

Запуск
Распакуйте архив целиком в отдельную папку и запустите Emberwild.exe.
Emberwild.pck должен оставаться рядом с EXE. Установка Godot не требуется.
Демоверсия: Тихая гавань, Янтарная роща и босс-хранитель.

Как пройти демо
Поймайте дикое существо, победите элитного стража и освободите рощу.
После выполнения трёх задач откройте «Итоги демо» в меню паузы
или взаимодействуйте с лагерем. Можно продолжить исследование и собрать добычу.
В рюкзаке можно надеть стартовые предметы. Источник в гавани восстанавливает
героиню и команду; в лагере доступны припасы и хранилище.

Стандартное управление
WASD / стрелки — движение; левая кнопка мыши — атака.
Правая кнопка мыши — выбрать цель; Space — рывок; Q / E — способности спутников.
F — захват существа; R — взаимодействие; C — зелье.
I — рюкзак; Tab — команда; Esc — меню и пауза.
Клавиши можно изменить в настройках. В меню Tab / Shift+Tab перемещают фокус.
Русский и английский выбираются в настройках языка.

Сохранение
Используйте «Выход с сохранением» или закройте окно игры.
Сохранения и настройки находятся в профиле Windows, отдельно от папки игры:
%APPDATA%\Godot\app_userdata\Emberwild — Хранители рощи
Удаление или перемещение папки игры не удаляет эти сохранения.

Windows x86_64. Игра использует OpenGL Compatibility renderer.
Godot и сторонние компоненты: Godot-NOTICES.txt.
Контрольные суммы файлов: manifest.json.

Ограничения демо
Это небольшой законченный маршрут, а не полная игра по исходному ТЗ.
Дальнейшие биомы, процедурный мир и поздняя игра ещё не реализованы.
Графика, баланс и синтезированный звук могут дорабатываться после отзывов.
Стабильные 60 FPS в экстремальном бою не гарантированы: в проверке
с 30 врагами и 120 предметами получено около 56 FPS на текущем компьютере.
Совместимость с другими видеокартами и драйверами пока не проверена.

ENGLISH
Extract the entire archive and run Emberwild.exe. Keep Emberwild.pck next to it.
Godot installation is not required. This demo includes the haven, grove and guardian.
Capture a creature, defeat the elite and free the grove to unlock Demo results
in the pause menu and at camp. You may continue exploring after completion.
Select English in Settings. Saves/settings live in your Windows user profile.
Use Save and quit, or close the game window, to save your journey.
Future biomes, a procedural world and endgame are not included. Art, balance
and synthesized sound may receive further work. Stress scenarios are not yet
stable at 60 FPS; GPU/driver compatibility beyond this machine is unverified.
'@
[IO.File]::WriteAllText((Join-Path $payload 'README.txt'), $readme, [Text.UTF8Encoding]::new($true))
$files = @(Get-ChildItem -LiteralPath $payload -File | Sort-Object Name | ForEach-Object {
    @{ name = $_.Name; bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$manifest = @{ format = 1; build = $buildId; state = 'demo'; platform = 'windows-x86_64'; runtime = 'release'; godot = $version; sourceChecksPassed = [int]$testResult.Groups[1].Value; files = $files }
[IO.File]::WriteAllText((Join-Path $payload 'manifest.json'), ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
$zip = Join-Path $releaseRoot "$packageName-$buildId.zip"
Compress-Archive -LiteralPath $payload -DestinationPath $zip -CompressionLevel Optimal
Expand-Archive -LiteralPath $zip -DestinationPath $testRoot
$extracted = Join-Path $testRoot $packageName
$extractedManifest = Get-Content -LiteralPath (Join-Path $extracted 'manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in $extractedManifest.files) {
    if ([IO.Path]::GetFileName($entry.name) -ne $entry.name) { throw 'Unexpected manifest path' }
    $file = Join-Path $extracted $entry.name
    if ((Get-Item -LiteralPath $file).Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "Extracted file verification failed: $($entry.name)" }
}
if (Test-Path -LiteralPath (Join-Path $extracted 'project.godot')) { throw 'Verification must not use a source project' }

Write-Output 'PACKAGE: checking extracted copy outside the source project'
$executable = Join-Path $extracted 'Emberwild.exe'
$headlessOutput = Run-CheckedProcess $executable $extracted @('--headless', '--quit-after', '180', '--', '--autostart', '--grove') 'headless'
foreach ($scene in @('title', 'grove')) {
    $arguments = @('--quit-after', '180', '--', "--screenshot=../$scene.png")
    if ($scene -eq 'grove') { $arguments += @('--autostart', '--grove') }
    $output = Run-CheckedProcess $executable $extracted $arguments "native-$scene"
    if ($output -notmatch 'SCREENSHOT .*result=0 debug=false' -or -not (Test-Path -LiteralPath (Join-Path $testRoot "$scene.png"))) { throw "Native release screenshot verification failed: $scene" }
    Copy-Item -LiteralPath (Join-Path $testRoot "$scene.png") -Destination (Join-Path $qa "$scene.png")
}
$archiveHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$zip.sha256", "$archiveHash *$([IO.Path]::GetFileName($zip))`n", [Text.UTF8Encoding]::new($false))
$verification = @{ verified = $true; build = $buildId; archive = $zip; sha256 = $archiveHash; sourceChecksPassed = $manifest.sourceChecksPassed; extractedOutsideProject = $true; nativeReleaseScenes = @('title', 'grove'); headlessStartup = $true }
[IO.File]::WriteAllText((Join-Path $qa 'result.json'), ($verification | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
# Delete only the new, uniquely named temporary extraction created by this run.
$resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
if ([IO.Directory]::GetParent($resolvedTestRoot).FullName -ne $tempParent -or [IO.Path]::GetFileName($resolvedTestRoot) -ne "Emberwild-package-$buildId") { throw 'Temporary extraction cleanup path check failed' }
Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
Write-Output "PACKAGE COMPLETE: $zip"
Write-Output "VERIFICATION: $(Join-Path $qa 'result.json')"

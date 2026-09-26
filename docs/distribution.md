# Windows portable build

Demo checkpoint delivered before the user-requested pause: `20260926-134409-20ea02`.
All 1008 core source checks, the 18-check demo completion fixture and all runtime
subprocesses pass. The 77,818,509-byte archive is verified after extraction outside
the source tree; native title/grove startup reports `debug=false`, stderr logs are
empty and both images were inspected. SHA-256:
`539959bacc61682b5a508a22a642fe159de023e5f05136aa278a2f6b38c763e2`.
The manifest identifies a demo, and the included RU/EN README explains objectives,
completion, controls, saves and known limitations. `Демо.cmd` launches this exact
local payload. Full-project work remains open; handoff: `resume-after-demo.md`.

Run from the repository:

```powershell
powershell -ExecutionPolicy Bypass -File tools/package-windows.ps1
```

Requirements: the bundled Godot 4.7.2 executable in `tools/godot/` and matching Windows x86_64 export templates in `%APPDATA%/Godot/export_templates/4.7.2.stable/`. The build script does not download or install dependencies.

Each invocation creates a separate `build/releases/<timestamp-random>/` directory. The default pipeline runs the full source test suite, exports the Windows release EXE and PCK, obtains Godot/third-party copyright and license texts from the bundled engine, and writes Russian/English launch instructions. `manifest.json` records engine version, build identifier, source check count and SHA-256/size of payload files. The manifest does not hash itself. The ZIP has a separate SHA-256 file.

The archive contains one `Emberwild-Windows-x86_64` folder. Extract the entire folder and run `Emberwild.exe`; keep `Emberwild.pck` beside it. No Godot installation is needed on the receiving computer. Saves and settings use the same Windows profile directory as the source launch: `%APPDATA%/Godot/app_userdata/Emberwild — Хранители рощи`. Moving the application folder does not move or remove them. Source and portable copies on the same account share these files.

Verification unpacks the actual ZIP into a unique temporary directory outside the source tree, checks payload hashes and launches the extracted executable with its own working directory and without project/source overrides. It checks headless grove startup and native screenshots of both title screen and grove; screenshot logs must identify a release runtime (`debug=false`). Screenshots and process logs stay in `verification/`, outside the distributed archive. A successful run writes `verification/result.json` and removes only its own temporary extraction after checking the exact absolute cleanup path. Failures retain evidence and do not produce a success report.

The first failed attempt reached export but failed to compile the notices helper; its logs are retained under `build/releases/20260926-120441-00c259/verification/`. The helper now has an explicit String type and passes standalone execution.

Verified build: `20260926-120957-afb03f`. All 938 source checks and the subprocess suite passed. The 77,714,201-byte ZIP contains the EXE, PCK, notices, README and manifest. SHA-256: `fb9e6904a8fecacf6b778b476e4de872be7575f2652e8fe25727f569d1fbeac4`. Both native screenshots were visually inspected; the title log identifies `area.haven`, the gameplay log `area.grove`, and both report `debug=false`. Evidence: `build/releases/20260926-120957-afb03f/verification/`.

Updated build with synchronized trainer footsteps: `20260926-121929-2b1510`. All 957 source checks and the subprocess suite pass, including the 24-check footstep input fixture. Native audio was separately exercised in the 26-check recording described in `docs/audio.md`. The new 77,720,345-byte ZIP passes extraction/hash checks and native release title/grove startup; the grove screenshot was inspected. SHA-256: `e700c7952e4857a898ee7f43bfc987f225bf863628aa9d38c2d38371c6fd01b1`. Its own `verification/result.json` and logs are stored alongside it.

These are development builds of the first playable area. The smoke checks verify packaging and startup on this machine; they do not certify another computer's GPU/driver compatibility, stable frame rate, long campaign saves or final gameplay/art/audio acceptance. F3 developer menus are unavailable in a release runtime. The package is not a signed installer or an update system.

HUD-safe ground-label build: `20260926-132620-f65616`. All 1008 source checks and runtime subprocess scenarios pass. Separate native checks cover eight dense-loot/HUD states and 17 ground-tooltip interactions. The 77,816,362-byte ZIP passes extracted-copy hashes and headless/native title/grove startup outside the repository; native stderr logs are empty and the grove image was inspected. SHA-256: `04ed162abcec3ee719ff612a076c1b04dc5956523acfc2c691cae32e21eb5a6d`. Its `verification/result.json` records the successful build. The failed previous attempt `20260926-132505-bba8e0` is not a deliverable; two headless ownership fixtures required the same pre-draw geometry-cache initialization as production rendering.

Updated build with six combat audio profiles: `20260926-123100-d354ec`. The 988-check source suite, 79-check headless combat audio fixture and all other subprocess scenarios pass. Separate native combat recording passes 95 checks. The 77,813,339-byte ZIP includes all 36 imported combat samples and nested profile Resources; extracted headless/title/grove startup passes, both screenshot logs report `debug=false`, and the grove image was inspected. SHA-256: `fff980e28017d1b50304626a9944b5d84af68e9ba44a593e53232ebef2c7968d`. Its `verification/` folder holds authoritative reports, logs and screenshots.

Updated loot-layout optimization build: `20260926-124225-4e317f`. All 992 source checks and runtime subprocess scenarios pass; the actual ZIP also passes outside-project hash/startup verification for headless grove, native title and native grove. ZIP size: 77,813,838 bytes; SHA-256: `f5488fd4e9724d817ab7a6e4d313846dda227e6af9322e39962a3b8c9bd9e9a6`. Reports/logs/screenshots remain in its `verification/` folder. Performance evidence is separate in `docs/performance.md` and does not claim stable 60 FPS.

Updated batched loot-marker build: `20260926-130352-c87fc1`. All 998 headless source checks and runtime subprocess scenarios pass. Separate native checks verify GPU readback, raster equivalence and real-world pickup/filter/reveal population. The 77,815,485-byte ZIP passes extracted-copy hashes and headless/native release startup; both native screenshot markers report `debug=false` and process stderr logs are empty. SHA-256: `2b1833c3abc459ffb9db53184b53fb5ad5daaf4d6ca142500bed2f5128dede25`. The earlier failed package `20260926-125918-b8ea0b` is not a successful deliverable; its log records the headless GPU-readback test mismatch explained in `docs/performance.md`.

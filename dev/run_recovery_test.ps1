param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$Log = 'recovery_test',
    [string]$UserArgs = '--quality=1',
    [string]$ExpectedMarker = '',
    [int]$TimeoutSeconds = 180,
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path "$PSScriptRoot/..").Path
$lockPath = Join-Path $env:TEMP 'echoes_godot.lock'
$otherTests = Get-CimInstance Win32_Process -Filter "name LIKE '%godot%'" | Where-Object { $_.CommandLine -notmatch '--editor' }
if ($otherTests) { throw 'Another Godot test is running; wait before retrying.' }
New-Item -ItemType Directory -Path $lockPath -ErrorAction Stop | Out-Null
$userDataPath = Join-Path $env:APPDATA 'Godot/app_userdata/ECHOES BENEATH'
$originalFiles = @{}
Get-ChildItem -LiteralPath $userDataPath -File | ForEach-Object {
    $originalFiles[$_.FullName] = [IO.File]::ReadAllBytes($_.FullName)
}
try {
    $headlessArg = if ($Headless) { '--headless' } else { '' }
    $logPath = Join-Path $workspace "docs/$Log.log"
    $argsText = "--path `"$workspace`" $headlessArg --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --log-file `"$logPath`" $Target -- $UserArgs"
    $testProcess = Start-Process -FilePath 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList $argsText -WindowStyle Hidden -PassThru
    if (-not $testProcess.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $testProcess.Id
        throw "Godot test exceeded $TimeoutSeconds seconds; see $logPath"
    }
    Write-Output "Godot exit=$($testProcess.ExitCode); log=$logPath"
    Get-Content -LiteralPath $logPath -Tail 12
    if ($testProcess.ExitCode -ne 0) { throw 'Godot test failed.' }
    if ($ExpectedMarker -ne '' -and -not (Select-String -LiteralPath $logPath -SimpleMatch -Pattern $ExpectedMarker -Quiet)) {
        throw "Godot exited without the required success marker: $ExpectedMarker"
    }
    if (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR:|PARSE_FAIL|FOLIAGE_WIND_FAIL|PHYSICAL CAMPAIGN BLOCKER:|ERROR:') {
        throw 'Godot logged an error despite its exit code.'
    }
} finally {
    Get-ChildItem -LiteralPath $userDataPath -File | Where-Object { -not $originalFiles.ContainsKey($_.FullName) } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName
    }
    foreach ($originalPath in $originalFiles.Keys) {
        [IO.File]::WriteAllBytes($originalPath, $originalFiles[$originalPath])
    }
    Remove-Item -LiteralPath $lockPath
}

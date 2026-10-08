# Godot MCP setup - installs Coding-Solo/godot-mcp and registers it with Claude Desktop and Cursor.
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File D:\new-dev\setup-godot-mcp.ps1
$ErrorActionPreference = "Stop"

function Need($cmd, $hint) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "Missing '$cmd'. $hint" -ForegroundColor Red; exit 1
    }
}
Need node "Install Node.js 18+ from https://nodejs.org"
Need git  "Install Git from https://git-scm.com"
Need npm  "npm comes with Node.js"

# 1. Locate Godot executable
Write-Host "Searching for Godot..." -ForegroundColor Cyan
$roots = @("C:\Program Files", "C:\Program Files (x86)", "D:\", "$env:USERPROFILE\Downloads",
           "$env:USERPROFILE\Desktop", "$env:LOCALAPPDATA", "$env:USERPROFILE\scoop\apps",
           "C:\Program Files (x86)\Steam\steamapps\common")
$godot = $null
foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    $hit = Get-ChildItem $r -Recurse -Depth 3 -Filter "Godot*.exe" -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch "console" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($hit) { $godot = $hit.FullName; break }
}
if (-not $godot) { $godot = Read-Host "Godot not found. Paste the full path to your Godot .exe" }
if (-not (Test-Path $godot)) { Write-Host "Path not valid: $godot" -ForegroundColor Red; exit 1 }
Write-Host "Using Godot: $godot" -ForegroundColor Green

# 2. Clone + build (outside the Godot project so Godot doesn't import node_modules)
$dir = Join-Path $env:USERPROFILE "godot-mcp"
if (Test-Path $dir) { git -C $dir pull } else { git clone https://github.com/Coding-Solo/godot-mcp.git $dir }
Push-Location $dir
npm install
npm run build
Pop-Location
$entry = Join-Path $dir "build\index.js"
if (-not (Test-Path $entry)) { Write-Host "Build failed: $entry missing" -ForegroundColor Red; exit 1 }

# 3. Register in client configs (merges, keeps existing servers, backs up originals)
$server = [ordered]@{ command = "node"; args = @($entry); env = [ordered]@{ GODOT_PATH = $godot; DEBUG = "true" } }

function Register($path) {
    $folder = Split-Path $path
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    $cfg = [pscustomobject]@{}
    if (Test-Path $path) {
        Copy-Item $path "$path.bak" -Force
        $raw = Get-Content $path -Raw
        if ($raw.Trim()) { $cfg = $raw | ConvertFrom-Json }
    }
    if (-not $cfg.PSObject.Properties["mcpServers"]) { $cfg | Add-Member mcpServers ([pscustomobject]@{}) }
    $cfg.mcpServers | Add-Member -Force godot ([pscustomobject]$server)
    $cfg | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
    Write-Host "Registered in $path" -ForegroundColor Green
}
Register (Join-Path $env:APPDATA "Claude\claude_desktop_config.json")
Register (Join-Path $env:USERPROFILE ".cursor\mcp.json")

Write-Host "`nDone. Fully quit and reopen Claude Desktop / Cursor, then look for the 'godot' tools." -ForegroundColor Cyan
Write-Host "Your project path to use in prompts: D:\new-dev"

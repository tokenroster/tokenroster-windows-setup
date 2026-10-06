# TokenRoster Business Workspace - Windows setup
# Automates the install steps from README.md: VS Code, Git, Node.js,
# the Claude Code extension, and cloning the business template.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -CompanyName acme -Destination D:\work

param(
    [string]$CompanyName,
    [string]$Destination
)

$ErrorActionPreference = 'Stop'
# Default to the folder this script (and setup.cmd) lives in.
if (-not $Destination) { $Destination = $PSScriptRoot }
$TemplateUrl = 'https://github.com/tokenroster/tokenroster-business-template.git'

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
$Check = [char]0x2713  # built from its code point so the file stays ASCII (PS 5.1 misreads UTF-8 without BOM)
function Write-Ok($text)   { Write-Host "    $Check $text" -ForegroundColor Green }
function Fail($text)       { Write-Host "`nERROR: $text" -ForegroundColor Red; exit 1 }

# Reload PATH from the registry so newly installed tools are found
# without restarting the terminal.
function Update-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-WithWinget($id, $command, $name, $extraArgs = @()) {
    Write-Step "Installing $name"
    if (Get-Command $command -ErrorAction SilentlyContinue) {
        Write-Ok "$name is already installed, skipping"
        return
    }
    winget install --id $id -e --source winget --silent `
        --accept-package-agreements --accept-source-agreements @extraArgs
    # -1978335189 (0x8A15002B): winget thinks it's already installed; fall through to the PATH check.
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        Fail "$name failed to install (winget exit code $LASTEXITCODE). If Windows asked for administrator permission, click Yes. On a work computer you may need IT to install it. Then run this script again."
    }
    Update-Path
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Fail "$name installed but '$command' is not on PATH. Close this window, reopen it, and run the script again. If it still fails, restart the computer."
    }
    Write-Ok "$name installed"
}

# --- Preflight ---------------------------------------------------------------
Write-Step 'Checking for winget'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail "winget is not available. Open the Microsoft Store, search 'App Installer', update it, then run this script again."
}
Write-Ok 'winget found'

# --- Step 1: VS Code ---------------------------------------------------------
# The override enables the "Open with Code" context menu and adds `code` to PATH.
Install-WithWinget 'Microsoft.VisualStudioCode' 'code' 'Visual Studio Code' @(
    '--override', '/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath'
)

# --- Step 2: Git -------------------------------------------------------------
Install-WithWinget 'Git.Git' 'git' 'Git'
Write-Ok (git --version)

# --- Step 3: Node.js ---------------------------------------------------------
Install-WithWinget 'OpenJS.NodeJS.LTS' 'node' 'Node.js LTS'
Write-Ok "node $(node --version)"

# --- Step 4: Claude Code extension -------------------------------------------
Write-Step 'Installing the Claude Code extension'
code --install-extension anthropic.claude-code --force
if ($LASTEXITCODE -ne 0) { Fail 'Could not install the Claude Code extension.' }
Write-Ok 'Claude Code extension installed'

# --- Step 6: Download the business template ----------------------------------
if (-not $CompanyName) {
    $CompanyName = Read-Host "`nYour company's name for the workspace folder (no spaces, e.g. my-company)"
}
$CompanyName = $CompanyName.Trim()
if (-not $CompanyName -or $CompanyName -match '\s') {
    Fail 'Company name must be non-empty and contain no spaces.'
}
$WorkspacePath = Join-Path $Destination $CompanyName

Write-Step "Downloading the business template to $WorkspacePath"
if (Test-Path $WorkspacePath) {
    Write-Ok 'Folder already exists, skipping download'
} else {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    git clone $TemplateUrl $WorkspacePath
    if ($LASTEXITCODE -ne 0) { Fail 'git clone failed. Check your internet connection and try again.' }
    Write-Ok 'Template downloaded'
}

foreach ($folder in 'strategy', 'marketing', 'sales') {
    if (-not (Test-Path (Join-Path $WorkspacePath $folder))) {
        Fail "Expected folder '$folder' is missing from $WorkspacePath."
    }
}
Write-Ok 'Found strategy, marketing, and sales folders'

# --- Open the workspace and print the remaining manual steps -----------------
Write-Step 'Opening the workspace in VS Code'
code $WorkspacePath

Write-Host @"

Setup complete. Finish these steps in VS Code:

  1. If asked whether you trust the authors, click "Yes, I trust the authors".
  2. Click the Claude icon, choose "Claude account (subscription)",
     and authorize in your browser.                         (README Step 5)
  3. In the Claude panel, type:  /tokenroster-company-setup  (README Step 7)

"@ -ForegroundColor Yellow

# Run a local bash script on Vanda over SSH, from Windows PowerShell.
# Avoids PowerShell quote/pipe mangling and strips CR so remote bash is happy.
#
# Usage:
#   .\remote_bash.ps1 -Id e0900742 -Script .\probe.sh
#
param(
    [Parameter(Mandatory = $true)] [string] $Id,
    [Parameter(Mandatory = $true)] [string] $Script,
    [string] $Host = "vanda.nus.edu.sg"
)

((Get-Content $Script -Raw) -replace "`r", "") |
    ssh -o BatchMode=yes -o ConnectTimeout=15 "$Id@$Host" "bash -s"

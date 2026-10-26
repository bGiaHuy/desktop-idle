param([string]$Project)
$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('Project')) {
    $Project = (Get-Location).Path
    $defaultLocations = @($env:USERPROFILE, $env:SystemRoot, "$env:SystemRoot\System32")
    if ($defaultLocations -contains $Project.TrimEnd('\')) {
        $Project = "$env:USERPROFILE\Documents"
    }
}
& "$PSScriptRoot\Start-Coding.ps1" -Project $Project

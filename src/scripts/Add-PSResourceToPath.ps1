param(
    [string[]]
    $ModulesPath = @(
        "$PSScriptRoot/../modules"
    ),

    [String[]]
    $ScriptsPath = @(
        "$PSScriptRoot/../scripts"
    )
)

function Add-ToEnvPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Value
    )

    $currentValue = (
        Get-Item `
            -Path "env:$Name"
    ).Value
    $pathSeparator = [System.IO.Path]::PathSeparator

    $currentValueItems = $currentValue -split [System.IO.Path]::PathSeparator

    $Value `
    | ForEach-Object {
        if ($_ -and $currentValueItems -inotcontains $_) {
            $currentValue += "$($pathSeparator)$($_)"
        }
    }

    Set-Item `
        -Path "env:$Name" `
        -Value $currentValue
}

Add-ToEnvPath `
    -Name "PSModulePath" `
    -Value $ModulesPath

Add-ToEnvPath `
    -Name "PATH" `
    -Value $ScriptsPath
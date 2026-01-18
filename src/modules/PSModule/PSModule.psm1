function Export-ModuleVariable {
    param (
        [String[]]
        $Name,

        [String[]]
        $Path = @(
            'Source/Variables.ps1'
        ),

        [Switch]
        $Force
    )

    $callStack = Get-PSCallStack

    if ($callStack.Count -lt 2) {
        return
    }
            
    $moduleBase = $callStack[1].ScriptName `
    | Split-Path `
        -Parent
    $moduleName = $moduleBase `
    | Split-Path `
        -Leaf

    $shouldProcess = $Force

    if (
        -not (
            Get-Variable `
                -Name $moduleName `
                -Scope 'Global' `
                -ErrorAction 'SilentlyContinue'
        )
    ) {
        $shouldProcess = $true
    }

    if (-not $shouldProcess) {
        return
    }

    $manifest = Import-PowerShellDataFile `
        -Path "$moduleBase/$moduleName.psd1" 

    $Name = $Name ? $Name : $manifest.VariablesToExport

    if (-not $Name) {
        return
    }

    $Path `
    | ForEach-Object {
        $pathItem = "$moduleBase/$_"

        if (
            Test-Path `
                -Path $pathItem
        ) {
            . $pathItem
        }
    }

    $variables = @{}

    $Name `
    | ForEach-Object {
        $variable = Get-Variable `
            -Name $_ `
            -Scope 'Script' `
            -ErrorAction 'SilentlyContinue'

        if ($variable) {
            $variables[$variable.Name] = $variable.Value
        }
    }

    Set-Variable `
        -Name $moduleName `
        -Value $variables `
        -Scope 'Global'
}
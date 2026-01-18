& "$PSScriptRoot/Add-PSResourceToPath.ps1"

Import-Module `
    -Name "Az.Naming.Config" `
    -Force

Initialize-AzResourceAbbreviation `
    -ItemAction {
        param (
            [Hashtable]
            $InputObject
        )

        Add-AzResourceCategory `
            -Category $InputObject.category `
            -ResourcePath $InputObject.resourcePath
    }

${Az.Naming.Config}.ResourceByCategory.GetEnumerator() `
| ForEach-Object {
    $_ `
    | ConvertTo-Json `
        -Depth 100
}
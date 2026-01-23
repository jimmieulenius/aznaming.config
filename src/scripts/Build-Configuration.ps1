& "$PSScriptRoot/Add-PSResourceToPath.ps1"

Import-Module `
    -Name @(
        'Az.Naming.Config'
        'Utility'
    ) `
    -Force

# @(
#     @{
#         a = 1
#         b = 2
#     },
#     @{
#         c = 3
#         d = 4
#     }
# ) `
# | ForEach-Object {
#     Add-JsonLine `
#         -Path "$PSScriptRoot/../../%Test/test.json" `
#         -Value $_
# }

Initialize-AzResourceAbbreviation `
    -ItemAction {
        param (
            [Hashtable]
            $InputObject
        )

        Add-AzResourceCategory `
            -Category $InputObject.Category `
            -Resource $InputObject.ResourcePath

        ${Az.Naming.Config}.ResourceNameRuleLookup[$InputObject.ResourcePath] = @{
            Resource = @{
                Abbreviation = $InputObject.Abbreviation
            }
            Category = $InputObject.Category
        }
    }

# Get-AzResourceCategory `
#     -Resource 'Microsoft.RecoveryServices/vaults'

Initialize-AzResourceNameRule `
    -ItemAction {
        param (
            [Hashtable]
            $InputObject
        )

        $nameRule = ${Az.Naming.Config}.ResourceNameRuleLookup[$InputObject.Key] ?? @{}

        return $InputObject `
        | Merge-Object `
            -Source $nameRule `
            -Path 'Value' `
            -PassThru
    } `
    -Force

Get-AzResourceNameRule `
    -Name 'Microsoft.EventGrid/domains'
    # -ItemAction {
    #     param (
    #         [Hashtable]
    #         $InputObject
    #     )

    #     switch ($InputObject.Key) {
    #         ('Microsoft.Storage/blob') {
    #             $InputObject.Key = 'Microsoft.Storage/storageAccounts/blobServices/containers'
    #         }
    #         ('Microsoft.Storage/queue') {
    #             $InputObject.Key = 'Microsoft.Storage/storageAccounts/queueServices/queues'
    #         }
    #         ('Microsoft.Storage/table') {
    #             $InputObject.Key = 'Microsoft.Storage/storageAccounts/tableServices/tables'
    #         }
    #     }

    #     return $InputObject
    # }

# ${Az.Naming.Config}.ResourceByCategory.GetEnumerator() `
# | ForEach-Object {
#     $_ `
#     | ConvertTo-Json `
#         -Depth 100
# }

$Global:ResourceCount = 0

Invoke-ApiSpecsAction `
    -Path 'C:\Users\admin\Source\Repos\azure-rest-api-specs' `
    -Action {
        param (
            [Parameter(Mandatory = $true)]
            [Hashtable]
            $InputObject
        )

        Write-Host "Provider: $($InputObject.Provider)"
        Write-Host "Version: $($InputObject.Version)"
        Write-Host "Path: $($InputObject.Path)"
        Write-Host ''

        $specsObject = Get-Content `
            -Path $InputObject.Path `
            -Raw `
        | ConvertFrom-Json `
            -AsHashtable

        Get-AzProviderResource `
            -Provider $InputObject.Provider `
            -SpecsObject $specsObject `
        | ForEach-Object {
            Write-Host "Resource Path: $_"

            $Global:ResourceCount++
        }
    }

Write-Host "Total Resource Paths: $($Global:ResourceCount)"
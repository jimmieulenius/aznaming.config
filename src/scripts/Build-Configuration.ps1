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

Get-AzResourceCategory `
    -Resource 'Microsoft.RecoveryServices/vaults'

Get-AzResourceNameRule `
    -Name 'Microsoft.Storage/blob'
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
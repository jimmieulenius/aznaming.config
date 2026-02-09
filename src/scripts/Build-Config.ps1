& "$PSScriptRoot/Add-PSResourceToPath.ps1"

Import-Module `
    -Name @(
        'Az.Naming.Config'
        'DataStructure'
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
    -Process {
        Add-AzResourceCategory `
            -Category $_.Category `
            -Resource $_.ResourcePath

        ${Az.Naming.Config}.ResourceNameRuleLookup[$_.ResourcePath] = @{
            Resource = @{
                Abbreviation = $_.Abbreviation
            }
            Category = $_.Category
        }
    }

# Get-AzResourceCategory `
#     -Resource 'Microsoft.RecoveryServices/vaults'

try {
    $tempFile = [System.IO.Path]::GetTempFileName()

    Initialize-AzResourceNameRule `
        -Process {
            $nameRule = ${Az.Naming.Config}.ResourceNameRuleLookup[$_.Key] ?? @{}

            $_ `
            | Merge-Dictionary `
                -Source $nameRule `
                -Path 'Value' `
            | Out-Null

            Add-JsonLine `
                -Path $tempFile `
                -Value @{
                    $_.Key = $_.Value
                }
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

    $apiSpecsPath = 'C:\Users\admin\Source\Repos\azure-rest-api-specs'

    $global:ResourceCount = 0
    $global:Endpoint = @{}

    Invoke-AzApiSpecsItem `
        -Path $apiSpecsPath `
        -ScriptBlock {
            $item = $_

            $specsObject = Get-Content `
                -Path $item.Path `
                -Raw `
            | ConvertFrom-Json `
                -AsHashtable

            # if (-not $resourceEndpoint) {
            #     return
            # }

            # $resourceEndpoint `
            # | ForEach-Object {
            #     $Global:Endpoint[$_.Key] = $_.Value `
            #     | Resolve-AzApiSpecs `
            #         -BasePath $item.Path
            # }

            Write-Host "Provider: $($item.Provider)"
            Write-Host "Version: $($item.Version)"
            Write-Host "Path: $($item.Path)"

            $currentResourcePath = @()

            Get-AzProviderResourceFromApiSpecs `
                -SpecsObject $specsObject `
                -Provider $item.Provider `
                -AsKeyValue `
            | ForEach-Object {
                Write-Host "Resource Path: $($_.Key)"

                $currentResourcePath += $_.Key

                if (
                    -not (
                        Get-AzResourceNameRule `
                            -Name $_.Key
                    )
                ) {
                    $resourcePath = $_.Key `
                    | Get-AzResourcePath `
                        -Provider $item.Provider

                    Add-JsonLine `
                        -Path $tempFile `
                        -Value @{
                            $_.Key = @{
                                Resource = @{
                                    Abbreviation = "<TODO:>"
                                    Entity = $resourcePath.Entity
                                    Provider = $item.Provider
                                }
                                Category = 'other'
                                Source = "official api specs"
                            }
                        }
                }

                $global:ResourceCount++
            }

            Get-AzResourceEndpointFromApiSpecs `
                -SpecsObject $specsObject `
                -Provider $item.Provider `
                -ResourcePath $currentResourcePath `
                -AsKeyValue `
            | ForEach-Object {
                $endpointItem = $_

                @(
                    'checkName',
                    'get'
                ) `
                | ForEach-Object {
                    $endpointValue = $endpointItem.Value.$_

                    if (-not $endpointValue) {
                        return
                    }

                    $endpointItem.Value.$_ = $endpointValue `
                    | Resolve-AzApiSpecs `
                        -BasePath $item.Path
                }

                $global:Endpoint[$_.Key] = $endpointItem.Value

                # $global:Endpoint[$_.Key] = $_.Value `
                # | Resolve-AzApiSpecs `
                #     -BasePath $item.Path
            }

            # $resourceEndpoint `
            # | ForEach-Object {
            #     Write-Host "Resource Endpoint: $($_.Key)"
            # }

            Write-Host ''
        }

    Write-Host "Total Resource Paths: $($global:ResourceCount)"
}
finally {
    if ($tempFile) {
        Remove-Item `
            -Path $tempFile `
            -Force `
            -ErrorAction 'SilentlyContinue'
    }
}
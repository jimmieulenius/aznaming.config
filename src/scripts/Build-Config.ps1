& "$PSScriptRoot/Add-PSResourceToPath.ps1"

Import-Module `
    -Name @(
        'Az.Naming.Config',
        'BloomStore',
        'DataStructure',
        'Json'
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

        Add-AzResourceCategory `
            -Category $_.Category `
            -Resource (
                $_.ResourcePath `
                | Split-AzResourcePath `
                    -Provider
            )

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
    $global:ResourceCount = 0

    # Register global Bloom Store for all config items
    $ruleStore = Register-BloomStore `
        -Name 'Rule' `
        -Key 'key' `
        -Force `
        -PassThru

    # In-memory dictionaries to track keys by type
    $policiesKeys = @()
    $endpointsKeys = @()

    Initialize-AzResourceNameRule `
        -Process {
            $nameRule = ${Az.Naming.Config}.ResourceNameRuleLookup[$_.Key] ?? @{}

            $_ `
            | Merge-Dictionary `
                -Source $nameRule `
                -Path 'Value' `
            | Out-Null

            # Store in Bloom Store
            @{
                key = $_.Key
                value = $_.Value
            } `
            | Set-BloomItem `
                -StoreName $ruleStore.Name

            $global:ResourceCount++

            # Track key for policies
            $policiesKeys += $_.Key
        } `
        -Force

    # Get-AzResourceNameRule `
    #     -Name 'Microsoft.EventGrid/domains'

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

    # $global:Endpoint = @{}
    $endpointStore = Register-BloomStore `
        -Name 'Endpoint' `
        -Key 'key' `
        -PassThru

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
                    if ($policiesKeys -contains $_.Key) {
                        Write-Verbose "Resource path already has a naming rule, skipping: $($_.Key)"

                        return
                    }

                    $resourcePath = $_.Key `
                    | Get-AzResourcePath `
                        -Provider $item.Provider

                    $category = Get-AzResourceCategory `
                        -Resource $item.Provider `
                        -ErrorAction 'SilentlyContinue'

                    $newResourceConfig = @{
                        Resource = @{
                            Abbreviation = "<TODO:>"
                            Entity = $resourcePath.Entity
                            Provider = $item.Provider
                        }
                        Category = if ($category) {
                            $category
                        }
                        else {
                            'other'
                        }
                        Source = "official api specs"
                    }

                    # Store in Bloom Store
                    @{
                        key = $_.Key
                        value = $newResourceConfig
                    } `
                    | Set-BloomItem `
                        -StoreName $ruleStore.Name

                    # Track key for policies
                    $policiesKeys += $_.Key
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

                # $global:Endpoint[$_.Key] = $endpointItem.Value
                @{
                    key = $endpointItem.Key
                    value = $endpointItem.Value
                } `
                | Set-BloomItem `
                    -StoreName $endpointStore.Name

                # Track key for endpoints
                $endpointsKeys += $endpointItem.Key

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

    # Build Bloom Store indices for fast lookups
    # Build-BloomStoreIndex -StoreName $ruleStore.Name | Out-Null
    # Build-BloomStoreIndex -StoreName $endpointStore.Name | Out-Null
    Compress-BloomStoreIndex -StoreName $ruleStore.Name | Out-Null
    Compress-BloomStoreIndex -StoreName $endpointStore.Name | Out-Null

    # Output directory
    $outputDir = "$PSScriptRoot/../../config"

    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    $policiesKeys `
    | Sort-Object `
    | Write-EachToJson `
        -Path "$outputDir/policies.json" `
        -Utf8JsonWriter `
        -Begin {
            $_.Writer.WriteStartObject()
            $_.Writer.WritePropertyName('policies')
            $_.Writer.WriteStartObject()
        } `
        -Process {
            $key = $_.Item
            $item = Get-BloomItem `
                -StoreName $ruleStore.Name `
                -Key $key

            $_.Writer.WritePropertyName($key)

            Write-JsonItem -Utf8JsonWriter $_.Writer -Value $item.value
        } `
        -End {
            $_.Writer.WriteEndObject()
            $_.Writer.WriteEndObject()
        } `
        -Indented

    # Build JSON files from stores
    # Write-ToJsonFromStore `
    #     -Path "$outputDir/endpoints.json" `
    #     -StoreName $endpointStore.Name `
    #     -StoreKey $endpointsKeys `
    #     -PropertyName 'endpoints' `
    #     -ItemProperty 'value'
}
finally {
    # Bloom Store data is persisted, no cleanup needed
}
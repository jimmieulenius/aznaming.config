param (
    [string]
    $ApiSpecsPath = 'C:\Users\admin\Source\Repos\azure-rest-api-specs'
)

& "$PSScriptRoot/Add-PSResourceToPath.ps1"

Import-Module `
    -Name @(
        'Az.Naming.Config'
    ) `
    -Force

Build-AzResourceNameConfig `
    -ApiSpecsPath $ApiSpecsPath `
    -Destination "$PSScriptRoot/../../config"

exit

# Import-Module `
#     -Name @(
#         'Az.Docs',
#         'Az.Naming.Config',
#         'BloomStore',
#         'DataStructure',
#         'Json'
#     ) `
#     -Force

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
        # Add-AzResourceCategory `
        #     -Category $_.Category `
        #     -Resource $_.ResourcePath

        # Add-AzResourceCategory `
        #     -Category $_.Category `
        #     -Resource (
        #         $_.ResourcePath `
        #         | Split-AzResourcePath `
        #             -Provider
        #     )

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
    # $endpointsKeys = @()

    $validCharsList = @()

    Initialize-AzResourceNameRule `
        -Process {
            $nameRule = ${Az.Naming.Config}.ResourceNameRuleLookup[$_.Key] ?? @{}

            $_ `
            | Merge-Dictionary `
                -Source $nameRule `
                -Path 'Value' `
            | Out-Null

            if ($_.Value.ValidChars) {
                $validCharsList += $_.Value.ValidChars
            }

            # Store in Bloom Store
            @{
                key = $_.Key
                value = $_.Value
            } `
            | Set-BloomItem `
                -StoreName $ruleStore.Name

            $global:ResourceCount++

            # Track key for policies
            # $policiesKeys += $_.Key
        } `
        -Force

    Build-BloomStoreIndex `
        -StoreName $ruleStore.Name `
    | Out-Null

    New-Item `
        -Path "$PSScriptRoot/../../config/validChars.txt" `
        -ItemType 'File' `
        -Force `
    | Out-Null

    $validCharsList `
    | Sort-Object `
        -Unique `
    | ForEach-Object {
        Add-Content `
            -Path "$PSScriptRoot/../../config/validChars.txt" `
            -Value $_
    }


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

    # $global:Endpoint = @{}
    $endpointStore = Register-BloomStore `
        -Name 'Endpoint' `
        -Key 'key' `
        -PassThru

    $providerConfigObject = [ordered]@{}
    # $resourceConfigObject = [ordered]@{}
    $lastProvider = $null

    # Output directory
    $outputDir = "$PSScriptRoot/../../config"

    if (-not (Test-Path $outputDir)) {
        New-Item `
            -Path $outputDir `
            -ItemType 'Directory' `
            -Force `
        | Out-Null
    }

    Invoke-AzApiSpecsItem `
        -Path $ApiSpecsPath `
        -ScriptBlock {
            $item = $_

            if ($lastProvider -ne $item.Provider) {
                Write-Host "Processing provider: $($item.Provider)"

                # Save current config object before moving to next provider

                $lastProvider = $item.Provider
                $providerConfigObject = [ordered]@{}
            }

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
            | ForEach-Object {
                Write-Host "Resource Path: $($_.Identifier)"

                $currentResourcePath += $_.Identifier
                $rule = Get-BloomItem `
                    -StoreName $ruleStore.Name `
                    -Key $_.Identifier
                # $resourceConfigObject = [ordered]@{}
                # $policyObject = [ordered]@{
                #     MinLength = $null
                #     MaxLength = $null
                #     ValidChars = $null
                #     Source = "official api specs"
                # }

                $policyObject = New-AzResourceNamePolicy `
                    -ResourcePath $_.Identifier `
                    -MinLength $rule.value.MinLength `
                    -MaxLength $rule.value.MaxLength `
                    -ValidChars $rule.value.ValidChars `
                    -Abbreviation $rule.value.Resource.Abbreviation `
                    -Source (
                        $rule.value.Source `
                            ? @{
                                type = $rule.value.Source
                                url = ${Az.Docs}.ResourceNameRulesUrl
                            } `
                            : @{
                                type = "official api specs"
                                filePath = [System.IO.Path]::GetRelativePath($ApiSpecsPath, $item.Path) -replace '\\', '/'
                            }
                    )

                # if ($rule) {
                #     Merge-Dictionary `
                #         -InputObject $policyObject `
                #         -Source (
                #             [ordered]@{
                #                 MinLength = $rule.value.MinLength
                #                 MaxLength = $rule.value.MaxLength
                #                 ValidChars = $rule.value.ValidChars
                #                 Source = $rule.value.Source
                #             }
                #         ) `
                #     | Out-Null

                #     # $policyObject = $rule.value

                #     # $configObject `
                #     # | Merge-Dictionary `
                #     #     -Source @{
                #     #         $_.Key = $rule.value
                #     #     } `
                #     #     -Path "['policies']"
                #     # | Out-Null
                # }
                # else {
                #     $resourcePath = $_.Key `
                #     | Get-AzResourcePath `
                #         -Provider $item.Provider

                #     $policyObject = @{
                #         Resource = @{
                #             Abbreviation = "<TODO:>"
                #             Entity = $resourcePath.Entity
                #             Provider = $item.Provider
                #         }
                #         Category = if ($category) {
                #             $category
                #         }
                #         else {
                #             'other'
                #         }
                #         Source = "official api specs"
                #     }
                # }

                # $resourceConfigObject.policy = $policyObject
                $providerConfigObject[$_.Identifier] = [ordered]@{
                    policy = $policyObject
                }

                # Merge-Dictionary `
                #     -InputObject $resourceConfigObject `
                #     -Source $policyObject `
                #     -Path "['policy']" `
                # | Out-Null

                # Merge-Dictionary `
                #     -InputObject $providerConfigObject `
                #     -Source $resourceConfigObject `
                #     -Path "['$($_.Key)']"
                # | Out-Null

                # if (
                #     -not (
                #         Get-AzResourceNameRule `
                #             -Name $_.Key
                #     )
                # ) {
                #     if ($policiesKeys -contains $_.Key) {
                #         Write-Verbose "Resource path already has a naming rule, skipping: $($_.Key)"

                #         return
                #     }

                #     $resourcePath = $_.Key `
                #     | Get-AzResourcePath `
                #         -Provider $item.Provider

                #     $category = Get-AzResourceCategory `
                #         -Resource $item.Provider `
                #         -ErrorAction 'SilentlyContinue'

                #     $newResourceConfig = @{
                #         Resource = @{
                #             Abbreviation = "<TODO:>"
                #             Entity = $resourcePath.Entity
                #             Provider = $item.Provider
                #         }
                #         Category = if ($category) {
                #             $category
                #         }
                #         else {
                #             'other'
                #         }
                #         Source = "official api specs"
                #     }

                #     # Store in Bloom Store
                #     # @{
                #     #     key = $_.Key
                #     #     value = $newResourceConfig
                #     # } `
                #     # | Set-BloomItem `
                #     #     -StoreName $ruleStore.Name

                #     # Track key for policies
                #     $policiesKeys += $_.Key
                # }

                $global:ResourceCount++
            }

            Get-AzResourceEndpointFromApiSpecs `
                -SpecsObject $specsObject `
                -Provider $item.Provider `
                -ResourcePath $currentResourcePath
            | ForEach-Object {
                # $resourceConfigObject = [ordered]@{}
                $endpointItem = $_
                $hasCheckNameEndpoint = $false
                $objectPath = $null

                @(
                    'checkName',
                    'get'
                ) `
                | ForEach-Object {
                    $endpointValue = $endpointItem.Value.$_

                    if (-not $endpointValue) {
                        return
                    }

                    switch ($_) {
                        ('checkname') {
                            $hasCheckNameEndpoint = $true
                            $objectPath = @(
                                'parameters',
                                'responses'
                            )
                        }
                        ('get') {
                            $objectPath = @(
                                'parameters'
                            )
                        }
                    }

                    $endpointItem.Value.$_ = $endpointValue `
                    | Resolve-AzApiSpecs `
                        -BasePath $item.Path `
                        -Path $objectPath

                    switch ($_) {
                        ('get') {
                            $constraintsObject = Get-AzResourceNamePolicyConstraintFromEndpoint `
                                -InputObject $endpointValue `
                                -ProviderConfigObject $providerConfigObject `
                                -EndpointItem $endpointItem

                            if ($constraintsObject) {
                                Merge-Dictionary `
                                    -InputObject $providerConfigObject `
                                    -Source $constraintsObject `
                                    -Path "['$($endpointItem.Identifier)'].['policy'].['constraints']" `
                                | Out-Null
                            }

                            # $nameParameter = $endpointValue.parameters `
                            # | Where-Object {
                            #     $_.name -imatch 'name' `
                            #     -and $_.in -ieq 'path'
                            # } `
                            # | Select-Object `
                            #     -Last 1

                            # if ($nameParameter) {
                            #     $resourceConfigObject = $providerConfigObject[$endpointItem.Identifier]

                            #     if (
                            #         $resourceConfigObject `
                            #         -and $resourceConfigObject.policy.metadata.source.type -ine 'official docs'
                            #     ) {
                            #         $constraintsObject = [ordered]@{}

                            #         @(
                            #             'minLength',
                            #             'maxLength',
                            #             'pattern'
                            #         ) `
                            #         | ForEach-Object {
                            #             $value = $nameParameter.$_
                                        
                            #             if ($value) {
                            #                 switch ($_) {
                            #                     ('pattern') {
                            #                         $lengthConstraint = $value `
                            #                         | Get-LengthConstraintFromPattern

                            #                         @(
                            #                             'minLength',
                            #                             'maxLength'
                            #                         ) `
                            #                         | ForEach-Object {
                            #                             if ($constraintsObject.Contains($_)) {
                            #                                 return
                            #                             }

                            #                             $constraintsValue = $lengthConstraint.$_
                                                        
                            #                             if ($constraintsValue) {
                            #                                 $constraintsObject.$_ = $constraintsValue
                            #                             }
                            #                         }
                            #                     }
                            #                 }

                            #                 $constraintsObject.$_ = $value
                            #             }
                            #         }

                            #         Merge-Dictionary `
                            #             -InputObject $providerConfigObject `
                            #             -Source $constraintsObject `
                            #             -Path "['$($endpointItem.Identifier)'].['policy'].['constraints']" `
                            #         | Out-Null
                            #     }
                            # }
                        }
                    }
                }

                # $resourceConfigObject.Endpoints = $endpointItem.Value
                # $providerConfigObject[$endpointItem.Key].endpoints = $endpointItem.Value

                if ($hasCheckNameEndpoint) {
                    if ($providerConfigObject.Contains($endpointItem.Identifier)) {
                        Merge-Dictionary `
                            -InputObject $providerConfigObject `
                            -Source $endpointItem.Value `
                            -Path "['$($endpointItem.Identifier)'].['endpoints']" `
                        | Out-Null
                    }
                    else {
                        @{
                            key = $endpointItem.Identifier
                            value = $endpointItem.Value
                        } `
                        | Set-BloomItem `
                            -StoreName $endpointStore.Name
                    }
                }

                # $global:Endpoint[$_.Key] = $endpointItem.Value
                # @{
                #     key = $endpointItem.Key
                #     value = $endpointItem.Value
                # } `

                # | Set-BloomItem `
                #     -StoreName $endpointStore.Name

                # # Track key for endpoints
                # $endpointsKeys += $endpointItem.Key

                # $global:Endpoint[$_.Key] = $_.Value `
                # | Resolve-AzApiSpecs `
                #     -BasePath $item.Path
            }

            # $resourceEndpoint `
            # | ForEach-Object {
            #     Write-Host "Resource Endpoint: $($_.Key)"
            # }

            Write-Host ''

            if ($providerConfigObject.Keys.Count) {
                # $filePath = "$outputDir/$($item.Provider).json"

                $providerConfigObject.Keys `
                | Sort-Object `
                | Write-EachToJson `
                    -Path "$outputDir/$($item.Provider).json" `
                    -Utf8JsonWriter `
                    -Begin {
                        $_.Writer.WriteStartObject()
                    } `
                    -Process {
                        $key = $_.Item
                        $item = $providerConfigObject.$key

                        Write-JsonItem `
                            -Utf8JsonWriter $_.Writer `
                            -Key $key `
                            -Value $item
                    } `
                    -End {
                        $_.Writer.WriteEndObject()
                    }

                # New-Item `
                #     -Path $filePath `
                #     -ItemType 'File' `
                #     -Force `
                # | Out-Null

                # Set-Content `
                #     -Path $filePath `
                #     -Value (
                #         $providerConfigObject `
                #         | ConvertTo-Json `
                #             -Depth 100
                #     ) `
                #     -Encoding 'utf8'
            }
        }

    Write-Host "Total Resource Paths: $($global:ResourceCount)"
    Write-Host "Abbreviations count: $(${Az.Naming.Config}.ResourceAbbreviation.Keys.Count)"

    Build-BloomStoreIndex `
        -StoreName $endpointStore.Name `
        -PassThru

    # exit

    # # Build Bloom Store indices for fast lookups
    # Build-BloomStoreIndex `
    #     -StoreName $ruleStore.Name `
    # | Out-Null
    # Build-BloomStoreIndex `
    #     -StoreName $endpointStore.Name `
    # | Out-Null
    # # Compress-BloomStoreIndex -StoreName $ruleStore.Name | Out-Null
    # # Compress-BloomStoreIndex -StoreName $endpointStore.Name | Out-Null

    # $policiesKeys `
    # | Sort-Object `
    # | Write-EachToJson `
    #     -Path "$outputDir/policies.json" `
    #     -Utf8JsonWriter `
    #     -ProcessWriterFactory {
            
    #     } `
    #     -Begin {
    #         $_.Writer.WriteStartObject()
    #         $_.Writer.WritePropertyName('policies')
    #         $_.Writer.WriteStartObject()
    #     } `
    #     -Process {
    #         $key = $_.Item
    #         $item = Get-BloomItem `
    #             -StoreName $ruleStore.Name `
    #             -Key $key

    #         $_.Writer.WritePropertyName($key)

    #         Write-JsonItem `
    #             -Utf8JsonWriter $_.Writer `
    #             -Value $item.value
    #     } `
    #     -End {
    #         $_.Writer.WriteEndObject()
    #         $_.Writer.WriteEndObject()
    #     }

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
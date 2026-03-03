function Build-AzResourceNameConfig {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiSpecsPath,

        [Parameter(Mandatory = $true)]
        [string]
        $Destination
    )

    Initialize-AzResourceAbbreviation `
        -Process {
            ${Az.Naming.Config}.ResourceNameRuleLookup[$_.ResourcePath] = @{
                Resource = @{
                    Abbreviation = $_.Abbreviation
                }
                Category = $_.Category
            }
        }

    # $global:ResourceCount = 0

    # Register global Bloom Store for all config items
    $ruleStore = Register-BloomStore `
        -Name 'Rule' `
        -Key 'key' `
        -Force `
        -PassThru

    # $validCharsList = @()

    Initialize-AzResourceNameRule `
        -Process {
            $nameRule = ${Az.Naming.Config}.ResourceNameRuleLookup[$_.Key] ?? @{}

            $_ `
            | Merge-Dictionary `
                -Source $nameRule `
                -Path 'Value' `
            | Out-Null

            # if ($_.Value.ValidChars) {
            #     $validCharsList += $_.Value.ValidChars
            # }

            # Store in Bloom Store
            @{
                key = $_.Key
                value = $_.Value
            } `
            | Set-BloomItem `
                -StoreName $ruleStore.Name

            # $global:ResourceCount++
        } `
        -Force

    $ruleIndex = Build-BloomStoreIndex `
        -StoreName $ruleStore.Name `
        -PassThru

    # New-Item `
    #     -Path "$Destination/validChars.txt" `
    #     -ItemType 'File' `
    #     -Force `
    # | Out-Null

    # $validCharsList `
    # | Sort-Object `
    #     -Unique `
    # | ForEach-Object {
    #     Add-Content `
    #         -Path "$Destination/validChars.txt" `
    #         -Value $_
    # }

    $endpointStore = Register-BloomStore `
        -Name 'Endpoint' `
        -Key 'key' `
        -Force `
        -PassThru

    $providerConfigObject = [ordered]@{}
    $lastProvider = $null
    $providerStore = Register-BloomStore `
        -Name 'provider' `
        -Key 'key' `
        -Force `
        -PassThru

    if (-not (Test-Path $Destination)) {
        New-Item `
            -Path $Destination `
            -ItemType 'Directory' `
            -Force `
        | Out-Null
    }

    $global:UsedRuleList = [System.Collections.Generic.List[string]]::new()
    $global:PoliciesCount = 0
    $global:PolicyFromApiSpecsCount = 0
    $global:PolicyFromDocsCount = 0
    $global:ConstraintsFromApiSpecsCount = 0
    $global:CheckNameEndpointCount = 0
    $global:UnresolvedAbbreviationCount = 0
    $global:CheckNameEndpointList = [System.Collections.Generic.List[string]]::new()
    $global:OutputFileCount = 0

    Invoke-AzApiSpecsItem `
        -Path $ApiSpecsPath `
        -ScriptBlock {
            $item = $_

            if ($lastProvider -ne $item.Provider) {
                $providerIndex = Build-BloomStoreIndex `
                    -StoreName $providerStore.Name `
                    -PassThru `
                    -Keys

                if ($providerIndex.Keys.Count) {
                    $providerIndex.Keys `
                    | Sort-Object `
                    | Write-EachToJson `
                        -Path "$Destination/$($lastProvider).json" `
                        -Utf8JsonWriter `
                        -Begin {
                            $_.Writer.WriteStartObject()
                        } `
                        -Process {
                            $key = $_.Item
                            $bloomItem = Get-BloomItem `
                                -StoreName $providerStore.Name `
                                -Key $key
                            $configObject = $providerConfigObject[$key]

                            if ($configObject.policy) {
                                Merge-Dictionary `
                                    -InputObject $bloomItem.value `
                                    -Source $configObject.policy `
                                    -Path 'policy' `
                                | Out-Null
                            }

                            Write-JsonItem `
                                -Utf8JsonWriter $_.Writer `
                                -Key $key `
                                -Value $bloomItem.value
                        } `
                        -End {
                            $_.Writer.WriteEndObject()
                        }

                    $global:OutputFileCount++
                }

                $lastProvider = $item.Provider
                $providerConfigObject = [ordered]@{}
                $providerStore = Register-BloomStore `
                    -Name 'provider' `
                    -Key 'key' `
                    -Force `
                    -PassThru

                if ($null -ne $lastProvider) {
                    Write-Host $null
                }

                Write-Host "Provider: $($item.Provider)"
                Write-Host "Version: $($item.Version)"
            }

            Write-Host "  Path: $($item.Path)"

            $specsObject = Get-Content `
                -Path $item.Path `
                -Raw `
            | ConvertFrom-Json `
                -AsHashtable

            $currentResourcePath = @()

            Get-AzProviderResourceFromApiSpecs `
                -SpecsObject $specsObject `
                -Provider $item.Provider `
            | ForEach-Object {
                Write-Host "    Resource Path: $($_.Identifier)"

                $currentResourcePath += $_.Identifier
                $rule = Get-BloomItem `
                    -StoreName $ruleStore.Name `
                    -Key $_.Identifier

                if ($rule) {
                    $global:UsedRuleList.Add($_.Identifier)
                }

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

                @{
                    key = $_.Identifier
                    value = [ordered]@{
                        policy = $policyObject
                    }
                } `
                | Set-BloomItem `
                    -StoreName $providerStore.Name

                # $providerConfigObject[$_.Identifier] = [ordered]@{
                #     policy = $policyObject
                # }

                if ($policyObject.metadata.isTodo) {
                    $global:UnresolvedAbbreviationCount++
                }

                if ($policyObject.metadata.source.type -eq "official api specs") {
                    $global:PolicyFromApiSpecsCount++
                }
                elseif ($policyObject.metadata.source.type -eq "official docs") {
                    $global:PolicyFromDocsCount++
                }

                $global:PoliciesCount++
            }

            Get-AzResourceEndpointFromApiSpecs `
                -SpecsObject $specsObject `
                -Provider $item.Provider `
                -ResourcePath $currentResourcePath
            | ForEach-Object {
                $endpointItem = $_
                $hasCheckNameEndpoint = $false
                $objectPath = $null
                $checkNameEndpoint = $null
                $getEndpoint = $null

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
                        ('checkName') {
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

                    $endpointValue = $endpointValue `
                    | Resolve-AzApiSpecs `
                        -BasePath $item.Path `
                        -Path $objectPath
                    $endpointItem.Value.$_ = $endpointValue

                    switch ($_) {
                        ('checkName') {
                            $hasCheckNameEndpoint = $true
                            $checkNameEndpoint = $endpointValue

                            $global:CheckNameEndpointList.Add($endpointItem.Identifier)
                        }
                        ('get') {
                            $getEndpoint = $endpointValue

                            $constraintsObject = $endpointValue `
                            | Get-AzResourceNamePolicyConstraintFromEndpoint

                            if ($constraintsObject) {
                                $global:ConstraintsFromApiSpecsCount++

                                Merge-Dictionary `
                                    -InputObject $providerConfigObject `
                                    -Source $constraintsObject `
                                    -Path "['$($endpointItem.Identifier)'].['policy'].['constraints']" `
                                | Out-Null
                            }
                        }
                    }
                }

                $endpointConfigObject = [ordered]@{}

                (
                    [ordered]@{
                        checkName = $checkNameEndpoint
                        get = $getEndpoint
                    }
                ).GetEnumerator() `
                | ForEach-Object {
                    if ($_.Value) {
                        $typeParameter = $checkNameEndpoint.parameters `
                        | Where-Object {
                            $_.name -ieq 'parameters'
                        } `
                        | ForEach-Object {
                            $_.schema.properties.type
                        }

                        if ($typeParameter) {
                            if ($typeParameter.enum.Count -eq 1) {
                                $typeParameter.value = $typeParameter.enum[0]
                            }
                        }

                        $parameterObject = @{
                            Path = $_.Value.path
                            Method = $_.Value.method
                            OperationId = $_.Value.operationId
                            Parameter = $_.Value.parameters
                            ParameterValue = @{
                                'api-version' = $specsObject.info.version
                            }
                        }

                        switch ($_.Key) {
                            ('checkName') {
                                $parameterObject.Response = $_.Value.responses
                            }
                        }

                        $endpointConfigObject[$_.Key] = New-AzResourceEndpoint @parameterObject
                    }
                }

                if ($hasCheckNameEndpoint) {
                    if ($providerConfigObject.Contains($endpointItem.Identifier)) {
                        Merge-Dictionary `
                            -InputObject $providerConfigObject `
                            -Source $endpointConfigObject `
                            -Path "['$($endpointItem.Identifier)'].['endpoints']" `
                        | Out-Null
                    }

                    $global:CheckNameEndpointCount++
                }

                @{
                    key = $endpointItem.Identifier
                    value = $endpointConfigObject
                } `
                | Set-BloomItem `
                    -StoreName $endpointStore.Name
            }

            # Write-Host ''

            # if ($providerConfigObject.Keys.Count) {
            #     $providerConfigObject.Keys `
            #     | Sort-Object `
            #     | Write-EachToJson `
            #         -Path "$Destination/$($item.Provider).json" `
            #         -Utf8JsonWriter `
            #         -Begin {
            #             $_.Writer.WriteStartObject()
            #         } `
            #         -Process {
            #             $key = $_.Item
            #             $item = $providerConfigObject.$key

            #             Write-JsonItem `
            #                 -Utf8JsonWriter $_.Writer `
            #                 -Key $key `
            #                 -Value $item
            #         } `
            #         -End {
            #             $_.Writer.WriteEndObject()
            #         }

            #     $global:OutputFileCount++
            # }
        }

    $endpointIndex = Build-BloomStoreIndex `
        -StoreName $endpointStore.Name `
        -PassThru

    $unusedRuleList = [System.Collections.Generic.List[string]]::new()

    Get-BloomItem `
        -StoreName $ruleStore.Name `
        -AsHashtable `
    | ForEach-Object {
        $ruleKey = $_.key

        foreach ($usedRuleListItem in $global:UsedRuleList) {
            if ($usedRuleListItem -ieq $ruleKey) {
                return
            }
        }

        $unusedRuleList.Add($ruleKey)
    }

    Write-Host
    Write-Host

    Write-Host "Unused Rules List:"
    $unusedRuleList `
    | Sort-Object `
    | ForEach-Object {
        Write-Host "  $_"
    }

    Write-Host

    Write-Host "Unresolved CheckName Endpoints List:"
    $global:CheckNameEndpointList `
    | Sort-Object `
    | ForEach-Object {
        Write-Host "  $_"
    }

    Write-Host

    Write-Host "Rules count:"
    Write-Host "  Total: $($ruleIndex.KeyCount)"
    Write-Host "  Used: $($global:UsedRuleList.Count)"
    Write-Host "  Unused: $($unusedRuleList.Count)"
    Write-Host "Policies count:"
    Write-Host "  Total: $($global:PoliciesCount)"
    Write-Host "  From docs: $($global:PolicyFromDocsCount)"
    Write-Host "  From API specs: $($global:PolicyFromApiSpecsCount)"
    Write-Host "Abbreviations count:"
    Write-Host "  Total: $(${Az.Naming.Config}.ResourceAbbreviation.Keys.Count)"
    Write-Host "  Unresolved: $($global:UnresolvedAbbreviationCount)"
    Write-Host "Constraints count:"
    Write-Host "  From docs: $($global:PolicyFromDocsCount)"
    Write-Host "  From API specs: $($global:ConstraintsFromApiSpecsCount)"
    Write-Host "Endpoints count:"
    Write-Host "  Total: $($endpointIndex.KeyCount)"
    Write-Host "  CheckName: $($global:CheckNameEndpointCount)"

    Write-Host

    Write-Host "Output Files Count: $($global:OutputFileCount)"
}
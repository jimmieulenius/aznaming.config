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

    $global:ResourceCount = 0

    # Register global Bloom Store for all config items
    $ruleStore = Register-BloomStore `
        -Name 'Rule' `
        -Key 'key' `
        -Force `
        -PassThru

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
        } `
        -Force

    Build-BloomStoreIndex `
        -StoreName $ruleStore.Name `
    | Out-Null

    New-Item `
        -Path "$Destination/validChars.txt" `
        -ItemType 'File' `
        -Force `
    | Out-Null

    $validCharsList `
    | Sort-Object `
        -Unique `
    | ForEach-Object {
        Add-Content `
            -Path "$Destination/validChars.txt" `
            -Value $_
    }

    $endpointStore = Register-BloomStore `
        -Name 'Endpoint' `
        -Key 'key' `
        -Force `
        -PassThru

    $providerConfigObject = [ordered]@{}
    $lastProvider = $null

    if (-not (Test-Path $Destination)) {
        New-Item `
            -Path $Destination `
            -ItemType 'Directory' `
            -Force `
        | Out-Null
    }

    $global:ConstraintsFromApiSpecsCount = 0
    $global:CheckNameEndpointCount = 0

    Invoke-AzApiSpecsItem `
        -Path $ApiSpecsPath `
        -ScriptBlock {
            $item = $_

            if ($lastProvider -ne $item.Provider) {
                $lastProvider = $item.Provider
                $providerConfigObject = [ordered]@{}

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

                $providerConfigObject[$_.Identifier] = [ordered]@{
                    policy = $policyObject
                }

                $global:ResourceCount++
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
                        ('checkname') {
                            $hasCheckNameEndpoint = $true
                            $objectPath = @(
                                'parameters',
                                'responses'
                            )
                            $checkNameEndpoint = $endpointValue
                        }
                        ('get') {
                            $objectPath = @(
                                'parameters'
                            )
                            $getEndpoint = $endpointValue
                        }
                    }

                    $endpointValue = $endpointValue `
                    | Resolve-AzApiSpecs `
                        -BasePath $item.Path `
                        -Path $objectPath
                    $endpointItem.Value.$_ = $endpointValue

                    switch ($_) {
                        ('checkname') {
                            $checkNameEndpoint = $endpointValue
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
                        $endpointConfigObject[$_.Key] = $_.Value
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

            if ($providerConfigObject.Keys.Count) {
                $providerConfigObject.Keys `
                | Sort-Object `
                | Write-EachToJson `
                    -Path "$Destination/$($item.Provider).json" `
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
            }
        }

    $endpointIndex = Build-BloomStoreIndex `
        -StoreName $endpointStore.Name `
        -PassThru

    Write-Host $null
    Write-Host $null
    Write-Host "Total Resource Paths: $($global:ResourceCount)"
    Write-Host "Abbreviations count: $(${Az.Naming.Config}.ResourceAbbreviation.Keys.Count)"
    Write-Host "Constraints from API Specs count: $($global:ConstraintsFromApiSpecsCount)"
    Write-Host "Checkname endpoints count: $($global:CheckNameEndpointCount)"
    Write-Host "Total Endpoint Count: $($endpointIndex.KeyCount)"
}
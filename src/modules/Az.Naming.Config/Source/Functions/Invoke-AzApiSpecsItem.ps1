function Invoke-AzApiSpecsItem {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [string[]]
        $ApiType = @(
            'data-plane',
            'resource-manager'
        ),

        [string[]]
        $VersionPreference = @(
            'stable',
            'preview'
        ),

        [scriptblock]
        $ProviderResolver = {
            $path = "$($_.FullName)/resource-manager"

            if (
                Test-Path `
                    -Path $path `
                    -PathType 'Container'
            ) {
                return (
                    Get-ChildItem `
                        -Path $path `
                        -Directory `
                    | Where-Object {
                        $_.Name -ine 'common'
                    } `
                    | Select-Object `
                        -First 1
                ).Name
            }
        }
    )

    if (
        -not (
            Test-Path `
                -Path "$Path/specification" `
                -PathType 'Container'
        )
    ) {
        throw "API specs path not found: $Path/specification"
    }

    Get-ChildItem `
        -Path "$Path/specification" `
        -Directory `
    | ForEach-Object {
        $providerContainerPath = $_.FullName

        if ($ProviderResolver) {
            $provider = $_ `
            | ForEach-Object `
                -Process $ProviderResolver
        }

        foreach ($apiTypeItem in $ApiType) {
            $apiTypePath = "$providerContainerPath/$apiTypeItem"

            if (
                -not (
                    Test-Path `
                        -Path $apiTypePath `
                        -PathType 'Container'
                )
            ) {
                continue
            }

            Get-ChildItem `
                -Path $apiTypePath `
                -Directory `
                -ErrorAction 'SilentlyContinue' `
            | ForEach-Object {
                $provider ??= $_.Name

                $containers = Get-ChildItem `
                    -Path $_.FullName `
                    -Directory `
                    -ErrorAction 'SilentlyContinue'

                if (
                    (
                        $containers `
                        | Where-Object {
                            $_.Name -imatch "$($VersionPreference -join '|')"
                        }
                    ).Count
                ) {
                    $containers = $_
                }

                $containers `
                | ForEach-Object {
                    foreach ($versionPreferenceItem in $VersionPreference) {
                        $versionContainerPath = "$($_.FullName)/$versionPreferenceItem"

                        if (
                            -not (
                                Test-Path `
                                    -Path $versionContainerPath `
                                    -PathType 'Container'
                            )
                        ) {
                            continue
                        }

                        # Get-ChildItem `
                        #     -Path $_.FullName `
                        #     -Directory `
                        #     -Filter $versionPreferenceItem `
                        #     -Recurse `
                        #     -ErrorAction 'SilentlyContinue' `
                        # | ForEach-Object {
                            $specsContainer = Get-ChildItem `
                                -Path $versionContainerPath `
                                -Directory `
                                -ErrorAction 'SilentlyContinue' `
                            | Sort-Object `
                                -Property 'Name' `
                            | Select-Object `
                                -Last 1

                            if (-not $specsContainer) {
                                return
                            }

                            Get-ChildItem `
                                -Path $specsContainer.FullName `
                                -Filter '*.json' `
                                -File `
                                -ErrorAction 'SilentlyContinue' `
                            | ForEach-Object {
                                @{
                                    Provider = $provider
                                    Version = $specsContainer.Name
                                    Path = $_.FullName
                                } `
                                | ForEach-Object `
                                    -Process $ScriptBlock
                            }

                            break
                        # }

                        # $specsContainer = Get-ChildItem `
                        #     -Path $versionContainerPath `
                        #     -Directory `
                        #     -ErrorAction 'SilentlyContinue' `
                        # | Sort-Object `
                        #     -Property 'Name' `
                        # | Select-Object `
                        #     -Last 1

                        # if (-not $specsContainer) {
                        #     continue
                        # }

                        # Get-ChildItem `
                        #     -Path $specsContainer.FullName `
                        #     -Filter '*.json' `
                        #     -File `
                        #     -ErrorAction 'SilentlyContinue' `
                        # | ForEach-Object {
                        #     # & $ScriptBlock `
                        #     #     -InputObject @{
                        #     #         Provider = $provider
                        #     #         Version = $specsContainer.Name
                        #     #         Path = $_.FullName
                        #     #     }

                        #     @{
                        #         Provider = $provider
                        #         Version = $specsContainer.Name
                        #         Path = $_.FullName
                        #     } `
                        #     | ForEach-Object `
                        #         -Process $ScriptBlock
                        # }

                        # break
                    }
                }
            }
        }
    }
}
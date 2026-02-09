function Invoke-AzApiSpecsItem {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock,

        [String[]]
        $ApiType = @('resource-manager'),

        [String[]]
        $VersionPreference = @(
            'stable',
            'preview'
        )
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
                $provider = $_.Name

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

                    $specsContainer = Get-ChildItem `
                        -Path $versionContainerPath `
                        -Directory `
                        -ErrorAction 'SilentlyContinue' `
                    | Sort-Object `
                        -Property 'Name' `
                    | Select-Object `
                        -Last 1

                    if (-not $specsContainer) {
                        continue
                    }

                    Get-ChildItem `
                        -Path $specsContainer.FullName `
                        -Filter '*.json' `
                        -File `
                        -ErrorAction 'SilentlyContinue' `
                    | ForEach-Object {
                        # & $ScriptBlock `
                        #     -InputObject @{
                        #         Provider = $provider
                        #         Version = $specsContainer.Name
                        #         Path = $_.FullName
                        #     }

                        @{
                            Provider = $provider
                            Version = $specsContainer.Name
                            Path = $_.FullName
                        } `
                        | ForEach-Object `
                            -Process $ScriptBlock
                    }

                    break
                }
            }
        }
    }
}
function Invoke-ApiSpecsAction {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $Action

        # [String]
        # $Filter = "(resource-manager|data-plane).*\.json$"
    )

    # $files = Get-ChildItem `
    #     -Path $Path `
    #     -Recurse `
    #     -ErrorAction 'SilentlyContinue' `
    # | Where-Object { $_.FullName -match $Filter } `
    # | ForEach-Object {
    #     & $Action `
    #         -InputObject $_
    # }

    Get-ChildItem `
        -Path "$Path/specification" `
        -Directory `
    | ForEach-Object {
        Get-ChildItem `
            -Path "$($_.FullName)/resource-manager" `
            -Directory `
            -ErrorAction 'SilentlyContinue' `
        | ForEach-Object {
            $provider = $_.Name
            $isProcessed = $false

            foreach (
                $versionContainer in @(
                    'stable',
                    'preview'
                )
            ) {
                $versionContainerPath = "$($_.FullName)/$versionContainer"

                if (
                    Test-Path `
                        -Path $versionContainerPath
                ) {
                    Get-ChildItem `
                        -Path $versionContainerPath `
                        -Directory `
                    | Select-Object `
                        -Last 1 `
                    | ForEach-Object {
                        $version = $_.Name

                        Get-ChildItem `
                            -Path $_.FullName `
                            -File `
                            -Filter '*.json' `
                        | ForEach-Object {
                            & $Action `
                                -InputObject @{
                                    Provider = $provider
                                    Version = $version
                                    Path = $_.FullName
                                }

                            $isProcessed = $true
                        }
                    }
                }

                if ($isProcessed) {
                    break
                }
            }
        }
    }
}
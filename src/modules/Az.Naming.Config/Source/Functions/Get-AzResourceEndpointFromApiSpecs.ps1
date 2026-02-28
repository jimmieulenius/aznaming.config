function Get-AzResourceEndpointFromApiSpecs {
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $SpecsObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Provider,

        [string[]]
        $ResourcePath = @()
    )    

    if ($SpecsObject.ContainsKey('paths')) {
        $SpecsObject.paths.GetEnumerator() `
        | ForEach-Object {
            $path = $_.Key
            $endpoint = $_.Value

            $identifier = (
                $_.Key `
                | Get-AzResourcePath `
                    -Provider $Provider
            ).Path

            $parameters = $null

            $endpoint.GetEnumerator() `
            | ForEach-Object {
                if ($_.Value.deprecated) {
                    return
                }

                if ($_.Key -ieq 'parameters') {
                    $parameters = $_.Value

                    return
                }

                $endpointName = $null

                if ($_.Value.operationId -imatch 'check.*nameavailability') {
                    $endpointName = 'checkName'
                }
                elseif (
                    $_.Key -ieq 'get' `
                    -and $ResourcePath -icontains $identifier `
                    -and $endpoint.ContainsKey('put')
                ) {
                    $endpointName = 'get'
                }
                else {
                    return
                }

                if (-not $endpointName) {
                    return
                }

                $endpointValue = (
                    $_.Value `
                    | Merge-Dictionary `
                        -Source @{
                            path = $path
                            method = $_.Key
                        } `
                        -PassThru
                )

                # $result = @{
                #     Identifier = $identifier
                #     Value = @{
                #         $endpointName = (
                #             $_.Value `
                #             | Merge-Dictionary `
                #                 -Source @{
                #                     path = $path
                #                     method = $_.Key
                #                 } `
                #                 -PassThru
                #         )
                #     }
                # }

                if ($parameters) {
                    $endpointParameters = $_.Value.parameters `
                    | Merge-Parameters `
                        -Source $parameters

                    if ($endpointParameters) {
                        $endpointValue.parameters = $endpointParameters
                    }
                }

                @{
                        Identifier = $identifier
                        Value = @{
                            $endpointName = $endpointValue
                        }
                    }
            }

            # $_.Value.post.operationId,
            # $_.Value.get.operationId `
            # | Where-Object {
            #     $_ -imatch 'check.*nameavailability'
            # } `
            # | ForEach-Object {
            #     $_
            # }
        }
    }
}

function Merge-Parameters {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [object]
        $Source
    )

    if (-not $InputObject) {
        return $Source
    }

    if (
        (
            Test-Array `
                -InputObject $InputObject
        ) `
        -and (
            Test-Array `
                -InputObject $Source
        )
    ) {
        $Source `
        | ForEach-Object {
            $indexToUpdate = $null

            for ($index = 0; $index -lt $InputObject.Count; $index++) {
                if ($InputObject[$index].name -ieq $_.name) {
                    $indexToUpdate = $index

                    break
                }
            }

            if ($indexToUpdate) {
                $InputObject[$indexToUpdate] = $_
            }
            else {
                $InputObject += $_
            }
        }
    }

    return $InputObject
}
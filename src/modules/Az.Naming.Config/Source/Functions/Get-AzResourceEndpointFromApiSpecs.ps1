function Get-AzResourceEndpointFromApiSpecs {
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $SpecsObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Provider,

        [string[]]
        $ResourcePath = @(),

        [Switch]
        $AsKeyValue
    )    

    if ($SpecsObject.ContainsKey('paths')) {
        $SpecsObject.paths.GetEnumerator() `
        | ForEach-Object {
            # $path = $_.Key

            $key = (
                $_.Key `
                | Get-AzResourcePath `
                    -Provider $Provider
            ).Path

            $_.Value.GetEnumerator() `
            | ForEach-Object {
                if ($_.Value.deprecated) {
                    return
                }

                $endpointName = $null

                if ($_.Value.operationId -imatch 'check.*nameavailability') {
                    $endpointName = 'checkName'
                }
                elseif (
                    $_.Key -ieq 'get' `
                    -and $ResourcePath -icontains $key
                ) {
                    $endpointName = 'get'
                }
                else {
                    return
                }

                if ($endpointName) {
                    # $key = (
                    #     $path `
                    #     | Get-AzResourcePath `
                    #         -Provider $Provider
                    # ).Path

                    if ($AsKeyValue) {
                        @{
                            Key = $key
                            Value = @{
                                $endpointName = (
                                    $_.Value `
                                    | Merge-Dictionary `
                                        -Source @{
                                            method = $_.Key
                                        } `
                                        -PassThru
                                )
                            }
                        }
                    }
                    else {
                        $key
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
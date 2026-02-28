function New-AzResourceEndpoint {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "GET",
            "POST",
            "PUT",
            "DELETE",
            "PATCH"
        )]
        [string]
        $Method,

        [hashtable[]]
        $Parameter,

        [hashtable[]]
        $Response,

        [string]
        $OperationId,

        [hashtable]
        $ParameterValue
    )

    if ($ParameterValue.Keys.Count) {
        $Parameter = $Parameter `
        | ForEach-Object {
            $name = $_.name

            if (-not $name) {
                return
            }

            if ($ParameterValue.ContainsKey($name)) {
                $_.value = $ParameterValue[$name]
            }

            return $_
        }
    }

    $result = [ordered]@{
        path = $Path
        method = $Method
        parameters = $Parameter
    }

    (
        [ordered]@{
            operationId = $OperationId
            parameters = $Parameter
            response = $Response
        }
    ).GetEnumerator() `
    | ForEach-Object {
        if ($_.Value) {
            $result[$_.Key] = $_.Value
        }
    }

    return $result
}
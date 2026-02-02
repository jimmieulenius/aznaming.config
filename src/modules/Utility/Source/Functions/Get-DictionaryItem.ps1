function Get-DictionaryItem {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject,

        [String]
        $Path,

        [Switch]
        $AsKeyValue
    )

    if (
        -not (
            $InputObject `
            | Get-IsDictionary
        )
    ) {
        throw "InputObject must be a dictionary."
    }

    if ($Path) {
        $InputObject `
        | Invoke-DictionaryItem `
            -Path $Path `
            -ScriptBlock {
                return $_
            } `
            -AsKeyValue:$AsKeyValue `
        | Select-Object `
            -Last 1
    }
    else {
        $InputObject `
        | Invoke-DictionaryItem `
            -ScriptBlock {
                return $_
            } `
            -AsKeyValue:$AsKeyValue
    }
}
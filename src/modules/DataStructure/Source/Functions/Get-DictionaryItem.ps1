function Get-DictionaryItem {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject,

        [string]
        $Path
    )

    if (
        -not (
            Get-IsDictionary `
                -InputObject $InputObject
        )
    ) {
        Write-Error `
            -Message 'InputObject must be a dictionary.'

        return
    }

    if ($Path) {
        Invoke-DictionaryItem `
            -InputObject $InputObject `
            -Path $Path `
            -ScriptBlock {
                return $_
            }
        | Select-Object `
            -Last 1
    }
    else {
        Invoke-DictionaryItem `
            -InputObject $InputObject `
            -ScriptBlock {
                return $_
            }
    }
}
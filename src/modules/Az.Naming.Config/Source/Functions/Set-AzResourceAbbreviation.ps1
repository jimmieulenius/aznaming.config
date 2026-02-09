function Set-AzResourceAbbreviation {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Abbreviation,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourcePath
    )

    $resourceAbbreviations = Get-AzResourceAbbreviation
    $resourceAbbreviations[$Abbreviation] = $ResourcePath
}
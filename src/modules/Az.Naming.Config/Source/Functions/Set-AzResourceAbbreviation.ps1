function Set-AzResourceAbbreviation {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Abbreviation,

        [Parameter(Mandatory = $true)]
        [String]
        $ResourcePath
    )

    $resourceAbbreviations = Get-AzResourceAbbreviation
    $resourceAbbreviations[$Abbreviation] = $ResourcePath
}
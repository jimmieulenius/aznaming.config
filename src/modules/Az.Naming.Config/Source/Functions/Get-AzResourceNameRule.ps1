function Get-AzResourceNameRule {
    param (
        [String]
        $Name
    )

    $result = Initialize-AzResourceNameRule

    if ($Name) {
        return $result[$Name]
    }

    return $result
}
function Get-AzResourceNameRule {
    param (
        [string]
        $Name
    )

    $result = Initialize-AzResourceNameRule

    if ($Name) {
        return $result[$Name]
    }

    return $result
}
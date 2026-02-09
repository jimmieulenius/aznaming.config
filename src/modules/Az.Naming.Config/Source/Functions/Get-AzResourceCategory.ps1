function Get-AzResourceCategory {
    param (
        [string]
        $Resource
    )

    return ${Az.Naming.Config}.ResourceCategoryLookup[$Resource]
}
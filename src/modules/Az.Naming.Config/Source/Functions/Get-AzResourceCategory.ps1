function Get-AzResourceCategory {
    param (
        [String]
        $Resource
    )

    return ${Az.Naming.Config}.ResourceCategoryLookup[$Resource]
}
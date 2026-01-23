function Add-AzResourceCategory {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Category,

        [Parameter(Mandatory = $true)]
        [String]
        $Resource
    )

    $sanitizedCategory = $Category `
    | ConvertTo-SanitizedCategory

    if ($Script:CategoryList -inotcontains $sanitizedCategory) {
        $Script:CategoryList += $sanitizedCategory
    }

    $resourceCategoryItem = ${Az.Naming.Config}.ResourceCategoryLookup[$Resource]

    if (-not $resourceCategoryItem) {
        ${Az.Naming.Config}.ResourceCategoryLookup[$Resource] = $sanitizedCategory
    }
}
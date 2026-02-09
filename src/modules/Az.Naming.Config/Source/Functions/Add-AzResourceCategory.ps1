function Add-AzResourceCategory {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Category,

        [Parameter(Mandatory = $true)]
        [string]
        $Resource
    )

    $sanitizedCategory = $Category `
    | ConvertTo-SanitizedCategory

    if ($script:CategoryList -inotcontains $sanitizedCategory) {
        $script:CategoryList += $sanitizedCategory
    }

    $resourceCategoryItem = ${Az.Naming.Config}.ResourceCategoryLookup[$Resource]

    if (-not $resourceCategoryItem) {
        ${Az.Naming.Config}.ResourceCategoryLookup[$Resource] = $sanitizedCategory
    }
}
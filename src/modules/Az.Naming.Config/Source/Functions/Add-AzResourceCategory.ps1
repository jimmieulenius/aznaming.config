function Add-AzResourceCategory {
    param (
        [String]
        $Category,

        [String]
        $ResourcePath
    )

    $sanitizedCategory = $Category `
    | ConvertTo-SanitizedCategory

    $resourceByCategoryItem = ${Az.Naming.Config}.ResourceByCategory[$sanitizedCategory] ?? @()

    if ($resourceByCategoryItem -inotcontains $ResourcePath) {
        $resourceByCategoryItem += $ResourcePath
    }

    ${Az.Naming.Config}.ResourceByCategory[$sanitizedCategory] = $resourceByCategoryItem
}
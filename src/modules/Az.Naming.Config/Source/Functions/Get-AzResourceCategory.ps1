function Get-AzResourceCategory {
    param (
        [String]
        $Resource
    )

    if (-not ${Az.Naming.Config}.ResourceByCategory) {
        return
    }

    foreach ($keyValue in ${Az.Naming.Config}.ResourceByCategory.GetEnumerator()) {
        if ($keyValue.Value -icontains $Resource) {
            return $keyValue.Key
        }
    }
}
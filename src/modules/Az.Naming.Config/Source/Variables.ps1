$script:ResourceAbbreviation = @{}
$script:ResourceNameRuleLookup = @{}
$script:CategoryList = @()
$script:ResourceCategoryLookup = @{}
$script:DefaultMinLength = 1
$script:DefaultMaxLength = 90

Export-ModuleMember `
    -Variable '*'
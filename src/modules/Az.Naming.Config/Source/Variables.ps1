$script:ResourceAbbreviation = @{}
$script:ResourceNameRuleLookup = @{}
$script:CategoryList = @()
$script:ResourceCategoryLookup = @{}
$script:DefaultMinLength = 1
$script:DefaultMaxLength = 80

Export-ModuleMember `
    -Variable '*'
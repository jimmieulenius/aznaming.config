$Script:ResourceAbbreviation = @{}
$Script:ResourceNameRuleLookup = @{}
$Script:CategoryList = @()
$Script:ResourceCategoryLookup = @{}
$Script:DefaultMinLength = 1
$Script:DefaultMaxLength = 80

Export-ModuleMember `
    -Variable '*'
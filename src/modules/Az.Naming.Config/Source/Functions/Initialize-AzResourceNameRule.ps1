function Initialize-AzResourceNameRule {
    param (
        [ScriptBlock]
        $ItemAction,

        [Switch]
        $Force
    )

    if (
        -not $Force `
        -and ${Az.Naming.Config}.ResourceNameRuleLookup
    ) {
        return ${Az.Naming.Config}.ResourceNameRuleLookup
    }

    $lines = Save-WebDocument `
        -Url ${Az.Docs}.ResourceNameRulesUrl `
        -Force:$Force `
        -PassThru

    $result = @{}
    # Parse markdown table rows (they use blockquote format with >)
    # Format: > | Entity | Scope | Length | Valid Characters |
    # The section header is: ## Microsoft.Provider
    
    $currentProvider = ""

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        # Track current provider section (e.g., "## Microsoft.KeyVault")
        if ($line -match '##\s+Microsoft\.([a-zA-Z]+)') {
            $currentProvider = "Microsoft.$($matches[1])"

            continue
        }
        
        # Look for blockquote table rows
        if ($line -match '^\s*>\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*(.+)\s*\|\s*$') {
            $entity = $matches[1].Trim()
            $scope = $matches[2].Trim()
            $length = $matches[3].Trim()
            $validChars = $matches[4].Trim()
            
            # Skip header row and separator
            if (
                $entity -eq 'Entity' `
                -or $entity -eq 'Resource' `
                -or $entity -eq '---'
            ) {
                continue
            }
            
            # Parse length: "3-24" or "1-100" or "1-50<br><br>..."
            $minLength = $Script:DefaultMinLength
            $maxLength = $Script:DefaultMaxLength

            if ($length -match '(\d+)-(\d+)') {
                $minLength = [int]$matches[1]
                $maxLength = [int]$matches[2]
            }
            
            # Generate pattern from valid chars description
            # $pattern = ConvertDescriptionToPattern $validChars
            
            # Create rule entry with provider context
            # Use full path like "Microsoft.KeyVault/vaults" as the key for exact matching
            if ($entity -and $entity.Length -gt 0 -and $currentProvider) {
                # $resourceKey = if ($entity -match '/') {
                #     # Already has provider prefix or path separator
                #     $entity
                # }
                # else {
                #     # Add current provider context
                #     "$currentProvider/$entity"
                # }

                $resourceKey = "$currentProvider/$(
                    (
                        $entity -split '/' `
                        | ForEach-Object {
                            $_.Trim()
                        }
                    ) -join '/'
                )"

                $item = @{
                    Key = $resourceKey
                    Value = @{
                        Resource = @{
                            Entity = $entity
                            Provider = $currentProvider
                        }
                        Scope = $scope
                        MinLength = $minLength
                        MaxLength = $maxLength
                        ValidChars = $validChars
                        #pattern = $pattern
                        Source = "official"
                    }
                }

                if ($ItemAction) {
                    $item = & $ItemAction `
                        -InputObject $item
                }
                
                if (
                    $item `
                    -and $item.Key `
                    -and $item.Value
                ) {
                    $result[$item.Key] = $item.Value
                }

                # $result[$resourceKey] = @{
                #     entity = $entity
                #     provider = $currentProvider
                #     scope = $scope
                #     minLength = $minLength
                #     maxLength = $maxLength
                #     description = $validChars
                #     #pattern = $pattern
                #     source = "official"
                # }
                
                # Store simple entity key too (for backward compatibility)
                # if (-not $result.ContainsKey($entity)) {
                #     $result[$entity] = $result[$resourceKey]
                # }
            }
        }
    }
    
    # Post-processing: Generate full resource path keys from entity name format keys
    # For example, if we have key "storageAccounts / blobServices", also add key
    # "Microsoft.Storage/storageAccounts/blobServices" for direct lookup
    # $entitiesToProcess = @($result.Keys) # Create a copy to avoid modifying while iterating

    # foreach ($key in $entitiesToProcess) {
    #     # Check if this is an entity name format with spaces (e.g., "storageAccounts / blobServices")
    #     if ($key -match '^[a-zA-Z]+(\s*\/\s*[a-zA-Z]+)+$') {
    #         $rule = $result[$key]

    #         if ($rule -and $rule.provider) {
    #             # Convert "storageAccounts / blobServices" to "Microsoft.Storage/storageAccounts/blobServices"
    #             $parts = $key -split '\s*/\s*' | ForEach-Object { $_.Trim() }
    #             $resourcePath = $rule.provider + '/' + ($parts -join '/')
                
    #             # Add the full resource path as an additional key pointing to the same rule
    #             if (-not $result.ContainsKey($resourcePath)) {
    #                 $result[$resourcePath] = $rule

    #                 $result.Remove($key)
    #             }
    #         }
    #     }
    # }

    ${Az.Naming.Config}.ResourceNameRuleLookup = $result

    return $result
}
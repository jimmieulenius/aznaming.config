Export-ModuleVariable

# # Initialize script-level registry for Bloom Stores
# # Stores are identified by name and contain all necessary metadata
# $script:BloomStores = @{}

# # Dot-source the Bloom filter class
# . $PSScriptRoot\Source\Classes\BloomFilter.ps1

# # Dot-source functions
# Get-ChildItem -Path "$PSScriptRoot\Source\Functions" -Filter "*.ps1" | 
#     ForEach-Object { . $_.FullName }

# # Export public functions
# Export-ModuleMembers -Function @(
#     'Register-BloomStore'
#     'Unregister-BloomStore'
#     'Set-BloomItem'
#     'Get-BloomItem'
#     'Test-BloomKey'
#     'Build-BloomStoreIndex'
#     'Compress-BloomStoreIndex'
# )

<#
.SYNOPSIS
Rebuilds the index and Bloom filter for a Bloom Store.

.DESCRIPTION
Scans the entire data file and rebuilds the index and Bloom filter from scratch.
Use this after performing multiple Set-BloomItem operations with -Build $false,
or when you need to refresh the index after manual data file modifications.

.PARAMETER StoreName
The name of the registered Bloom Store

.EXAMPLE
# Append many items without rebuilding
1..1000 | ForEach-Object {
    @{ key = "item-$_"; data = $_ } | Set-BloomItem -StoreName "resources"
}

# Then rebuild index once
Build-BloomStoreIndex -StoreName "resources"

# Now fast lookups are available
Get-BloomItem -StoreName "resources" -Key "item-500"
#>
function Build-BloomStoreIndex {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoreName,

        [switch]
        $PassThru
    )
    
    process {
        try {
            # Validate store exists
            if (-not $script:BloomStores.ContainsKey($StoreName)) {
                Write-Error "Store '$StoreName' is not registered. Use Register-BloomStore first."
                
                return
            }
            
            Write-Verbose "Building index for store: $StoreName"

            $bloomSize = Invoke-BloomStoreIndexBuild `
                -StoreName $StoreName
            
            $store = $script:BloomStores[$StoreName]
            
            if ($PassThru) {
                [PSCustomObject]@{
                    StoreName = $StoreName
                    # KeyCount      = if ($store.Index) { $store.Index.Count } else { 0 }
                    KeyCount = $store.Index `
                        ? $store.Index.Count `
                        : 0
                    BloomSizeKB = [Math]::Round($bloomSize / 1KB, 2)
                    LastRebuilt = $store.LastRebuild
                }
            }
        }
        catch {
            Write-Error "Failed to build index: $_"
        }
    }
}

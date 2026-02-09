# Internal function to rebuild index and Bloom filter for a store
# Used by Set-BloomItem, Build-BloomStoreIndex, and Compress-BloomStoreIndex

function Invoke-BloomStoreIndexBuild {
    [CmdletBinding()]
    param(
        [string]
        $StoreName
    )
    
    $store = $script:BloomStores[$StoreName]
    
    # Count items
    $itemCount = @(Get-Content -Path $store.DataFile -ErrorAction SilentlyContinue).Count
    
    if ($null -eq $itemCount) {
        $itemCount = 0
    }

    if ($itemCount -eq 0) { 
        Write-Verbose "Store is empty, skipping index rebuild"

        return 0 
    }
    
    Write-Verbose "Rebuilding index for store: $StoreName ($itemCount items)"
    
    # Create Bloom filter
    $bloom = [BloomFilter]::new(
        [Math]::Max($itemCount, 100),
        0.01
    )
    $index = @{}
    $offset = 0
    
    # Process each line
    Get-Content `
        -Path $store.DataFile `
    | ForEach-Object {
        try {
            $obj = $_ `
            | ConvertFrom-Json `
                -AsHashtable `
                -ErrorAction 'Stop'
            
            # Extract all keys using each extractor (native ForEach-Object for $_ support)
            foreach ($extractor in $store.KeyExtractors) {
                $key = $obj | ForEach-Object -Process $extractor

                if (-not [string]::IsNullOrEmpty($key)) {
                    $key = [string]$key
                    $bloom.Add($key)
                    
                    # Always update to keep last occurrence
                    $index[$key] = @{
                        Offset = $offset
                        Length = $_.Length
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to parse line: $_"
        }
        
        $offset += $_.Length + [System.Environment]::NewLine.Length
    }
    
    # Save Bloom filter with metadata
    $bloomMetadata = @{
        bitArray = $bloom.bitArray
        size = $bloom.size
        hashCount = $bloom.hashCount
    }
    $bloomMetadata `
    | Export-Clixml `
        -Path "$($store.BloomFile).metadata"
    
    # Save binary data
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $bloom.bitArray `
        | Set-Content `
            -Path $store.BloomFile `
            -AsByteStream
    }
    else {
        [byte[]]$bloom.bitArray `
        | Set-Content `
            -Path $store.BloomFile `
            -Encoding Byte
    }

    $index `
    | Export-Clixml `
        -Path $store.IndexFile
    
    # Update in-memory cache
    $store.Bloom = $bloom
    $store.Index = $index
    $store.LastRebuild = Get-Date
    
    Write-Verbose "Index rebuilt with $($index.Count) keys"
    
    return $bloom.GetSizeInBytes()
}

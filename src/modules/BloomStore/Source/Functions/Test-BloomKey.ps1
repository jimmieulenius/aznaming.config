<#
.SYNOPSIS
Tests if a key exists in a Bloom Store.

.DESCRIPTION
Performs a fast existence check using only the Bloom filter (no index/file access).
Returns $true if key might exist, $false if definitely doesn't exist.

.PARAMETER StoreName
The name of the registered Bloom Store

.PARAMETER Key
The key to test

.EXAMPLE
# Quick existence check
if (Test-BloomKey -StoreName "resources" -Key "vm-eastus") {
    $item = Get-BloomItem -StoreName "resources" -Key "vm-eastus"
}
#>
function Test-BloomKey {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoreName,
        
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $Key
    )
    
    process {
        try {
            # Validate store exists
            if (-not $script:BloomStores.ContainsKey($StoreName)) {
                Write-Error "Store '$StoreName' is not registered. Use Register-BloomStore first."

                return
            }
            
            $store = $script:BloomStores[$StoreName]
            
            # Load Bloom if not cached
            if (-not $store.Bloom) {
                if (
                    -not (
                        Test-Path `
                            -Path $store.BloomFile
                    )
                ) {
                    Write-Verbose "No Bloom filter found, store may be empty"
                    
                    return $false
                }
                
                # Read binary file - handle PowerShell 5 compatibility
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $bloomData = [byte[]](
                        Get-Content `
                            -Path $store.BloomFile `
                            -AsByteStream
                    )
                }
                else {
                    $bloomData = [byte[]](
                        Get-Content `
                            -Path $store.BloomFile `
                            -Encoding Byte `
                            -ReadCount 0
                    )
                }
                
                # Try to load metadata
                $bloom = $null
                if (
                    Test-Path `
                        -Path "$($store.BloomFile).metadata"
                ) {
                    try {
                        $metadata = Import-Clixml `
                            -Path "$($store.BloomFile).metadata"
                        $bloom = [BloomFilter]::new(
                            $bloomData,
                            $metadata.size,
                            $metadata.hashCount
                        )
                    }
                    catch {
                        Write-Verbose "Failed to load Bloom metadata, using default initialization"
                    }
                }
                
                # Fallback if no metadata
                if (-not $bloom) {
                    $bloom = [BloomFilter]::new(
                        $bloomData,
                        $store.ItemCount
                    )
                }
                
                $store.Bloom = $bloom
                
                Write-Verbose "Loaded Bloom filter for store: $StoreName"
            }
            
            return $store.Bloom.Contains($Key)
        }
        catch {
            Write-Error "Failed to test key: $_"
        }
    }
}

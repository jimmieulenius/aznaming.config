<#
.SYNOPSIS
Retrieves an item from a Bloom Store by key.

.DESCRIPTION
Performs efficient key lookup using the store's cached Bloom filter and index.
Returns the parsed JSON object for the matching key.

.PARAMETER StoreName
The name of the registered Bloom Store

.PARAMETER Key
The key to look up

.PARAMETER Raw
If specified, returns the raw JSON string instead of parsed object

.EXAMPLE
# Get item from store
$item = Get-BloomItem -StoreName "resources" -Key "vm-eastus"

# Get raw JSON
$json = Get-BloomItem -StoreName "resources" -Key "vm-eastus" -Raw
#>
function Get-BloomItem {
    [CmdletBinding(DefaultParameterSetName = "Default")]
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
        $Key,
        
        [Parameter(ParameterSetName = "Raw")]
        [switch]
        $Raw,

        [Parameter(ParameterSetName = "Default")]
        [switch]
        $AsHashtable
    )
    
    process {
        try {
            # Validate store exists
            if (-not $script:BloomStores.ContainsKey($StoreName)) {
                Write-Error "Store '$StoreName' is not registered. Use Register-BloomStore first."

                return
            }
            
            $store = $script:BloomStores[$StoreName]
            
            # Load index and Bloom if not cached
            if (-not $store.Index) {
                if (-not (Test-Path $store.IndexFile)) {
                    Write-Verbose "No index found, store may be empty"
                    
                    return $null
                }
                
                # Read binary file - handle PowerShell 5 compatibility
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $bloomData = [byte[]](Get-Content -Path $store.BloomFile -AsByteStream)
                }
                else {
                    $bloomData = [byte[]](Get-Content -Path $store.BloomFile -Encoding Byte -ReadCount 0)
                }
                
                # Try to load metadata
                $bloom = $null
                if (Test-Path "$($store.BloomFile).metadata") {
                    try {
                        $metadata = Import-Clixml -Path "$($store.BloomFile).metadata"
                        $bloom = [BloomFilter]::new($bloomData, $metadata.size, $metadata.hashCount)
                    }
                    catch {
                        Write-Verbose "Failed to load Bloom metadata, using default initialization"
                    }
                }
                
                # Fallback if no metadata
                if (-not $bloom) {
                    $bloom = [BloomFilter]::new($bloomData, $store.ItemCount)
                }
                
                $store.Bloom = $bloom
                $store.Index = Import-Clixml -Path $store.IndexFile
                
                Write-Verbose "Loaded index for store: $StoreName"
            }
            
            $bloom = $store.Bloom
            $index = $store.Index
            
            # Step 1: Check Bloom filter
            if (-not $bloom.Contains($Key)) {
                Write-Verbose "Key '$Key' not found in Bloom filter"

                return $null
            }
            
            # Step 2: Check index
            if (-not $index.ContainsKey($Key)) {
                Write-Verbose "Key '$Key' is a Bloom filter false positive"

                return $null
            }
            
            # Step 3: Seek to file offset
            $offsetInfo = $index[$Key]
            $reader = [System.IO.StreamReader]::new($store.DataFile)

            try {
                $reader.BaseStream.Seek(
                    $offsetInfo.Offset,
                    [System.IO.SeekOrigin]::Begin
                ) `
                | Out-Null

                $line = $reader.ReadLine()
                
                if ($Raw) {
                    return $line
                }
                else {
                    return $line `
                    | ConvertFrom-Json `
                        -AsHashtable:$AsHashtable
                }
            }
            finally {
                $reader.Close()
            }
        }
        catch {
            Write-Error "Failed to retrieve item: $_"
        }
    }
}

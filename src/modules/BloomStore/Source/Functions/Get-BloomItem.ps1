<#
.SYNOPSIS
Retrieves items from a Bloom Store by key or returns all items.

.DESCRIPTION
When a key is specified, performs efficient key lookup using the store's cached Bloom filter and index.
When no key is specified, enumerates all items from the data file (full scan).

.PARAMETER StoreName
The name of the registered Bloom Store

.PARAMETER Key
The key to look up. If omitted, enumerates all items in the store.

.PARAMETER Raw
If specified, returns raw JSON strings instead of parsed objects

.PARAMETER Compress
When used with no -Key, compresses the store before enumeration to remove duplicates.
Has no effect when -Key is specified.

.PARAMETER AsHashtable
If specified, returns objects as hashtables instead of PSCustomObjects

.EXAMPLE
# Get item by key (fast indexed lookup)
$item = Get-BloomItem -StoreName "resources" -Key "vm-eastus"

# Get raw JSON by key
$json = Get-BloomItem -StoreName "resources" -Key "vm-eastus" -Raw

# Get all items (full file scan, includes duplicates)
$all = Get-BloomItem -StoreName "resources"

# Get all items after deduplicating
$clean = Get-BloomItem -StoreName "resources" -Compress

.NOTES
When enumerating without -Key:
- The data file may contain duplicates from updates
- Use -Compress to ensure you get only current values (runs Compress-BloomStoreIndex first)
- For most use cases, query by key using -Key instead (much faster)
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
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Key"
        )]
        [string]
        $Key,
        
        [Parameter(ParameterSetName = "Key")]
        [Parameter(ParameterSetName = "Default")]
        [switch]
        $Raw,

        [Parameter(ParameterSetName = "Default")]
        [switch]
        $Compress,

        # [Parameter(ParameterSetName = "AllItems")]
        # [switch]
        # $Raw,

        [Parameter(ParameterSetName = "Key")]
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
            
            # FAST PATH: Lookup by key
            if ($PSCmdlet.ParameterSetName -eq "Key") {
                # Load index and Bloom if not cached
                if (-not $store.Index) {
                    if (-not (Test-Path $store.IndexFile)) {
                        Write-Verbose "No index found, store may be empty"
                        
                        return $null
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

                    if (Test-Path "$($store.BloomFile).metadata") {
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
                    $store.Index = Import-Clixml `
                        -Path $store.IndexFile
                    
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
            # SLOW PATH: Enumerate all items
            else {
                if (-not (Test-Path $store.DataFile)) {
                    Write-Verbose "Data file not found: $($store.DataFile)"
                    
                    return
                }
                
                # Optionally compress first to remove duplicates
                if ($Compress) {
                    Write-Verbose "Compressing store before enumeration..."

                    Compress-BloomStoreIndex `
                        -StoreName $StoreName `
                        -ErrorAction 'Stop' `
                    | Out-Null
                }
                
                # Enumerate all lines from data file
                Get-Content `
                    -Path $store.DataFile `
                    -ErrorAction 'SilentlyContinue' `
                | ForEach-Object {
                    try {
                        if ($Raw) {
                            $_
                        }
                        else {
                            $_ `
                            | ConvertFrom-Json `
                                -AsHashtable:$AsHashtable
                        }
                    }
                    catch {
                        Write-Warning "Failed to parse line: $_"
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to retrieve item: $_"
        }
    }
}

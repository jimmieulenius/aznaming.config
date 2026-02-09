<#
.SYNOPSIS
Registers a new Bloom Store for efficient append-only key-value data storage.

.DESCRIPTION
Creates and registers a named Bloom Store that manages a JSONL data file with associated index and Bloom filter.
Stores are append-only by default. The index is rebuilt on-demand using Build-BloomStoreIndex.
The store is cached in memory for fast subsequent operations.
Default paths use the temp folder for automatic management.

.PARAMETER Name
The name of the store (used as identifier for all subsequent operations)

.PARAMETER DataFile
Path to the JSONL data file (one JSON object per line).
Default: $env:TEMP\BloomStore\<StoreName>.jsonl

.PARAMETER StoreDirectory
Directory where index and Bloom filter files will be stored.
Default: $env:TEMP\BloomStore

.PARAMETER Key
Specifies how to extract key(s) from items. Accepts:
- String: Property name to extract (e.g., "id", "resourceId")
- ScriptBlock: Custom key extraction logic using $_ (e.g., { "$($_.category)-$($_.name)" })
- Array of strings/ScriptBlocks: Multiple composite keys for flexible lookups
Default: "key" (extracts the 'key' property)

The scriptblock receives the item object as $_ (like ForEach-Object).

Examples:
  -Key "id"                                    # Single key by property name
  -Key { "$($_.category)-$($_.name)" }         # Single key by script with $_
  -Key "id", "name"                           # Multiple property keys
  -Key "id", { "$($_.cat)-$($_.type)" }       # Mix of properties and scripts

.PARAMETER AutoBuild
If specified, automatically rebuilds the index after each Set-BloomItem operation.
Default: $false (append-only, manual rebuild)

.PARAMETER Force
Overwrites existing store registration if it already exists.

.EXAMPLE
# Register with defaults (uses 'key' property)
Register-BloomStore -Name "resources"

.EXAMPLE
# Register with single custom key
Register-BloomStore -Name "resources" -Key "id"

.EXAMPLE
# Register with multiple keys for flexible lookups
Register-BloomStore -Name "resources" -Key "id", "name", { param($obj) "$($obj.category)-$($obj.region)" }

.EXAMPLE
# Register with automatic index rebuilds
Register-BloomStore -Name "resources" -Key "id" -AutoBuild
#>
function Register-BloomStore {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [string]
        $DataFile,
        
        # [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $StoreDirectory,
        
        [object[]]
        $Key = "key",
        
        [switch]
        $AutoBuild,
        
        [switch]
        $Force,

        [Switch]
        $PassThru
    )

    begin {
        # Initialize registry if not already done
        if (-not $script:BloomStores) {
            $script:BloomStores = @{}
        }
    }
    
    process {
        try {
            # Check if store already registered
            if (
                -not $Force `
                -and $script:BloomStores.ContainsKey($Name)
            ) {
                Write-Error "Store '$Name' is already registered. Use -Force to overwrite."
                
                return
            }
            
            # Set defaults
            if (-not $StoreDirectory) {
                $StoreDirectory = "$($env:TEMP)/BloomStore"
                # $StoreDirectory = Join-Path $env:TEMP "BloomStore"
            }
            
            if (-not $DataFile) {
                $DataFile = Join-Path $StoreDirectory "$Name.jsonl"
            }
            
            # Ensure directories exist
            if (-not (Test-Path $StoreDirectory)) {
                New-Item `
                    -Path $StoreDirectory `
                    -ItemType 'Directory' `
                    -Force `
                | Out-Null
            }
            
            # Ensure data file exists (empty if new)
            if (-not (Test-Path $DataFile)) {
                New-Item `
                    -Path $DataFile `
                    -ItemType 'File' `
                    -Force `
                | Out-Null
            }
            
            # Resolve key extractors from mixed array
            $resolvedKeyExtractors = @()

            foreach ($keyItem in $Key) {
                if ($keyItem -is [scriptblock]) {
                    # Already a scriptblock
                    $resolvedKeyExtractors += $keyItem
                }
                elseif ($keyItem -is [string]) {
                    # Convert property name to scriptblock
                    $propertyName = $keyItem
                    # $resolvedKeyExtractors += [scriptblock]::Create("param(`$obj) `$obj.$propertyName")
                    $resolvedKeyExtractors += [scriptblock]::Create("`$_.$propertyName")
                }
                else {
                    Write-Error "Key must be string (property name) or ScriptBlock (extractor), got: $($keyItem.GetType().Name)"

                    return
                }
            }
            
            # Register the store
            $script:BloomStores[$Name] = @{
                Name = $Name
                DataFile = $DataFile
                StoreDirectory = $StoreDirectory
                IndexFile = Join-Path $StoreDirectory "$Name.index.clixml"
                BloomFile = Join-Path $StoreDirectory "$Name.bloom.bin"
                KeyExtractors = $resolvedKeyExtractors
                Bloom = $null
                Index = $null
                LastRebuild = $null
                AutoBuild = $AutoBuild
                ItemCount = 0
            }
            
            # Create empty Bloom filter file if it doesn't exist
            if (
                -not (
                    Test-Path `
                        -Path (
                            Join-Path $StoreDirectory "$Name.bloom.bin"
                        )
                )
            ) {
                $emptyBloom = [BloomFilter]::new(100, 0.01)

                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $emptyBloom.bitArray `
                    | Set-Content `
                        -Path (Join-Path $StoreDirectory "$Name.bloom.bin") `
                        -AsByteStream
                }
                else {
                    [byte[]]$emptyBloom.bitArray `
                    | Set-Content `
                        -Path (Join-Path $StoreDirectory "$Name.bloom.bin") `
                        -Encoding Byte `
                        -ReadCount 0
                }
            }
            
            # Create empty index file if it doesn't exist
            if (
                -not (
                    Test-Path `
                        -Path (
                            Join-Path $StoreDirectory "$Name.index.clixml"
                        )
                )
            ) {
                @{} `
                | Export-Clixml `
                    -Path (Join-Path $StoreDirectory "$Name.index.clixml")
            }
            
            Write-Verbose "Registered store: $Name (Keys: $($resolvedKeyExtractors.Count), AutoBuild: $AutoBuild)"
            
            if ($PassThru) {
                # Return store info
                [PSCustomObject]@{
                    Name = $Name
                    DataFile = $DataFile
                    StoreDirectory = $StoreDirectory
                    KeyCount = $resolvedKeyExtractors.Count
                    AutoBuild = $AutoBuild
                    Registered = $true
                }
            }
        }
        catch {
            Write-Error "Failed to register store: $_"
        }
    }
}

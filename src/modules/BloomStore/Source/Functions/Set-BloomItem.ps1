<#
.SYNOPSIS
Appends items to a Bloom Store's data file.

.DESCRIPTION
Appends one or more JSON objects to the store's data file in JSONL format (one object per line).
The store is append-only by default. Use -Build to rebuild the index after appending, or use the
AutoBuild setting at store registration time.

.PARAMETER StoreName
The name of the registered Bloom Store

.PARAMETER InputObject
The object(s) to append (will be converted to JSON).
Accepts arrays for batch operations.

.PARAMETER Value
Alias for InputObject (for consistency with other cmdlets)

.PARAMETER Build
If specified, rebuilds the index and Bloom filter after appending items.
Otherwise, just appends to file and updates item count.

.EXAMPLE
# Append single item
$resource = @{ key = "vm-eastus"; type = "virtualMachine"; location = "eastus" }
Set-BloomItem -StoreName "resources" -InputObject $resource

# Append multiple items (batch)
$resources | Set-BloomItem -StoreName "resources"

# Append and rebuild index
$resources | Set-BloomItem -StoreName "resources" -Build

# Pipeline usage
$items | Set-BloomItem -StoreName "resources" -Build
#>
function Set-BloomItem {
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
            ValueFromPipeline = $true
        )]
        [object[]]
        $InputObject,
        
        [Alias('Value')]
        [object[]]
        $InputObjectAlias,
        
        [switch]
        $Build,

        [switch]
        $PassThru
    )
    
    begin {
        # Validate store exists
        if (-not $script:BloomStores.ContainsKey($StoreName)) {
            Write-Error "Store '$StoreName' is not registered. Use Register-BloomStore first."
            
            return
        }
        
        $store = $script:BloomStores[$StoreName]
        $itemsAppended = 0
    }
    
    process {
        try {
            # Append each item to the file
            foreach ($item in $InputObject) {
                # Convert to JSON
                $jsonLine = if ($item -is [string]) {
                    $item
                }
                else {
                    $item `
                    | ConvertTo-Json `
                        -Compress
                }
                
                # Append to data file
                Add-Content `
                    -Path $store.DataFile `
                    -Value $jsonLine `
                    -ErrorAction 'Stop'

                $itemsAppended++
            }
        }
        catch {
            Write-Error "Failed to append items: $_"
        }
    }
    
    end {
        $store.ItemCount += $itemsAppended

        Write-Verbose "Appended $itemsAppended items to store: $StoreName"
        
        # Rebuild index if requested or if AutoBuild is enabled
        if (
            $Build `
            -or $store.AutoBuild
        ) {
            Write-Verbose "Rebuilding index..."

            $bloomSize = Invoke-BloomStoreIndexBuild `
                -StoreName $StoreName
            
            if ($PassThru) {
                [PSCustomObject]@{
                    StoreName = $StoreName
                    ItemsAppended = $itemsAppended
                    IndexRebuilt = $true
                    BloomSize = $bloomSize
                }
            }
        }
        else {
            if ($PassThru) {
                [PSCustomObject]@{
                    StoreName = $StoreName
                    ItemsAppended = $itemsAppended
                    IndexRebuilt = $false
                    TotalItems = $store.ItemCount
                }
            }
        }
    }
}


<#
.SYNOPSIS
Compresses a Bloom Store by removing duplicate entries.

.DESCRIPTION
Scans the entire data file and rewrites it, keeping only the last occurrence of each key.
This reclaims space from duplicate/updated entries and rebuilds the index.
The original data file is backed up before compression.

.PARAMETER StoreName
The name of the registered Bloom Store

.PARAMETER KeepBackup
If specified, keeps the backup of the original file.
Default: Removes the backup after successful compression

.EXAMPLE
# Compress store after many updates
Compress-BloomStoreIndex -StoreName "resources"

# Compress and keep backup for safety
Compress-BloomStoreIndex -StoreName "resources" -KeepBackup

.NOTES
This operation:
1. Reads the entire data file
2. Keeps only the last occurrence of each key
3. Writes deduplicated data to a temporary file
4. Backs up the original file
5. Replaces original with compressed version
6. Rebuilds the index and Bloom filter

The store must be registered but does not need to be cached.
#>
function Compress-BloomStoreIndex {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoreName,
        
        [switch]
        $KeepBackup
    )
    
    process {
        try {
            # Validate store exists
            if (-not $script:BloomStores.ContainsKey($StoreName)) {
                Write-Error "Store '$StoreName' is not registered. Use Register-BloomStore first."
                
                return
            }
            
            $store = $script:BloomStores[$StoreName]
            
            if (
                -not (
                    Test-Path `
                        -Path $store.DataFile
                )
            ) {
                Write-Warning "Data file not found: $($store.DataFile)"

                return
            }
            
            Write-Verbose "Compacting store: $StoreName"
            
            # Count current items
            $originalItemCount = @(
                Get-Content `
                    -Path $store.DataFile `
                    -ErrorAction 'SilentlyContinue'
            ).Count
            
            if ($null -eq $originalItemCount) {
                $originalItemCount = 0
            }
            
            if ($originalItemCount -eq 0) {
                Write-Verbose "Store is empty, nothing to compact"

                return
            }
            
            if ($PSCmdlet.ShouldProcess($StoreName, "Compress BloomStore")) {
                # Phase 1: Read file and keep last occurrence of each key
                Write-Verbose "  Phase 1: Scanning for duplicates..."

                $keyMap = @{}
                $offset = 0
                
                Get-Content `
                    -Path $store.DataFile `
                | ForEach-Object {
                    try {
                        $obj = $_ `
                        | ConvertFrom-Json `
                            -ErrorAction 'Stop'
                        
                        # Extract all keys using each extractor (native ForEach-Object for $_ support)
                        foreach ($extractor in $store.KeyExtractors) {
                            $key = $obj `
                            | ForEach-Object `
                                -Process $extractor
                            
                            if (-not [string]::IsNullOrEmpty($key)) {
                                $key = [string]$key
                                # Store full line and offset - will keep last occurrence
                                $keyMap[$key] = @{
                                    Line   = $_
                                    Offset = $offset
                                }
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to parse line: $_"
                    }
                    
                    $offset += $_.Length + [System.Environment]::NewLine.Length
                }
                
                # Phase 2: Write deduplicated data to temp file
                Write-Verbose "  Phase 2: Writing deduplicated data..."

                $tempFile = "$($store.DataFile).tmp"
                
                $keyMap.Values `
                | ForEach-Object { $_.Line } `
                | Set-Content `
                    -Path $tempFile
                
                # Phase 3: Backup original
                Write-Verbose "  Phase 3: Backing up original..."

                $backupFile = "$($store.DataFile).backup"
                
                Copy-Item `
                    -Path $store.DataFile `
                    -Destination $backupFile `
                    -Force
                
                # Phase 4: Replace original with compacted
                Write-Verbose "  Phase 4: Replacing original file..."

                Move-Item `
                    -Path $tempFile `
                    -Destination $store.DataFile `
                    -Force
                
                # Phase 5: Rebuild index
                Write-Verbose "  Phase 5: Rebuilding index..."
                $bloomSize = Invoke-BloomStoreIndexBuild `
                    -StoreName $StoreName
                
                # Cleanup backup if not requested
                if (-not $KeepBackup) {
                    Remove-Item `
                        -Path $backupFile `
                        -Force

                    Write-Verbose "  Removed backup file"
                }
                
                $newItemCount = $keyMap.Count
                $duplicatesRemoved = $originalItemCount - $newItemCount
                
                Write-Verbose "Compression complete"
                
                [PSCustomObject]@{
                    StoreName = $StoreName
                    OriginalItemCount = $originalItemCount
                    CompactedItemCount = $newItemCount
                    DuplicatesRemoved = $duplicatesRemoved
                    BloomSizeKB = [Math]::Round($bloomSize / 1KB, 2)
                    # BackupFile = if ($KeepBackup) { $backupFile } else { $null }
                    BackupFile = $KeepBackup `
                        ? $backupFile `
                        : $null
                }
            }
        }
        catch {
            Write-Error "Failed to compress store: $_"
        }
    }
}
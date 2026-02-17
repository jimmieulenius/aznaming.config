<#
.SYNOPSIS
Unregisters a Bloom Store and removes it from memory cache.

.DESCRIPTION
Removes a registered Bloom Store from the module's internal registry.
By default, deletes the data file, index, and Bloom filter files to prevent stale data.

.PARAMETER Name
The name of the store to unregister

.PARAMETER KeepFiles
If specified, keeps all files (data file, index, and Bloom filter) instead of deleting them.

.EXAMPLE
# Unregister store (removes data, index, and Bloom files)
Unregister-BloomStore -Name "resources"

.EXAMPLE
# Unregister but keep all files
Unregister-BloomStore -Name "resources" -KeepFiles
#>
function Unregister-BloomStore {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [switch]
        $KeepFiles
    )
    
    process {
        try {
            if (-not $script:BloomStores.ContainsKey($Name)) {
                Write-Warning "Store '$Name' is not registered"

                return
            }
            
            $store = $script:BloomStores[$Name]
            
            if ($PSCmdlet.ShouldProcess($Name, "Unregister BloomStore")) {
                # Remove from registry
                $script:BloomStores.Remove($Name)
                
                # Remove files by default unless KeepFiles is specified
                if (-not $KeepFiles) {
                    if (
                        Test-Path `
                            -Path $store.DataFile
                    ) {
                        Remove-Item `
                            -Path $store.DataFile `
                            -Force

                        Write-Verbose "Removed data file: $($store.DataFile)"
                    }
                    if (
                        Test-Path `
                            -Path $store.IndexFile
                    ) {
                        Remove-Item `
                            -Path $store.IndexFile `
                            -Force

                        Write-Verbose "Removed index file: $($store.IndexFile)"
                    }
                    if (
                        Test-Path `
                            -Path $store.BloomFile
                    ) {
                        Remove-Item `
                            -Path $store.BloomFile `
                            -Force

                        Write-Verbose "Removed Bloom file: $($store.BloomFile)"
                    }
                }
                
                Write-Verbose "Unregistered store: $Name"
                
                [PSCustomObject]@{
                    Name = $Name
                    Unregistered = $true
                    FilesRemoved = -not $KeepFiles
                }
            }
        }
        catch {
            Write-Error "Failed to unregister store: $_"
        }
    }
}

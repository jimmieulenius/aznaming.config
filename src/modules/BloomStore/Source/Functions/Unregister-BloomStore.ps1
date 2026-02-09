<#
.SYNOPSIS
Unregisters a Bloom Store and removes it from memory cache.

.DESCRIPTION
Removes a registered Bloom Store from the module's internal registry.
Does not delete the data, index, or Bloom filter files by default.

.PARAMETER Name
The name of the store to unregister

.PARAMETER RemoveFiles
If specified, also deletes the index and Bloom filter files.
Data file is never deleted to prevent accidental data loss.

.EXAMPLE
# Unregister store (keeps files)
Unregister-BloomStore -Name "resources"

.EXAMPLE
# Unregister and clean up index/Bloom files
Unregister-BloomStore -Name "resources" -RemoveFiles
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
        $RemoveFiles
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
                
                # Optionally remove files
                if ($RemoveFiles) {
                    if (
                        Test-Path `
                            -Path $store.IndexFile
                    ) {
                        Remove-Item `
                            -Path $store.IndexFile -Force

                        Write-Verbose "Removed index file: $($store.IndexFile)"
                    }
                    if (
                        Test-Path `
                            -Path $store.BloomFile
                    ) {
                        Remove-Item `
                            -Path $store.BloomFile -Force

                        Write-Verbose "Removed Bloom file: $($store.BloomFile)"
                    }
                }
                
                Write-Verbose "Unregistered store: $Name"
                
                [PSCustomObject]@{
                    Name = $Name
                    Unregistered = $true
                    FilesRemoved = $RemoveFiles
                }
            }
        }
        catch {
            Write-Error "Failed to unregister store: $_"
        }
    }
}

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'BloomStore.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @(
        'Core',
        'Desktop'
    )

    # ID used to uniquely identify this module
    GUID = '6f2a1e9d-8c5b-4a7f-9e2c-1d3a5b7c9f1e'

    # Author of this module
    Author = 'Jimmie Ulenius'

    # Company or vendor of this module
    CompanyName = 'Jimmie Ulenius'

    # Copyright statement for this module
    Copyright = '(c) 2026 Jimmie Ulenius. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'High-performance key-value data storage using Bloom filters and indexed binary files. Enables efficient large dataset lookups without database overhead.'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        'PSModule'
    )

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'Source/Classes/BloomFilter.ps1',
        'Source/Functions/Invoke-BloomStoreIndexBuild.ps1',
        'Source/Functions/Register-BloomStore.ps1',
        'Source/Functions/Unregister-BloomStore.ps1',
        'Source/Functions/Set-BloomItem.ps1',
        'Source/Functions/Get-BloomItem.ps1',
        'Source/Functions/Test-BloomKey.ps1',
        'Source/Functions/Build-BloomStoreIndex.ps1',
        'Source/Functions/Compress-BloomStoreIndex.ps1'
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Register-BloomStore'
        'Unregister-BloomStore'
        'Set-BloomItem'
        'Get-BloomItem'
        'Test-BloomKey'
        'Build-BloomStoreIndex'
        'Compress-BloomStoreIndex'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Data', 'Store', 'BloomFilter', 'HighPerformance', 'Index')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = ''
            ReleaseNotes = 'Initial release - Bloom filter-based data store for efficient key-value lookups'
        }
    }

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Minimum version of the .NET Framework required by this module
    DotNetFrameworkVersion = '4.5'

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()
}

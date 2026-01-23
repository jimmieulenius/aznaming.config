enum MergeStatus {
    Skipped
    Merged
    Created
}

function Merge-Object {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject,

        [Object]
        $Source,

        [String]
        $Path,

        [Switch]
        $PassThru
    )

    $status = [MergeStatus]::Skipped

    if (
        -not ($Source ?? @{}).Keys.Count `
        -and -not ($Source.PSObject.Properties)
    ) {
        return $InputObject
    }

    $currentObj = $InputObject

    if ($Path) {
        $pathSegments = $Path `
        | Get-PathSegment

        foreach ($segment in $pathSegments[0..($pathSegments.Count - 1)]) {
            $value = $currentObj.$segment

            if (
                -not ($value) `
                -or -not (
                    $value `
                    | Get-IsObject
                )
            ) {
                $value = [Ordered]@{}

                # Create empty object at this path
                $currentObj `
                | Set-ObjectProperty `
                    -Key $segment `
                    -Value $value

                $status = [MergeStatus]::Created
            }

            $currentObj = $value
        }
    }

    $targetKey = $currentObj `
    | Get-ObjectPropertyName

    foreach ($keyItem in (
        $Source `
        | Get-ObjectPropertyName
    )) {
        $shouldProceed = $true
        $sourceValue = $Source.$keyItem

        if ($targetKey -icontains $keyItem) {
            $targetValue = $currentObj.$keyItem

            if (
                (
                    $targetValue `
                    | Get-IsObject
                ) `
                -and (
                    $sourceValue `
                    | Get-IsObject
                )
            ) {
                $currentObj
                | Set-ObjectProperty `
                    -Key $keyItem `
                    -Value (
                        $targetValue `
                        | Merge-Object `
                            -Source $sourceValue `
                            -PassThru
                    )

                $shouldProceed = $false

                if ($status -lt [MergeStatus]::Created) {
                    $status = [MergeStatus]::Merged
                }
            }
        }

        if ($shouldProceed) {
            $currentObj `
            | Set-ObjectProperty `
                -Key $keyItem `
                -Value $Source.$keyItem
        }
    }

    if ($PassThru) {
        return $InputObject
    }

    return $status
}

function Get-PathSegment {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [String]
        $InputObject
    )

    $path = $InputObject
    $result = @()

    while ($path) {
        $path = $path -replace '^\s*\.+\s*'  # trim leading dots
        
        if ($match = [Regex]::Match($path, "\['[^']+'\]|[^.\[\]]+")) {
            $segment = $match.Value
            # Remove brackets and quotes
            $segment = $segment -replace "^\['|'\]$", ""
            $result += $segment
            
            # Remove the matched part and trim
            $path = $path.Substring($match.Index + $match.Length)
        }
        else {
            break
        }
    }

    if ($result.Count -eq 1) {
        return ,$result
    }

    return $result
}

# function Get-ObjectPropertyName {
#     param (
#         [Parameter(
#             Mandatory = $true,
#             ValueFromPipeline = $true
#         )]
#         [Object]
#         $InputObject
#     )

#     if (
#         $InputObject -is [Hashtable] `
#         -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
#     ) {
#         return $InputObject.Keys
#     }

#     return $InputObject.PSObject.Properties.Name
# }

function Set-ObjectProperty {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object]
        $InputObject,

        [Parameter(
            Mandatory = $true
        )]
        [String]
        $Key,

        [Object]
        $Value,

        [Switch]
        $PassThru
    )

    if (
        $InputObject -is [Hashtable] `
        -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
    ) {
        $InputObject[$Key] = $Value
    }
    else {
        $InputObject `
        | Add-Member `
            -MemberType 'NoteProperty' `
            -Name $Key `
            -Value $Value `
            -Force
    }

    if ($PassThru) {
        return $InputObject
    }
}

# function Get-IsObject {
#     param (
#         [Parameter(
#             Mandatory = $true,
#             ValueFromPipeline = $true
#         )]
#         [Object]
#         $InputObject
#     )

#     return $InputObject -is [Hashtable] `
#         -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
#         -or $InputObject.PSObject.TypeNames -icontains 'System.Management.Automation.PSCustomObject'
# }

# function Remove-ObjectPropertyByPath {
#     param (
#         [Parameter(
#             Mandatory = $true,
#             ValueFromPipeline = $true
#         )]
#         [Object]
#         $InputObject,

#         [String]
#         $Path,

#         [Switch]
#         $PassThru
#     )

#     $currentObj = $InputObject
#     $result = $false

#     if ($Path) {
#         $pathSegments = $Path `
#         | Get-PathSegment

#         for ($segmentIndex = 0; $segmentIndex -lt $pathSegments.Count; $segmentIndex++) {
#             $segment = $pathSegments[$segmentIndex]

#             $targetKey = $currentObj `
#             | Get-ObjectPropertyName
            
#             if ($targetKey -icontains $segment) {
#                 if (
#                     $segmentIndex -eq $pathSegments.Count - 1 `
#                     -and (
#                         $currentObj `
#                         | Get-IsObject
#                     )
#                 ) {
#                     $result = $currentObj `
#                     | Remove-ObjectProperty `
#                         -Key $segment

#                     break
#                 }
#                 else {
#                     $currentObj = $currentObj.$segment
#                 }
#             }
#             else {
#                 break  # Path doesn't exist
#             }
#         }
#     }

#     if ($PassThru) {
#         return $InputObject
#     }

#     return $result
# }

# function Remove-ObjectProperty {
#     param (
#         [Parameter(
#             Mandatory = $true,
#             ValueFromPipeline = $true
#         )]
#         [Object]
#         $InputObject,

#         [Parameter(
#             Mandatory = $true
#         )]
#         [String]
#         $Key,

#         [Switch]
#         $PassThru
#     )

#     if (
#         $InputObject -is [Hashtable] `
#         -or $InputObject -is [System.Collections.Specialized.IOrderedDictionary] `
#     ) {
#         $result = $InputObject.ContainsKey($Key)
#         $InputObject.Remove($Key)
#     }
#     else {
#         $result = $InputObject.PSObject.Properties.Name -contains $Key

#         if ($result) {
#             $InputObject.PSObject.Properties.Remove($Key)
#         }
#     }

#     if ($PassThru) {
#         return $InputObject
#     }

#     return $result
# }
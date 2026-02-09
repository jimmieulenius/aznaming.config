function Get-PathSegment {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]
        $InputObject
    )

    $path = $InputObject
    $segments = @()

    # Parse all segments first
    while ($path) {
        $path = $path -replace '^\s*\.+\s*'  # trim leading dots
        
        # Match property with brackets (quoted or unquoted), array index, or unbracketed property
        if ($match = [Regex]::Match($path, "\['[^']+'\]|\[[^\[\]]+\]|\[\d+\]|[^.\[\]]+")) {
            $segment = $match.Value
            $segmentIdentifierType = "Property"
            $segmentIdentifier = $segment

            # Handle bracketed property with quotes
            if ($segment -match "^\['(.+)'\]$") {
                $segmentIdentifier = $matches[1]
                $segmentIdentifierType = "Property"
            }
            # Handle array index
            elseif ($segment -match "^\[(\d+)\]$") {
                $segmentIdentifier = [int]$matches[1]
                $segmentIdentifierType = "Index"
            }
            # Handle bracketed property without quotes
            elseif ($segment -match "^\[([^\[\]]+)\]$") {
                $segmentIdentifier = $matches[1]
                $segmentIdentifierType = "Property"
            }
            # Handle unbracketed property
            else {
                $segmentIdentifier = $segment
                $segmentIdentifierType = "Property"
            }

            $segments += @{
                Identifier = $segmentIdentifier
                IdentifierType = $segmentIdentifierType
            }
            
            # Remove the matched part and trim
            $path = $path.Substring($match.Index + $match.Length)
        }
        else {
            break
        }
    }

    $result = @()

    for ($i = 0; $i -lt $segments.Count; $i++) {
        $segmentsItem = $segments[$i]
        
        # Check if there's a next segment
        if ($i + 1 -lt $segments.Count) {
            $nextSegment = $segments[$i + 1]

            if ($nextSegment.IdentifierType -eq "Index") {
                $segmentsItem['ContainerType'] = "Array"
            }
            else {
                $segmentsItem['ContainerType'] = "Object"
            }
        }

        $result += [PSCustomObject](
            @{
                PSTypeName = 'DataStructure.PathSegment'
                Identifier = $segmentsItem.Identifier
                IdentifierType = $segmentsItem.IdentifierType
            } + (
                $segmentsItem.ContainerType `
                    ? @{
                        ContainerType = $segmentsItem.ContainerType
                    } `
                    : @{}
            )
        )
    }

    if ($result.Count -eq 1) {
        return ,$result
    }

    return $result
}
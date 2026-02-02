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
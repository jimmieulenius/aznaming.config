function Invoke-DictionaryItem {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Path'
        )]
        [string]
        $Path,

        [Parameter(ParameterSetName = 'Path')]
        [Switch]
        $Traverse,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'Path')]
        [Switch]
        $Recurse
    )

    function Get-IsContainer {
        param (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [object]
            $InputObject
        )

        return (
            (
                $InputObject `
                | Get-IsDictionary
            ) -or (
                $InputObject `
                | Get-IsArray
            )
        )
    }

    function Invoke-ContainerItem {
        param (
            [Parameter(
                ValueFromPipeline = $true
            )]
            [object]
            $InputObject,

            [Parameter(Mandatory = $true)]
            [ScriptBlock]
            $ScriptBlock,

            [Switch]
            $Recurse
        )

        if (
            Get-IsDictionary `
                -InputObject $InputObject
        ) {
            $InputObject `
            | Get-DictionaryKey `
            | ForEach-Object {
                $value = $InputObject.$_

                $pathSegmentStack.Push(
                    (
                        "['$_']" `
                        | Get-PathSegment
                    )
                )

                Invoke-Item `
                    -Value $value

                if (
                    $Recurse `
                    -and (
                        $value `
                        | Get-IsContainer
                    )
                ) {
                    Invoke-ContainerItem `
                        -InputObject $value `
                        -ScriptBlock $ScriptBlock `
                        -Recurse:$Recurse
                }

                $pathSegmentStack.Pop() `
                | Out-Null
            }
        }
        elseif (
            Get-IsArray `
                -InputObject $InputObject
        ) {
            $arrayIndex = 0

            $InputObject `
            | ForEach-Object {
                $value = $_

                $pathSegmentStack.Push(
                    (
                        "[$arrayIndex]" `
                        | Get-PathSegment
                    )
                )

                Invoke-Item `
                    -Value $value

                if (
                    $Recurse `
                    -and (
                        $value `
                        | Get-IsContainer
                    )
                ) {
                    Invoke-ContainerItem `
                        -InputObject $value `
                        -ScriptBlock $ScriptBlock `
                        -Recurse:$Recurse
                }

                $pathSegmentStack.Pop() `
                | Out-Null

                $arrayIndex++
            }
        }
    }

    function Invoke-Item {
        param (
            [object]
            $Value
        )

        $currentPath = $null
        $pathSegments = $pathSegmentStack.ToArray()
        $lastPathSegmentItem = $null

        for ($index = $pathSegments.Count - 1; $index -ge 0; $index--) {
            $pathSegmentsItem = $pathSegments[$index]
            $currentPath = $currentPath `
            | Add-PathSegment `
                -PathSegment $pathSegmentsItem

            if (-not $lastPathSegmentItem) {
                $lastPathSegmentItem = $pathSegmentsItem
            }
        }

        $item = @{
            Identifier = $lastPathSegmentItem.Identifier
            IdentifierType = $lastPathSegmentItem.IdentifierType
            Path = $currentPath
            Value = $Value
        }
        
        $item `
        | ForEach-Object `
            -Process $ScriptBlock
    }

    if (
        -not (
            $InputObject `
            | Get-IsDictionary
        )
    ) {
        Write-Error `
            -Message 'InputObject must be a dictionary.'
    }

    $pathSegmentStack = [System.Collections.Stack]::new()

    if ($Path) {
        $currentValue = $InputObject
        $pathSegments = $Path `
        | Get-PathSegment

        for ($index = 0; $index -lt $pathSegments.Count; $index++) {
            $pathSegmentsItem = $pathSegments[$index]
            $value = $currentValue[$pathSegmentsItem.Identifier]
            $isLastItem = $index -eq $pathSegments.Count - 1

            if (-not $value) {
                Write-Error `
                    -Message "Path '$CurrentPath' in dictionary does not exist."

                return
            }

            $pathSegmentStack.Push(
                $pathSegmentsItem
            )

            if (
                $Traverse `
                -or $isLastItem
            ) {
                Invoke-Item `
                    -Value $value

                if ($isLastItem) {
                    if (
                        $Recurse `
                        -and (
                            $value `
                            | Get-IsContainer
                        )
                    ) {
                        Invoke-ContainerItem `
                            -InputObject $value `
                            -ScriptBlock $ScriptBlock `
                            -Recurse:$Recurse
                    }
                }
            }

            $currentValue = $value
        }
    }
    else {
        Invoke-ContainerItem `
            -InputObject $InputObject `
            -ScriptBlock $ScriptBlock `
            -Recurse:$Recurse
    }
}
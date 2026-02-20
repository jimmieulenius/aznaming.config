function Write-JsonItem {
    <#
    .SYNOPSIS
    Recursively writes any PowerShell object to a JSON writer with proper indentation.

    .DESCRIPTION
    Handles hashtables, objects, arrays, and primitive types, writing them correctly
    to maintain JSON structure and indentation level. Supports multiple writer implementations
    via parameter sets.

    .PARAMETER Utf8JsonWriter
    The System.Text.Json.Utf8JsonWriter instance to write to.

    .PARAMETER Value
    The object to serialize and write.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Utf8JsonWriter')]
    param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Utf8JsonWriter'
        )]
        [System.Text.Json.Utf8JsonWriter]
        $Utf8JsonWriter,

        [string]
        $Key = $null,

        [object]
        $Value = $null
    )

    switch ($PSCmdlet.ParameterSetName) {
        ('Utf8JsonWriter') {
            $Writer = $Utf8JsonWriter

            if ($Key) {
                $Writer.WritePropertyName($Key)
            }

            if ($null -eq $Value) {
                $Writer.WriteNullValue()
            }
            elseif ($Value -is [bool]) {
                $Writer.WriteBooleanValue($Value)
            }
            elseif (
                $Value -is [int] `
                -or $Value -is [long] `
                -or $Value -is [double]
            ) {
                $Writer.WriteNumberValue([double]$Value)
            }
            elseif ($Value -is [string]) {
                $Writer.WriteStringValue($Value)
            }
            elseif ($Value -is [array]) {
                $Writer.WriteStartArray()

                foreach ($item in $Value) {
                    Write-JsonItem `
                        -Utf8JsonWriter $Writer `
                        -Value $item
                }

                $Writer.WriteEndArray()
            }
            elseif (
                Get-IsDictionary `
                    -InputObject $Value
            ) {
                $Writer.WriteStartObject()
                
                $items = $Value `
                | Get-DictionaryItem

                foreach ($item in $items) {
                    $Writer.WritePropertyName($item.Identifier)

                    Write-JsonItem `
                        -Utf8JsonWriter $Writer `
                        -Value $item.Value
                }

                $Writer.WriteEndObject()
            }
            else {
                # Fallback for other types - serialize via ConvertTo-Json
                $Writer.WriteRawValue(
                    (
                        $Value `
                        | ConvertTo-Json `
                            -Depth 100 `
                            -Compress
                    )
                )
            }
        }
    }
}
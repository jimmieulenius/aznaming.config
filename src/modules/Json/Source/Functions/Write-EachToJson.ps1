function Write-EachToJson {
    <#
    .SYNOPSIS
    Writes piped items to a JSON file using a specified JSON writer implementation.

    .DESCRIPTION
    Provides a flexible pipeline-based JSON writer with Begin/Process/End scriptblock support,
    similar to ForEach-Object. The context object ($_ in scriptblocks) contains:
    - Item: Current item from pipeline
    - Writer: JSON writer instance (type depends on parameter set)

    Items are processed in the order they arrive from the pipeline.
    Use Sort-Object before piping if ordering is needed.

    .PARAMETER Path
    Output file path for the JSON file

    .PARAMETER Utf8JsonWriter
    Use System.Text.Json.Utf8JsonWriter implementation (default).

    .PARAMETER Indented
    If specified, formats JSON with indentation for readability. Only valid with -Utf8JsonWriter.

    .PARAMETER Encoder
    JavaScriptEncoder instance for escaping. Only valid with -Utf8JsonWriter.
    Default: UnsafeRelaxedJsonEscaping (outputs < and > literally).

    .PARAMETER Begin
    Scriptblock executed before processing items. Default varies by writer implementation.

    .PARAMETER Process
    Scriptblock executed for each item. Default varies by writer implementation.

    .PARAMETER End
    Scriptblock executed after all items. Default varies by writer implementation.

    .EXAMPLE
    @('item1', 'item2', 'item3') `
    | Sort-Object `
    | Write-EachToJson `
        -Path "output.json" `
        -Utf8JsonWriter `
        -Indented

    .EXAMPLE
    @(1, 2, 3) `
    | Sort-Object `
    | Write-EachToJson `
        -Path "object.json" `
        -Utf8JsonWriter `
        -Indented `
        -Encoder ([System.Text.Encodings.Web.JavaScriptEncoder]::Create([System.Text.Unicode.UnicodeRanges]::All)) `
        -Begin {
            $_.Writer.WriteStartObject()
            $_.Writer.WritePropertyName("values")
            $_.Writer.WriteStartArray()
        } `
        -Process {
            $_.Writer.WriteNumberValue($_.Item)
        } `
        -End {
            $_.Writer.WriteEndArray()
            $_.Writer.WriteEndObject()
        }
    #>
    [CmdletBinding(DefaultParameterSetName = 'Utf8JsonWriter')]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [object[]]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(ParameterSetName = 'Utf8JsonWriter')]
        [switch]
        $Utf8JsonWriter,

        [Parameter(ParameterSetName = 'Utf8JsonWriter')]
        [switch]
        $Indented,

        [Parameter(ParameterSetName = 'Utf8JsonWriter')]
        [System.Text.Encodings.Web.JavaScriptEncoder]
        $Encoder,

        [scriptblock]
        $Begin,

        [scriptblock]
        $Process,

        [scriptblock]
        $End
    )

    begin {
        $writerType = $PSCmdlet.ParameterSetName

        # Evaluate defaults based on writer type at runtime
        if (-not $Begin) {
            $Begin = switch ($writerType) {
                ('Utf8JsonWriter') {
                    { $_.Writer.WriteStartArray() }
                }
            }
        }

        if (-not $Process) {
            $Process = switch ($writerType) {
                ('Utf8JsonWriter') {
                    {
                        $itemJson = $_.Item `
                        | ConvertTo-Json `
                            -Depth 100 `
                            -Compress

                        $_.Writer.WriteRawValue($itemJson)
                    }
                }
            }
        }

        if (-not $End) {
            $End = switch ($writerType) {
                ('Utf8JsonWriter') {
                    {
                        $_.Writer.WriteEndArray()
                    }
                }
            }
        }

        # Create writer based on parameter set
        switch ($writerType) {
            ('Utf8JsonWriter') {
                $options = [System.Text.Json.JsonWriterOptions]::new()
                $options.Indented = $Indented
                $options.Encoder = $Encoder ?? [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping

                $fileStream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Create)
                $writer = [System.Text.Json.Utf8JsonWriter]::new($fileStream, $options)
            }
        }

        $context = [PSCustomObject]@{
            Item   = $null
            Writer = $writer
        }

        $context `
        | ForEach-Object `
            -Process $Begin
    }

    process {
        $context.Item = $_

        $context `
        | ForEach-Object `
            -Process $Process
    }

    end {
        try {
            $context.Item = $null

            $context `
            | ForEach-Object `
                -Process $End
        }
        finally {
            $writer.Dispose()
            $fileStream.Dispose()
        }
    }
}
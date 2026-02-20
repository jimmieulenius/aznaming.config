function Write-EachToJson {
    <#
    .SYNOPSIS
    Writes piped items to JSON file(s) using custom writer factories for flexible output handling.

    .DESCRIPTION
    Provides a flexible pipeline-based JSON writer with Begin/Process/End scriptblock support,
    similar to ForEach-Object. Items are processed in pipeline order. Use Sort-Object before
    piping if ordering is needed.

    The context object ($_ in scriptblocks) contains:
    - Item: Current item from pipeline
    - Writer: JSON writer instance (when using WriterFactory)
    - Writers: Dictionary of writers keyed by Tag (when using ProcessWriterFactory)

    Three parameter modes available:
    1. DefaultSingleWriter (-Path only): Creates default indented Utf8JsonWriter
    2. CustomSingleWriter (-WriterFactory): Uses custom writer creation logic
    3. MultiWriter (-ProcessWriterFactory): Creates separate writer per group

    Writer type validation requires the -Utf8JsonWriter switch.
    Future switch parameters (e.g., -NewtonSoftWriter) will be added for other writer types.

    .PARAMETER Path
    Output file path. Required for default Utf8JsonWriter mode.
    Not needed when using custom WriterFactory or ProcessWriterFactory - those manage their own file paths.

    .PARAMETER WriterFactory
    Scriptblock that creates and returns a JSON writer for single-file output.
    Optional. If omitted, creates default Utf8JsonWriter with indentation enabled.
    Context ($_ in script) contains: Item, Path.
    Example: { [System.Text.Json.Utf8JsonWriter]::new(...) }

    .PARAMETER ProcessWriterFactory
    Scriptblock that returns @{ Tag; Writer } for multi-file output.
    Invoked for each item. Context ($_ in script) contains: Item, Writers (hashtable).
    If writer not in Writers collection, -Begin is invoked before first use.
    All writers are finalized and disposed in -End phase.

    .PARAMETER Utf8JsonWriter
    Specify the writer type as System.Text.Json.Utf8JsonWriter.
    This enables type validation for all writer factories.
    Required for all parameter sets.

    .PARAMETER Begin
    Scriptblock executed before processing items (once per unique writer in multi-writer mode).
    Context ($_ in script) contains: Item (null in single-writer), Writer.

    .PARAMETER Process
    Scriptblock executed for each item.
    Context ($_ in script) contains: Item, Writer.

    .PARAMETER End
    Scriptblock executed after all items for each writer (once per unique writer).
    Context ($_ in script) contains: Item (null), Writer.

    .EXAMPLE
    # Default single writer (Utf8JsonWriter with indentation)
    @('item1', 'item2', 'item3') | Write-EachToJson `
        -Path "output.json" `
        -Utf8JsonWriter `
        -Begin { $_.Writer.WriteStartArray() } `
        -Process { $_.Writer.WriteStringValue($_.Item) } `
        -End { $_.Writer.WriteEndArray() }

    .EXAMPLE
    # Custom single writer
    @('item1', 'item2', 'item3') | Write-EachToJson `
        -WriterFactory {
            $options = [System.Text.Json.JsonWriterOptions]::new()
            $options.Indented = $true
            $fileStream = [System.IO.FileStream]::new("custom.json", [System.IO.FileMode]::Create)
            [System.Text.Json.Utf8JsonWriter]::new($fileStream, $options)
        } `
        -Utf8JsonWriter `
        -Begin { $_.Writer.WriteStartArray() } `
        -Process { $_.Writer.WriteStringValue($_.Item) } `
        -End { $_.Writer.WriteEndArray() }

    .EXAMPLE
    # Multiple writers by provider
    $items | Write-EachToJson `
        -ProcessWriterFactory {
            $provider = $_.Item.Provider
            $writer = $_.Writers[$provider]
            if (-not $writer) {
                $options = [System.Text.Json.JsonWriterOptions]::new()
                $options.Indented = $true
                $filePath = "config/$provider.json"
                $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Create)
                $writer = [System.Text.Json.Utf8JsonWriter]::new($fileStream, $options)
            }
            @{ Tag = $provider; Writer = $writer }
        } `
        -Utf8JsonWriter `
        -Begin { $_.Writer.WriteStartObject() } `
        -Process { $_.Writer.WritePropertyName($_.Item.Name); $_.Writer.WriteStringValue($_.Item.Value) } `
        -End { $_.Writer.WriteEndObject() }
    #>
    [CmdletBinding(DefaultParameterSetName = 'DefaultSingleWriter_Utf8JsonWriter')]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [object[]]
        $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'DefaultSingleWriter_Utf8JsonWriter')]
        [string]
        $Path,

        [Parameter(Mandatory, ParameterSetName = 'CustomSingleWriter_Utf8JsonWriter')]
        [scriptblock]
        $WriterFactory,

        [Parameter(Mandatory, ParameterSetName = 'MultiWriter_Utf8JsonWriter')]
        [scriptblock]
        $ProcessWriterFactory,

        [Parameter(Mandatory, ParameterSetName = 'DefaultSingleWriter_Utf8JsonWriter')]
        [Parameter(Mandatory, ParameterSetName = 'CustomSingleWriter_Utf8JsonWriter')]
        [Parameter(Mandatory, ParameterSetName = 'MultiWriter_Utf8JsonWriter')]
        [switch]
        $Utf8JsonWriter,

        [scriptblock]
        $Begin,

        [scriptblock]
        $Process,

        [scriptblock]
        $End
    )

    begin {
        # Determine writer mode and type
        $paramSetName = $PSCmdlet.ParameterSetName
        $writerMode = $paramSetName -replace '_Utf8JsonWriter$', ''
        
        # Determine expected writer type
        $expectedWriterType = if ($Utf8JsonWriter) {
            [System.Text.Json.Utf8JsonWriter]
        }
        
        # $writers = @{}  # Hashtable for multi-writer mode
        $writers = @()
        $singleWriter = $null  # For single-writer mode
        $fileStream = $null  # Track for disposal in single-writer mode

        # Initialize single writer
        if ($writerMode -eq 'DefaultSingleWriter') {
            # Create default Utf8JsonWriter
            $options = [System.Text.Json.JsonWriterOptions]::new()
            $options.Indented = $true
            $options.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping

            $fileStream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Create)
            $singleWriter = [System.Text.Json.Utf8JsonWriter]::new($fileStream, $options)

            $context = [PSCustomObject]@{
                Item   = $null
                Writer = $singleWriter
            }

            if ($Begin) {
                $context `
                | ForEach-Object `
                    -Process $Begin
            }
        }
        elseif ($writerMode -eq 'CustomSingleWriter') {
            # Use provided factory
            $context = [PSCustomObject]@{
                Item  = $null
                Path  = $Path
                Writer = $null
            }

            $singleWriter = & $WriterFactory.Invoke($context)
            
            # Validate writer type
            if ($singleWriter -isnot $expectedWriterType) {
                throw "WriterFactory must return a writer of type '$($expectedWriterType.Name)', but returned '$($singleWriter.GetType().Name)'"
            }
            
            $context.Writer = $singleWriter

            if ($Begin) {
                $context `
                | ForEach-Object `
                    -Process $Begin
            }
        }
    }

    process {
        if ($writerMode -eq 'DefaultSingleWriter' -or $writerMode -eq 'CustomSingleWriter') {
            # Single writer mode
            $context = [PSCustomObject]@{
                Item   = $_
                Writer = $singleWriter
            }

            if ($Process) {
                $context `
                | ForEach-Object `
                    -Process $Process
            }
        }
        elseif ($writerMode -eq 'MultiWriter') {
            # Multi-writer mode
            if (-not $ProcessWriterFactory) {
                throw "ProcessWriterFactory must be provided for multi-writer mode"
            }

            $context = [PSCustomObject]@{
                Item    = $_
                Writers = $writers
            }

            $result = & $ProcessWriterFactory.Invoke($context)

            if (-not $result) {
                throw "ProcessWriterFactory must return @{ Tag; Writer } hashtable"
            }

            if (
                Get-IsDictionary `
                    -InputObject $result `
            ) {
                $tag = $result.Tag
                $writer = $result.Writer
            }
            else {
                $writer = $result
            }
            
            
            # Validate writer type
            if ($writer -isnot $expectedWriterType) {
                throw "ProcessWriterFactory must return a writer of type '$($expectedWriterType.Name)' for tag '$tag', but returned '$($writer.GetType().Name)'"
            }

            # Initialize writer if first time seeing this tag
            if (-not $writers.ContainsKey($tag)) {
                $writers[$tag] = $writer

                # Run Begin for new writer
                if ($Begin) {
                    $beginContext = [PSCustomObject]@{
                        Item   = $null
                        Writer = $writer
                    }

                    $beginContext `
                    | ForEach-Object `
                        -Process $Begin
                }
            }

            # Run Process with current writer
            if ($Process) {
                $processContext = [PSCustomObject]@{
                    Item   = $_
                    Writer = $writer
                }

                $processContext `
                | ForEach-Object `
                    -Process $Process
            }
        }
    }

    end {
        try {
            if ($writerMode -eq 'DefaultSingleWriter' -or $writerMode -eq 'CustomSingleWriter') {
                # Single writer End
                if ($singleWriter -and $End) {
                    $context = [PSCustomObject]@{
                        Item   = $null
                        Writer = $singleWriter
                    }

                    $context `
                    | ForEach-Object `
                        -Process $End
                }
            }
            elseif ($writerMode -eq 'MultiWriter') {
                # Multi-writer End: finalize all writers
                if ($End) {
                    $writers.GetEnumerator() | ForEach-Object {
                        $writer = $_.Value

                        $endContext = [PSCustomObject]@{
                            Item   = $null
                            Writer = $writer
                        }

                        $endContext `
                        | ForEach-Object `
                            -Process $End
                    }
                }
            }
        }
        finally {
            # Dispose all writers
            if ($writerMode -eq 'DefaultSingleWriter' -or $writerMode -eq 'CustomSingleWriter') {
                if ($singleWriter) {
                    $singleWriter.Dispose()
                }
                if ($fileStream) {
                    $fileStream.Dispose()
                }
            }
            elseif ($writerMode -eq 'MultiWriter') {
                $writers.GetEnumerator() | ForEach-Object {
                    $_.Value.Dispose()
                }
            }
        }
    }
}
# Bloom Filter implementation for efficient membership testing
# Provides fast probabilistic key existence checking

class BloomFilter {
    [byte[]]
    $bitArray

    [int]
    $size

    [int]
    $hashCount
    
    <#
    .SYNOPSIS
    Creates a new Bloom filter with optimal parameters.
    
    .PARAMETER ExpectedItems
    Expected number of items to be added
    
    .PARAMETER FalsePositiveRate
    Desired false positive rate (default 0.01 = 1%)
    #>
    BloomFilter(
        [int]
        $expectedItems,
        
        [double]
        $falsePositiveRate = 0.01
    ) {
        if ($expectedItems -le 0) {
            throw "ExpectedItems must be greater than 0"
        }

        if (
            $falsePositiveRate -le 0 `
            -or $falsePositiveRate -ge 1
        ) {
            throw "FalsePositiveRate must be between 0 and 1"
        }
        
        # Optimal bit array size: -(n * ln(p)) / (ln(2)^2)
        $this.size = [Math]::Ceiling(
            -($expectedItems * [Math]::Log($falsePositiveRate)) / 
            ([Math]::Log(2) * [Math]::Log(2))
        )
        
        # Optimal hash function count: (m / n) * ln(2)
        $this.hashCount = [Math]::Max(1, [Math]::Ceiling(($this.size / $expectedItems) * [Math]::Log(2)))
        
        $this.bitArray = @(0) * [Math]::Ceiling($this.size / 8)
    }
    
    <#
    .SYNOPSIS
    Reconstructs a Bloom filter from saved bitArray data.
    
    .PARAMETER BitArray
    The saved bit array from a previous Bloom filter
    
    .PARAMETER ExpectedItems
    Expected number of items (used to recalculate optimal hashCount)
    #>
    BloomFilter(
        [byte[]]
        $bitArray,
        
        [int]
        $expectedItems = 100
    ) {
        if ($expectedItems -le 0) {
            throw "ExpectedItems must be greater than 0"
        }
        
        # If bitArray is null or empty, create a fresh filter
        if (
            $null -eq $bitArray `
            -or $bitArray.Length -eq 0
        ) {
            # Create fresh filter with standard parameters
            $this.size = [Math]::Ceiling(
                -($expectedItems * [Math]::Log(0.01)) / 
                ([Math]::Log(2) * [Math]::Log(2))
            )
            $this.hashCount = [Math]::Max(1, [Math]::Ceiling(($this.size / $expectedItems) * [Math]::Log(2)))
            $this.bitArray = @(0) * [Math]::Ceiling($this.size / 8)
        }
        else {
            # Load from saved data
            $this.bitArray = $bitArray
            $this.size = $bitArray.Length * 8
            
            # Recalculate optimal hash count based on size and expected items
            $this.hashCount = [Math]::Max(1, [Math]::Ceiling(($this.size / $expectedItems) * [Math]::Log(2)))
        }
    }
    
    <#
    .SYNOPSIS
    Reconstructs a Bloom filter from saved data with exact parameters.
    
    .PARAMETER BitArray
    The saved bit array from a previous Bloom filter
    
    .PARAMETER Size
    The original size in bits
    
    .PARAMETER HashCount
    The original hash count used
    #>
    BloomFilter(
        [byte[]]
        $bitArray,
        
        [int]
        $size,
        
        [int]
        $hashCount
    ) {
        if (
            $null -eq $bitArray `
            -or $bitArray.Length -eq 0
        ) {
            throw "BitArray cannot be null or empty"
        }

        if ($size -le 0) {
            throw "Size must be greater than 0"
        }

        if ($hashCount -le 0) {
            throw "HashCount must be greater than 0"
        }
        
        $this.bitArray = $bitArray
        $this.size = $size
        $this.hashCount = $hashCount
    }
    
    <#
    .SYNOPSIS
    Adds an item to the Bloom filter.
    #>
    [void] Add(
        [string]
        $item
    ) {
        if ([string]::IsNullOrEmpty($item)) {
            throw "Item cannot be null or empty"
        }
        
        for ($i = 0; $i -lt $this.hashCount; $i++) {
            $hash = $this.Hash($item, $i)
            $byteIndex = [Math]::Floor($hash / 8)
            $bitIndex = $hash % 8
            $this.bitArray[$byteIndex] = $this.bitArray[$byteIndex] -bor (1 -shl $bitIndex)
        }
    }
    
    <#
    .SYNOPSIS
    Tests if an item might exist (returns $true if "maybe exists", $false if "definitely not exists").
    
    .DESCRIPTION
    Returns $false only if item definitely doesn't exist.
    Returns $true if item might exist (may have false positives).
    #>
    [bool] Contains(
        [string]
        $item
    ) {
        if ([string]::IsNullOrEmpty($item)) {
            return $false
        }
        
        for ($i = 0; $i -lt $this.hashCount; $i++) {
            $hash = $this.Hash($item, $i)
            $byteIndex = [Math]::Floor($hash / 8)
            $bitIndex = $hash % 8

            if (($this.bitArray[$byteIndex] -band (1 -shl $bitIndex)) -eq 0) {
                return $false
            }
        }

        return $true
    }
    
    <#
    .SYNOPSIS
    Gets the size of the Bloom filter in bytes.
    #>
    [int] GetSizeInBytes() {
        return $this.bitArray.Length
    }
    
    <#
    .SYNOPSIS
    Internal hash function using multiple seeds.
    #>
    [int] Hash(
        [string]
        $item,
        
        [int]
        $seed
    ) {
        $hash = $seed

        foreach ($char in $item.ToCharArray()) {
            $hash = ($hash * 31 + [int]$char) % $this.size
        }
        
        return [Math]::Abs($hash)
    }
}

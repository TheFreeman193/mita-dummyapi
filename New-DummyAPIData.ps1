[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Name,
    [string]$Path = $PSScriptRoot,
    [int]$NumVersions = 100,
    [int]$NumValuesPerEntry = 5,
    [int]$MaxRecursionDepth = 5,
    [int]$StringLength = 32,
    [string]$IndexClass = 'updates',
    [string]$DataClass = 'data',
    [switch]$Force
)

begin {
    if (Test-Path -Path $Path -PathType Leaf) { return $false }
    if (-not (Test-Path -Path $Path)) {
        $null = New-Item -ItemType Directory -Path $Path
    }
    $RNG = [System.Random]::new()
    function GetRandomString {
        param([int]$Length)
        [char[]]$CharList = @(47..57 + 65..90 + 97..122 + @(43))
        (Get-Random -InputObject $CharList -Count $Length) -join ''
    }
    function GetRandomType {
        param ($Min)
        $Type = $RNG.Next($Min, 7)
        switch ($Type) {
            6 { $null }
            5 { $RNG.NextDouble(); break }
            4 { $RNG.NextDouble() -lt 0.5; break }
            3 { Get-Random; break }
            2 { GetRandomString -Length $StringLength; break }
            1 { [object[]]::new($NumValuesPerEntry) }
            default { @{} }
        }
    }
    function FillArray {
        param([array]$Array, [int]$_currentDepth = 0)
        $Min = if ($_currentDepth -ge $MaxRecursionDepth) { 2 } else { 0 }
        for ($Index = 0; $Index -lt $Array.Count; $Index++) {
            $Value = GetRandomType -Min $Min
            if ($Value -is [hashtable]) { FillTable $Value ($_currentDepth + 1) }
            elseif ($Value -is [array]) { FillArray $Value ($_currentDepth + 1) }
            $Array[$Index] = $Value
        }
    }
    function FillTable {
        param([hashtable]$Table, [int]$_currentDepth = 0)
        $Min = if ($_currentDepth -ge $MaxRecursionDepth) { 2 } else { 0 }
        for ($KeyN = 0; $KeyN -lt $NumValuesPerEntry; $KeyN++) {
            $Key = "Random_$(GetRandomString -Length 8)"
            $Value = GetRandomType -Min $Min
            if ($Value -is [hashtable]) { FillTable $Value ($_currentDepth + 1) }
            elseif ($Value -is [array]) { FillArray $Value ($_currentDepth + 1) }
            $Table[$Key] = $Value
        }
    }
}

process {
    $IndexPath = Join-Path $Path $Name
    $null = Test-Path $IndexPath -IsValid
    if (-not $?) {
        Write-Error -Message "Index Path '$IndexPath' is not valid."
        return $false
    }
    $DataPath = Join-Path $IndexPath $DataClass
    $null = Test-Path $DataPath -IsValid
    if (-not $?) {
        Write-Error -Message "Data Path '$IndexPath' is not valid."
        return $false
    }
    if ((Test-Path $IndexPath) -and -not $Force) {
        Write-Error -Message "Path '$IndexPath' already exists."
        return $false
    }
    $null = New-Item -ItemType Directory -Path $DataPath
    $Index = @{
        class   = $IndexClass
        updates = @()
    }
    for ($i -eq 0; $i -lt $NumVersions; $i++) {
        # 2005 - 2021
        $Date = Get-Random -Minimum 1104537600000 -Maximum 1640995200000
        $Guid = (New-Guid).Guid
        $Data = @{
            class = $DataClass
            data  = @{}
        }
        FillTable $Data.data
        $Index.updates += @{
            guid = $Guid
            date = $Date
        }
        $Data | ConvertTo-Json -Depth ($MaxRecursionDepth + 1) | Out-File -LiteralPath (Join-Path $DataPath $Date)
    }
    $Index | ConvertTo-Json -Depth ($MaxRecursionDepth + 1) | Out-File -LiteralPath (Join-Path $IndexPath $IndexClass)
}

function Get-DataStoreFile {
    [OutputType([System.IO.FileInfo])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [string]$Name,
        [switch]$MustExist,
        [switch]$MustNotExist
    )
    begin {
        # Determine store directory and ensure it exists
        $StorePath = Join-Path $Home '.store'
        if (-not (Test-Path -LiteralPath $StorePath -PathType Container)) {
            New-Item -ItemType Directory -Path $StorePath -ErrorAction Stop
        }
        # Regex pattern for removing invalid filename chars
        $SafePattern = '[{0}]' -f [regex]::Escape(([System.IO.Path]::GetInvalidFileNameChars()) -join '')
    }
    process {
        # Determine safe file path for store
        $SafeName = $Name -replace $SafePattern, '_'
        $StoreFilename = "${SafeName}.clixml"
        $StoreFile = Join-Path $StorePath $StoreFilename

        # Check if store file exists
        $Exists = Test-Path -PathType Leaf -LiteralPath $StoreFile

        # Validate requirements for existence and stop if not met
        if ($MustExist -and -not $Exists) {
            $Record = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new(
                    "Cannot find data store '$Name' because it does not exist."
                ), 'DataStoreNotFound', 'ObjectNotFound', $Name
            )
            $PSCmdlet.ThrowTerminatingError($Record)
        }
        elseif ($MustNotExist -and $Exists) {
            $Record = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.IOException]::new(
                    "A data store with the specified name '$Name' already exists."
                ), 'DataStoreExists', 'ResourceExists', $Name
            )
            $PSCmdlet.ThrowTerminatingError($Record)
        }

        # If store file doesn't exist, create a blank one with current time
        if (-not $Exists) {
            Export-Clixml -LiteralPath $StoreFile -InputObject @{}
        }

        # return FileInfo for store file
        Get-Item $StoreFile
    }
}

function New-DataStore {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    # Determine valid store filename, check it doesn't exist, and create it
    $StoreFile = Get-DataStoreFile -Name $Name -MustNotExist

    # If it exists or the path was invalid, stop
    if (-not $? -or $null -eq $StoreFile) { return }

    # Return new data store
    Get-DataStore -Name $Name
}

function Remove-DataStore {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )
    # Determine valid store filename and check it exists
    $StoreFile = Get-DataStoreFile -Name $Name -MustExist

    # If it doesn't, stop
    if (-not $? -or $null -eq $StoreFile) { return }

    # Delete store file
    Remove-Item -LiteralPath $StoreFile
}

function Get-DataStore {
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )
    process {
        # Determine valid store filename and check it exists
        $StoreFile = Get-DataStoreFile -Name $Name -MustExist

        # If it doesn't, stop
        if (-not $? -or $null -eq $StoreFile) { return }

        # Import CLIXML data from store
        $Data = Import-Clixml -LiteralPath $StoreFile.FullName

        # Return rich store object with name and file time
        [pscustomobject]@{
            Update = $StoreFile.LastWriteTimeUtc
            Data   = $Data
            Name   = $Name
        }
    }
}

function Set-DataStore {
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [psobject]$Data,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [datetime]$Update
    )
    process {
        # Determine valid store filename and check it exists
        $StoreFile = Get-DataStoreFile -Name $Name -MustExist

        # If it doesn't, stop
        if (-not $? -or $null -eq $StoreFile) { return }

        # Ensure data is a PSObject for CLIXML
        $WrappedData = [pscustomobject]$Data

        # Export PSObject to CLIXML file
        Export-Clixml -InputObject $WrappedData -LiteralPath $StoreFile

        # Make sure it didn't fail
        if (-not $?) { return }

        # Set the file time based on update
        Set-ItemProperty -LiteralPath $StoreFile -Name LastWriteTimeUtc -Value $Update
    }
}

function Update-DataStore {
    param ([string]$Name, [string]$Source)

    # Get list of updates from API
    $RequestUri = '{0}/{1}' -f $Source.TrimEnd('/'), 'updates'
    $Updates = (Invoke-RestMethod -Uri $RequestUri).updates.date

    # Determine latest update and parse unix timestamp
    [int64]$Latest = 0
    $Updates.ForEach{ if ($_ -gt $Latest) { $Latest = $_ } }
    $Update = [datetime]::new(1970, 1, 1, 0, 0, 0, 1).AddMilliseconds($Latest)

    # Get local data store
    $Store = Get-DataStore -Name $Name

    # Compare updates, and stop if local store is up-to-date
    if ($Update -le $Store.Update) { return }

    # Get data of latest update from API
    $RequestUri = '{0}/{1}/{2}' -f $Source.TrimEnd('/'), 'data', $Latest
    [psobject]$NewData = Invoke-RestMethod $RequestUri

    # Save new data to local store
    Set-DataStore -Name $Store.Name -Data $NewData.data -Update $Update
}

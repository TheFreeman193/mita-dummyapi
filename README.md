# Dummy API for Modern IT Automation with PowerShell

This repository comprises a static dummy API for use with the _Data Store_ demo functions from the _Mocking_ chapter of _Modern IT Automation with PowerShell_, 1st edition.

There are eight subdirectories, _001–008_, each representing a _bucket_ of data that serves as the remote `$Source` for `Update-DataStore`.

Each bucket has an _updates_ manifest in the root.
This file contains information about the dummy data in the _data_ subdirectory of the bucket.
Each file in _data_ is an 'update' to the bucket and `Update-DataStore` should select and synchronize the latest of these.

The files contain randomly generated dummy data from [New-DummyAPIData.ps1](./New-DummyAPIData.ps1).

## Using the Dummy API

Pass the GitHub raw URL for the numbered subdirectory to the `-Source` parameter of `Update-DataStore`:

```PowerShell
New-DataStore -Name Test01
Set-DataStoreDate -Name Test01 -Update '2000-01-01'

$Uri = 'https://raw.githubusercontent.com/TheFreeman193/mita-dummyapi/main/001'

Update-DataStore -Name Test01 -Source $Uri
```

## How it Works

The `Update-DataStore` function appends _updates_ to the `$Source` path to retrieve the update manifest, and _data/&lt;timestamp&gt;_ to retrieve a bucket update.
Where for a real API this might represent queries, the dummy API provides raw files at fixed paths.

## Data Store Functions

You can find the data store demo functions, along with Pester test files used in the chapter, in the
[Modern IT Automation with PowerShell Extras](https://github.com/devops-collective-inc/Modern-IT-Automation-with-PowerShellExtras/tree/main/Edition-01/Mocking/DataStoreDemo/) repository.

They are duplicated here in the [DataStoreDemo](./DataStoreDemo/) subdirectory.

## License

The content of this repository is released under the [MIT License](./LICENSE.txt). Please also attribute
[DevOps Collective, Inc.](https://github.com/devops-collective-inc/), the publisher of the book.

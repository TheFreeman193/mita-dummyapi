BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}
Describe "Update-DataStore" -Tag "Mocked", "Unit" {

    BeforeAll {
        [int64]$LaterUnix = Get-Random -Minimum 16.1e+11 -Maximum 16.2e+11
        [int64]$EarlierUnix = Get-Random -Minimum 16e+11 -Maximum 16.1e+11
        [datetime]$UnixEpoch = [datetime]::new(1970, 1, 1, 0, 0, 0, 1)
        [datetime]$Earlier = $UnixEpoch.AddMilliseconds($EarlierUnix)
        [datetime]$Later = $UnixEpoch.AddMilliseconds($LaterUnix)

        Mock Get-DataStore {
            @{ Name = $Name; Update = $Earlier; Data = @{} }
        } -Verifiable

        Mock Set-DataStore { $PesterBoundParameters } -Verifiable

        Mock Invoke-RestMethod {
            @{ class = 'updates'; updates = @(
                    @{ guid = [guid]::Empty; date = $EarlierUnix }
                    @{ guid = [guid]::Empty; date = $LaterUnix }
                )
            }
        } -ParameterFilter { $Uri -like '*/updates' } -Verifiable

        Mock Invoke-RestMethod {
            $Date = 0
            if ($Uri -match '/data/(\d+)$') {
                [int64]$Date = $Matches[1]
            }
            @{
                class = 'data'
                date  = $Date
                name  = "Update $Date"
                data  = @{ Property1 = "Value 1"; Property2 = "Value 2" }
            }
        } -ParameterFilter { $Uri -match '/data/\d+$' } -Verifiable

        Mock Invoke-RestMethod {
            throw (
                'Invoke-RestMethod called with unexpected parameters: {0}' -f
                ($PesterBoundParameters.Keys.ForEach{ "$_ = $($PesterBoundParameters.$_)" } -join ', ')
            )
        }
    }

    BeforeEach {
        $Name = Get-Random
        $Result = Update-DataStore -Name $Name -Source 'https://example.com'
    }

    Context "Unit tests" {

        It "Should access the right data store" {
            $Result.Name | Should -Be $Name
        }
        It "Should choose the latest update" {
            $Result.Update | Should -Be $Later
        }

    }

    Context "Mock tests" {

        It "Should access data stores and API" {
            Should -InvokeVerifiable
        }

        It "Should call Invoke-RestMethod once for update URL" {
            Should -Invoke -CommandName Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -like '*/updates' }
        }
        It "Should call Invoke-RestMethod once for data URL" {
            Should -Invoke -CommandName Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -match '/data/\d+$' }
        }
        It "Should call Get-DataStore once" {
            Should -Invoke -CommandName Get-DataStore -Times 1
        }

        It "Should call Set-DataStore once" {
            Should -Invoke -CommandName Set-DataStore -Times 1
        }

    }


} # End Describe

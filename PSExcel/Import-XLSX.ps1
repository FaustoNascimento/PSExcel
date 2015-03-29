﻿function Import-XLSX {
    <#
    .SYNOPSIS
        Import data from Excel

    .DESCRIPTION
        Import data from Excel

    .EXAMPLE
        Import-XLSX -Path "C:\Excel.xlsx"

        #Import data from C:\Excel.xlsx

    .EXAMPLE
        Import-XLSX -Path "C:\Excel.xlsx" -Header One, Two, Five

        # Import data from C:\Excel.xlsx
        # Replace headers with One, Two, Five

    .EXAMPLE
        Import-XLSX -Path "C:\Excel.xlsx" -Header One, Two, Five -FirstRowIsData -Sheet 2

        # Import data from C:\Excel.xlsx
        # Assume first row is data
        # Use headers One, Two, Five
        # Pull from sheet 2 (sheet 1 is default)

    .NOTES
        Thanks to Doug Finke for his example:
            https://github.com/dfinke/ImportExcel/blob/master/ImportExcel.psm1

        Thanks to Philip Thompson for an expansive set of examples on working with EPPlus in PowerShell:
            https://excelpslib.codeplex.com/

        Dates won't convert to datetime.
            Looking into solutions, in the interim, you can do this with [datetime]::FromOADate(42092.3634275347)

    .FUNCTIONALITY
        Excel
    #>
    [cmdletbinding()]
    param(
        [parameter( Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [validatescript({Test-Path $_})]
        [string[]]$Path,

        $Sheet = 1,

        [string[]]$Header,

        [switch]$FirstRowIsData
    )
    Process
    {
        foreach($file in $path)
        {
            #Resolve relative paths... Thanks Oisin! http://stackoverflow.com/a/3040982/3067642
            $file = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)

            write-verbose "target excel file $($file)"

            Try
            {
                $xl = New-Object OfficeOpenXml.ExcelPackage $file
                $workbook  = $xl.Workbook
            }
            Catch
            {
                Write-Error "Failed to open '$file':`n$_"
                continue
            }

            Try
            {
                if( @($workbook.Worksheets).count -eq 0)
                {
                    Throw "No worksheets found"
                }
                else
                {
                    $worksheet = $workbook.Worksheets[$Sheet]
                    $dimension = $worksheet.Dimension

                    $Rows = $dimension.Rows
                    $Columns = $dimension.Columns
                }

            }
            Catch
            {
                Write-Error "Failed to gather Worksheet '$Sheet' data for file '$file':`n$_"
                continue
            }

            $RowStart = 2
            if($Header -and $Header.count -gt 0)
            {
                if($Header.count -ne $Columns)
                {
                    Write-Error "Found '$columns' columns, provided $($header.count) headers.  You must provide a header for every column."
                }
                if($FirstRowIsData)
                {
                    $RowStart = 1
                }
            }
            else
            {
                $Header = foreach ($Column in 1..$Columns)
                {
                    $worksheet.Cells.Item(1,$Column).Value
                }
            }

            $SelectedHeaders = $Headers | select -Unique

            Write-Verbose "Found $(($RowStart..$Rows).count) rows, $Columns columns, with headers:`n$($Headers | Out-String)"

            foreach ($Row in $RowStart..$Rows)
            {
                $RowData = @{}
                foreach ($Column in 0..($Columns - 1) )
                {
                    $Name  = $Header[$Column]
                    $Value = $worksheet.Cells.Item($Row, ($Column+1)).Value

                    if($RowData.ContainsKey($Name) )
                    {
                        Write-Warning "Duplicate header for '$Name' found, with value '$Value', in row $Row"
                    }
                    else
                    {
                        $RowData.Add($Name, $Value)
                    }
                }
                New-Object -TypeName PSObject -Property $RowData | Select -Property $SelectedHeaders
            }

            $xl.Dispose()
            $xl = $null
        }
    }
}
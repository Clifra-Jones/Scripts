using namespace System.Collections.Generic
#Requires -Modules ImportExcel
Param(
    [Parameter(Mandatory)]
    [string]$BaseFolder,
    [Parameter(Mandatory)]
    [string]$ReportName,
    [string]$OutputFolder,
    [switch]$NoClobber,
    [ValidateSet('OneLevel','SubTree')]
    [string]$Scope = 'OneLevel',
    [switch]$IncludeTypeStats,
    [string[]]$ExcludeFolders,
    [switch]$OpenOnComplete
)

if (-not $ReportName.EndsWith('.xlsx')) {
    $WorksheetName = $ReportName
    $ReportName += '.xlsx'
} else {
    $WorksheetName = $ReportName.Replace('.xls'.'')
}

If ($OutputFolder) {
    $ReportPath = "{0}/{1}" -f $OutputFolder, $ReportName
} else {
    $ReportPath = "./{0}" -f $ReportName
}

If (Test-Path -Path $ReportPath) {
    If (-not $NoClobber.IsPresent) {
        Remove-Item -Path $ReportPath -Force
    } else {
        Write-Host "Output file $ReportPath already exist!"
        exit
    }
}

$StartRow = 4
$StartColumn = 1

$titleParams = @{
    TitleBold=$true;
    TitleSize=9;
}

$tableParams = @{
    BorderColor="black";
    BorderRight="thin";
    BorderLeft="thin";
    BorderTop="thin";
    BorderBottom="thin";
    FontSize=9
}

$TableStyle = New-ExcelStyle @tableParams

function Get-FolderStats() {
    Param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Recurse#,
        #[switch]$IncludeTypeStats
    )

    $params = @{}
    if ($Recurse.IsPresent) {
        $params.Add("Recurse", $true)
    } else {
        $params.Add("Recurse", $false)
    }

    $Items = Get-ChildItem -Path $Path @params
    $Stats = $Items | Measure-Object -Property Length -Sum | Select-Object Count, @{Name="Size"; Expression={$_.Sum / 1mb}}
    $Stats | Add-Member -MemberType NoteProperty -Name "Folder" -Value $Path

    $threeYrStats = $Items.Where({$_.LastWriteTime -lt (Get-Date).AddYears(-3)}) | Measure-Object -Property Length -Sum | Select-Object Count, @{Name="Size";Expression={$_.Sum / 1mb}}
    $fourYrStats = $Items.Where({$_.LastWriteTime -lt (Get-Date).AddYears(-4)}) | Measure-Object -Property Length -Sum | Select-Object Count, @{Name="Size";Expression={$_.Sum / 1mb}}
    $fiveYrStats = $Items.Where({$_.LastWriteTime -lt (Get-Date).AddYears(-5)}) | Measure-Object -Property Length -Sum | Select-Object Count, @{Name="Size";Expression={$_.Sum / 1mb}}

    $Stats | Add-Member -MemberType NoteProperty -Name "ThreeYearFiles" -Value $threeYrStats.Count
    $Stats | Add-Member -MemberType NoteProperty -Name "ThreeYearSize" -Value $threeYrStats.Size

    $Stats | Add-Member -MemberType NoteProperty -Name "FourYearFiles" -Value $fourYrStats.Count
    $Stats | Add-Member -MemberType NoteProperty -Name "FourYearSize" -Value $fourYrStats.Size

    $Stats | Add-Member -MemberType NoteProperty -Name "FiveYearFiles" -Value $fiveYrStats.Count
    $Stats | Add-Member -MemberType NoteProperty -Name "FiveYearSize" -Value $fiveYrStats.Size

    # Stats per file type

    if ($IncludeTypeStats.IsPresent) {
        $TypeStats = [List[PsObject]]::New()

        $Types = $Items | Group-Object -Property Extension | Where-Object {$_.Name -ne ''}
        foreach ($Type in $Types) {
            $TypeSize = ($Type.Group | Measure-Object -Property Length -Sum).Sum / 1mb
            if ($TypeSize -ge 0.01) {
                $TypeStat = [PSCustomObject]@{
                    Name = ( ('' -eq $Type.Name) ? "Undefined" : $Type.Name )
                    Count = $Type.Count
                    Size = $TypeSize
                }
                $TypeStats.Add($TypeStat)
            }
        }

        if ($TypeStats.Count -gt 0) {
            $Stats | Add-Member -MemberType NoteProperty -Name "TypeStats" -Value ($TypeStats.toArray())
        }
    }
    return $Stats
}


$excel = Export-Excel -Path $ReportPath -WorksheetName $WorksheetName -PassThru

$SheetTitle = "File Storage Statistics for: $BaseFolder"
$excel.Workbook.Worksheets[$WorksheetName].Cells["a1"].Value = $SheetTitle
$excel.Workbook.Worksheets[$WorksheetName].Cells["a1"].Style.Font.Bold = $true
$excel.Workbook.Worksheets[$WorksheetName].Cells["a1"].Style.Font.Size = 14



# Get Stats for entire folder tree
$FolderStatsTotal = Get-FolderStats -Path $BaseFolder -Recurse

$FolderStatsTotalData = $FolderStatsTotal | Select-Object @{Name = "Files"; Expression = {$_.Count}},@{Name = "Size MB"; Expression = {$_.Size.ToString("#.##")}},
                                                @{Name = "Files Over 3 Years"; Expression = {$_.ThreeYearFiles}}, @{Name = "Size Over 3 Years"; Expression={$_.ThreeYearSize.ToString("#.##")}},
                                                @{Name = "Files Over 4 Years"; Expression = {$_.FourYearFiles}}, @{Name = "Size Over 4 Years"; Expression={$_.FourYearSize.ToString("#.##")}},
                                                @{Name = "Files Over 5 Years"; Expression = {$_.FiveYearFiles}}, @{Name = "Size Over 5 Years"; Expression={$_.FiveYearSize.ToString("#.##")}}

$TableTitle = "{0} : Totals" -f $BaseFolder

$excel = $FolderStatsTotalData  | Export-Excel -ExcelPackage $excel `
                                    -WorksheetName $WorksheetName `
                                    -TableName 'RootStatsTotal' `
                                    -StartRow $StartRow `
                                    -StartColumn $StartColumn `
                                    -Title $TableTitle `
                                    -Style $TableStyle `
                                    @titleParams `
                                    -AutoSize `
                                    -Numberformat Number `
                                    -PassThru ` 3>$Null

$StartRow += ($RootDirStats.Length + 4)

# Get Status for root Directory
$RootDirStats = Get-FolderStats -Path $BaseFolder
Write-Host "Folder: $BaseFolder" -ForegroundColor Yellow

$RootDirStatsData =$RootDirStats | Select-Object @{Name = "Files"; Expression = {$_.Count}},@{Name = "Size MB"; Expression = {$_.Size.ToString("#.##")}},
                                @{Name = "Files Over 3 Years"; Expression = {$_.ThreeYearFiles}}, @{Name = "Size Over 3 Years"; Expression={$_.ThreeYearSize.ToString("#.##")}},
                                @{Name = "Files Over 4 Years"; Expression = {$_.FourYearFiles}}, @{Name = "Size Over 4 Years"; Expression={$_.FourYearSize.ToString("#.##")}},
                                @{Name = "Files Over 5 Years"; Expression = {$_.FiveYearFiles}}, @{Name = "Size Over 5 Years"; Expression={$_.FiveYearSize.ToString("#.##")}}

$excel = $RootDirStatsData | Export-Excel -ExcelPackage $excel `
                                    -WorksheetName $WorksheetName `
                                    -TableName 'RootStats' `
                                    -StartRow $StartRow `
                                    -StartColumn $StartColumn `
                                    -Title $BaseFolder `
                                    -Style $TableStyle `
                                    @titleParams `
                                    -AutoSize `
                                    -Numberformat Number `
                                    -PassThru 3>$null

$StartRow += ($RootDirStats.Length + 3)

If ($RootDirStats.TypeStats) {
    $excel = $RootDirStats.TypeStats | Select-Object @{Name = "File Type"; Expression = {$_.Name}},
                                            @{Name = "Files"; Expression = {$_.Count}},
                                            @{Name = "Size MB"; Expression = {$_.Size.ToString("#.##")}} |
                                            Export-Excel    -ExcelPackage $excel `
                                                            -TableName 'RootTypes' `
                                                            -WorksheetName $WorksheetName `
                                                            -StartRow $StartRow `
                                                            -StartColumn ($StartColumn + 1) `
                                                            -Title "Statistics by File Type" `
                                                            @titleParams `
                                                            -Style $TableStyle `
                                                            -Numberformat Number `
                                                            -AutoSize `
                                                            -PassThru 3>$null

    $StartRow += ($RootDirStats.TypeStats.Length + 3)
}

$Recurse = @{
    Recurse = $false
}

If ($Scope -eq 'SubTree') {
    $Recurse['Recurse'] = $true
}

$ChildFolders = Get-ChildItem -Directory -Path $BaseFolder -Exclude $ExcludeFolders | Get-ChildItem @Recurse

foreach ($ChildFolder in $ChildFolders) {
    Write-Host "Folder: $ChildFolder"
    $Index = $ChildFolders.IndexOf($ChildFolder)
    $ChildFolderStats = Get-FolderStats $ChildFolder.FullName -Recurse 

    $TableName = "FolderStats$Index"
    if ($ChildFolderStats) {
        $excel = $ChildFolderStats | Select-Object @{Name = "Files"; Expression = {$_.Count}},@{Name = "Size MB"; Expression = {$_.Size.ToString("#.##")}},
                                        @{Name = "Files Over 3 Years"; Expression = {$_.ThreeYearFiles}}, @{Name = "Size Over 3 Years"; Expression={$_.ThreeYearSize.ToString("#.##")}},
                                        @{Name = "Files Over 4 Years"; Expression = {$_.FourYearFiles}}, @{Name = "Size Over 4 Years"; Expression={$_.FourYearSize.ToString("#.##")}},
                                        @{Name = "Files Over 5 Years"; Expression = {$_.FiveYearFiles}}, @{Name = "Size Over 5 Years"; Expression={$_.FiveYearSize.ToString("#.##")}} |
                                        Export-Excel    -ExcelPackage $excel `
                                                        -TableName $TableName `
                                                        -WorksheetName $WorksheetName `
                                                        -StartRow $StartRow `
                                                        -StartColumn $StartColumn `
                                                        -Title $ChildFolder.FullName `
                                                        -Style $TableStyle `
                                                        @titleParams `
                                                        -Numberformat Number `
                                                        -AutoSize `
                                                        -PassThru 3>$null

        $StartRow += ($ChildFolderStats.Length + 3)
    }

    $TableName = "FolderTypeStats$Index"
    if ($ChildFolderStats.TypeStats) {        
        $excel = $ChildFolderStats.TypeStats | Select-Object @{Name = "File Type"; Expression = {$_.Name}},
                                                @{Name = "Files"; Expression = {$_.Count}},
                                                @{Name = "Size MB"; Expression = {$_.Size.ToString("#.##")}} |
                                                Export-Excel    -ExcelPackage $excel `
                                                                -TableName $TableName`
                                                                -WorksheetName $WorksheetName `
                                                                -StartRow $StartRow `
                                                                -StartColumn ($StartColumn + 1) `
                                                                -Title "Statistics by File Type" `
                                                                @titleParams `
                                                                -Style $TableStyle `
                                                                -Numberformat Number `
                                                                -AutoSize `
                                                                -PassThru 3>$null
        $StartRow += ($ChildFolderStats.TypeStats.Length + 3)
    }
}

If ($excel) {
    "Completed"
    "Closing Excel Package"
    if ($IsWindows) {
        if ($OpenOnComplete.IsPresent) {
            "Opening Workbook"
            Close-ExcelPackage $excel -Show
        } else{
            Close-ExcelPackage $excel
        }
    } Else {
        "Saving WorkBook. Open in your preferred Spreadsheet application (Note: Libre Calc will lose most formatting)"
        Close-ExcelPackage $excel
    }
}
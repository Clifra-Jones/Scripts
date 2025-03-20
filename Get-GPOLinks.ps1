#Requires -Modules ActiveDirectory, ImportExcel, GroupPolicy
Param(
    [string]$ReportFolder
)

$StartRow = 2

$OUs = Get-ADOrganizationalUnit -Filter *

$reportPath = "{0}\GPOLinks.xlsx" -f $ReportFolder

$excel = Export-Excel -Path $reportPath -WorksheetName "GPOLinks" -ClearSheet -PassThru

$Worksheet = $excel.Workbook.Worksheets["GPOLinks"]

Set-ExcelRange -Worksheet $Worksheet -Range "A1:B1" -Bold -FontSize 11 -BackgroundColor ([system.drawing.color]::CornflowerBlue) 

Set-ExcelRange -Worksheet $Worksheet -Range "A1" -Value "Orgaizational Unit"

Set-ExcelRange -Worksheet $Worksheet -Range "B1" -Value "Linked GPOs"



foreach ($OU in $OUs) {
    $GPInheritance = Get-GPInheritance -Target $OU.DistinguishedName

    if($GPInheritance.GPOLinks.Count -eq 0) {
        Continue
    }
    $Worksheet.Cells.Item($StartRow,1).Value = $GPInheritance.Path


    foreach($gpoLink in $GPInheritance.GPOLinks) {
        
        #$Hyperlink = [OfficeOpenXml.ExcelHyperLink]::New("$encodedFileName.html", $gpoLink.DisplayName)
        #$Hyperlink.DisplayName = $gpoLink.DisplayName
        $formula = '=Hyperlink("{0}.html","{1}")' -f $gpoLink.DisplayName, $gpoLink.DisplayName
        
        $Worksheet.Cells.Item($StartRow,2).Formula = $formula
        Set-ExcelRange -Worksheet $Worksheet -Range ($Worksheet.Cells.Item($StartRow,2)).Address -FontColor Blue -Underline

        $Range = "{0}:{1}" -f $worksheet.Cells.Item($StartRow,1).Address, $Worksheet.Cells.Item($StartRow,2).Address
        if (($StartRow % 2) -eq 0) {        
            Set-ExcelRange -Worksheet $Worksheet -Range $Range -BackgroundColor ([System.Drawing.Color]::LightBlue)
        } else {
            Set-ExcelRange -Worksheet $Worksheet -Range $Range -BackgroundColor ([System.Drawing.Color]::LightCyan)
        }    
        $StartRow += 1
    }

}

$Range = "A1:{0}" -f $Worksheet.Cells.Item($StartRow,2).Address
Set-ExcelRange -Worksheet $Worksheet -Range $Range -AutoSize
$Worksheet.Cells[$Range].AutoFilter = $true
$Worksheet.Cells[$Range].GetEnumerator() | ForEach-Object {
    $_ | Set-ExcelRange -BorderAround Thin -BorderColor Black    
}

Close-ExcelPackage $excel -Show
 
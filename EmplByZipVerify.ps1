#$ErrorActionPreference = "SilentlyContinue"
Get-PSSnapin -Registered | ?{$_.name -like "*quest*"} | Add-PSSnapin

$InputFile = ".\JDEStaffEmpls.csv"
$FoundOutFile = "VerifiedEmployees.csv"
$NotFoundOutFile = "UnverifiedEmployees.csv"

$VerifiedEmployees = New-Object 'System.Collections.Generic.List[psobject]'
$UnverifiedEmployees = New-Object 'System.Collections.Generic.List[psobject]'

$Props = @{
    EmployeeName = ''
    EmployeeNumber = ''
    PostalCode = ''
    Email = ''
}

$Employees = import-csv $InputFile

foreach ($employee in $Employees) {
    $emp = $null
    $UnEmp = $null

    $Alias = $employee."Business Email".split("@")[0]
    $AdAccount = Get-QADUser $Alias -ErrorAction:SilentlyContinue
    if ($AdAccount) {
        "$($employee.'Employee Name') Verified By Email Alias"
        $Emp = New-Object -Property $Props -TypeName:psobject   
        $Emp.EmployeeName = $employee."Employee Name"
        $Emp.EmployeeNumber = $employee."Employee Number"
        $emp.PostalCode = $employee."Work Postal Code"
        $emp.Email = $employee."Business Email"  
    } else {
        $Names = $employee."Employee Name".Split(",")
        if ($Names[0].Contains(" ")) {
            $Alias = $Names[1].substring(1,1) + $Names[0].substring(0, $names[0].indexof(" "))               
        } else {
            $Alias = $Names[1].substring(1,1) + $Names[0]
        }
        $AdAccount = Get-QADUser $Alias -ErrorAction:SilentlyContinue
        If ($AdAccount) {
            $Emp = New-Object -Property $Props -TypeName:psobject   
            $Emp.EmployeeName = $employee."Employee Name"
            $Emp.EmployeeNumber = $employee."Employee Number"
            $emp.PostalCode = $employee."Work Postal Code"
            $emp.Email = $employee."Business Email"                               
        } else {
            $names = $employee."Employee Name".Split(",")
            if ($Names[0].Contains(" ")) {
                $Alias = $Names[1].substring(1,2) + $Names[0].Substring(0, $Names[0].IndexOf(" "))
            } else {
                $Alias = $Names[1].substring(1,2) + $Names[0]
            }
            $AdAccount = Get-QADUser $Alias -ErrorAction:SilentlyContinue
            If ($AdAccount) {
                "$($employee.'Employee Name') verified by 1st 2 initials + lastname."
                $Emp = New-Object -Property $Props -TypeName:psobject   
                $Emp.EmployeeName = $employee."Employee Name"
                $Emp.EmployeeNumber = $employee."Employee Number"
                $emp.PostalCode = $employee."Work Postal Code"
                $emp.Email = $employee."Business Email"                                   
            } else {
                $Names = $employee."Employee Name".Split(",")
                If ($Names[0].Contains(" ")) {
                    $Alias = $Names[1] + $Names[0].Substring(0, $Names[0].IndexOf(" "))
                } else {
                    $Alias = $Names[1] + $Names[0]
                }
                $AdAccount = Get-QADUser $Alias -ErrorAction:SilentlyContinue
                If ($AdAccount) {                        
                    "$($employee.'Employee Name') verified by 1stName  + lastname."
                    $Emp = New-Object -Property $Props -TypeName:psobject   
                    $Emp.EmployeeName = $employee."Employee Name"
                    $Emp.EmployeeNumber = $employee."Employee Number"
                    $emp.PostalCode = $employee."Work Postal Code"
                    $emp.Email = $employee."Business Email"                                                          
                } else {
                    "Searching AD for Employee ID...."
                    $AdAccount = Get-QADUser -IncludedProperties 'EmployeeID' -SearchRoot 'bbc.local/balfourbeattyus/civils' -SizeLimit 0 `
                        | Where-Object{ $_.EmployeeID -eq $employee."Employee Number"}
                    if ($AdAccount) {
                        "$($employee.'Employee Name') Verified by Employee ID"
                        $Emp = New-Object -Property $Props -TypeName:psobject   
                        $Emp.EmployeeName = $employee."Employee Name"
                        $Emp.EmployeeNumber = $employee."Employee Number"
                        $emp.PostalCode = $employee."Work Postal Code"
                        $emp.Email = $employee."Business Email"                           
                    } else {
                        "$($employee.'employee name') unverified!"
                        $UnEmp = New-Object -Property $Props -TypeName:psobject   
                        $UnEmp.EmployeeName = $employee."Employee Name"
                        $UnEmp.EmployeeNumber = $employee."Employee Number"
                        $UnEmp.PostalCode = $employee."Work Postal Code"
                        $UnEmp.Email = $employee."Business Email"                               
                    }
                }
            }
        }
    }

    if ($Emp) {
        "$($Emp.EmployeeName) Added tp verified List"
        $VerifiedEmployees.Add($Emp)
    } else {
        if ($UnEmp) {
            $UnverifiedEmployees.Add($UnEmp)
        } else {
            "$($employee.'Employee Name') missed verification"
        }
    }
}

$VerifiedEmployees.ToArray() | Export-csv $FoundOutFile -NoTypeInformation
$UnverifiedEmployees.ToArray() | Export-Csv $NotFoundOutFile -NoTypeInformation


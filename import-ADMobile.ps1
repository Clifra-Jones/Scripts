Param (
    $filename
)
$ErrorActionPreference = "stop"

function Find-ADUser() {
    Param (
        $Employee
    )
    #Assume Name is First Last
    #try first initial+LastName
    $Username = "{0}{1}" -f $Employee.Firstname.Substring(0,1), $Employee.Lastname
    $adUser = Get-ADUser $Username -ErrorAction SilentlyContinue
    If ($adUser) {
        return $adUser
    }
    
    #fall through if $aduser is null
    #try LastName + First Initial
    $Username ="{0}{1}" -f $Employee.Lastname, $employee.Firstname.Substring(0,1)
    $adUser = Get-Aduser $Username -ErrorAction SilentlyContinue
    if ($adUser) {
        return $adUser
    }

    #fall through if $adUser is null
    #Lets try FirstnameLastname
    $Username = "{0}{1}" -f $employee.Firstname, $employee.Lastname
    $adUser = Get-Aduser $Username -ErrorAction SilentlyContinue
    if ($adUser) {
        return $AdUser
    }

    #Test odd Civils format 1st 2 letters of first name + LastName
    $Username = "{0}{1}" -f $employee.Firstname.Substring(0,2), $employee.LastName
    $adUser = Get-Aduser $Username -ErrorAction SilentlyContinue
    if ($adUser) {
        return $adUser
    }

    #if all fails return false
    return $false
}


if (Test-Path -Path $Filename) {    
    #Assumes file format is: Mobile,Firstname,LastName
    if ((Get-Item -Path $filename).extension -eq '.xlsx') {
        $employees = Import-Excel -Path $Filename
    } else {
        $employees = Import-Csv $filename
    }
    $Exceptions = new-object System.Collections.Generic.List[psobject]
    foreach($employee in $employees) {
        "Processing: {0} {1}" -f $employee.firstname, $employee.lastname
        $adUser = find-Aduser $employee
        if ($aduser) {
            $MobileNumber = [string]::Format("{0:(###) ###-####}", [int64]$employee.Mobile)
            Set-ADUser -identity $adUser.SamAccountName -MobilePhone $MobileNumber
        } else {
          "AD User not found for {0} {1}" -f $Employee.Firstname, $employee.lastname | write-host -fore red
           $Exceptions.Add($employee)
        }
    }
}
$exceptions | export-csv MobilePhoneExceptions.csv -NoTypeInformation

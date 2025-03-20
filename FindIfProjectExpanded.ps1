Param (
    [String]$BucketName,
    [String]$inputFile,
    [String]$ProjectNumber
)

if ($InputFile) {
    $inputProject = import-csv -Path $InputFile
} else {
    $ProjectNumbers = @()
    $ProjectNumbers += $ProjectNumber
}

$s3Folders = Get-S3Folder -BucketName $BucketName -Prefix 'project/'
$S3Folders = $S3Folders | Select-Object @{Name="Key";Expression={$_}}, @{Name="ProjectNumber";Expression={[regex]::match($_, "\[([^\[\]]*)\]").Value.replace("[","").Replace("]","")}}

$Projects = [System.Collections.Generic.List[string]]::New()
Foreach ($inputProject in $inputProjects) {
    $ProjectFolder = $S3Folders.Where({$_.ProjectNumber -eq $inputProject.ProjectNumber})
    if ($ProjectFolder) {
        $Project = Get-S3Object -BucketName $BucketName -Prefix "$input"
        $Project = $Project | Select-Object *, @{Name = "Expanded"; Expression={"True"}}
        $Projects.Add($Project)
    } 
}
Import-Module AWS.Tools.EC2
$Instances = Import-Csv ./AWSInstances.csv

foreach ($Instance in $Instances) {
    #$Instance = (Get-EC2Instance -Region $AWSinstance.Region).Instances.where({$_.InstanceId -eq $AWSinstance.InstanceId})
    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = "backupAction"
    $tag.Value = $Instance.BackupAction
    Remove-EC2Tag -Resource $Instance.InstanceId -Region $Instance.Region -Tag @{Key="BackupAction"} -Confirm:$False
    New-EC2Tag -Resource $Instance.InstanceId -Region $Instance.Region -Tag $Tag
}
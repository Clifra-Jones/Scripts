#Requires -Modules AWS.Tools.EC2, AWS.Tools.S3, AWS.Tools.IdentityManagement, AWS.Tools.WorkSpaces, AWS.Tools.Lambda
#Requires -Modules AWS.Tools.ElasticLoadBalancingV2, AWS.Tools.Workspaces, AWS.Tools.KeyManagementService, ImportExcel

Param (
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [switch] $WhatIf
)

<#
    This script uses a file from AWS Resource Groups > Tag Editor.
    Perform a search for all applicable regions and Resource Types.
    Then export the results including all tags.
    Open the file and edit the column names that begin with "Tag:", remove the space between Tag: and the tag Key name.
    Modify values appropriately for all tags to be applied to a resource.
    Remove any improperly named tags and add in anyTags that do not exist.
    
    Usage:
    When running the script, provide the path to the exported file as the value of the -InputFile parameter.
    If you provide the -WhatIf parameter no updates will be made to teh resources. The commands will just be tested
    for proper execution. 

    This script currently supports the following AWS Services
    EC2::Instances
    S3
    Lambda
    ElasticLoadBalancingV2::LoadBalancer
    Workspaces
    KMS
#>

# Read in the input file
If ($WhatIf.IsPresent) {
    $Param = @{
        WhatIf = $true
    }
} else {
    $Param = @{
        WhatIf = $False
    }
}

if ($InputFile.EndsWith(".xlsx")) {
    $Resources = Import-Excel -Path $InputFile
} elseif ($InputFile.EndsWith(".csv")) {
    $Resources = Import-Csv -Path $InputFile
} else {
    throw "Invalid input file!"
}

#Get a list of services from the import file
$Services = $resources | Sort-Object -Property Service -Unique | Select-Object Service

# Loop through the services and apply tags
foreach ($Service in $Services.Service) {
    # Get the resources for this service
    $ServiceResources = $Resources.where({$_.Service -eq $Service})

    # Loop through the Resources and apply tags
    foreach ($ServiceResource in $ServiceResources) {
        <# Get the new tags for this service resource
           Build a list of the new tags for this resource
           Select all Properties whose name begins with "Tag:" and whose
           value is not "(not tagged)"
           We need to remove the Tag: prefix from the property names
        #> 
        Write-Host "Processing Resource $($ServiceResource.identifier)"

        $NewTags = $ServiceResource.PSObject.Properties.Where({$_.Name -like "Tag: *" -and $_.Value -ne "(not tagged)"}) | `
            Select-Object @{Name="Name"; Expression={$_.Name.Split(": ")[1]}}, Value

        # Now we need to know which Service we are working with.
        Switch ($ServiceResource.Service) {
            "EC2" {
                # We only want instances.
                # While if you only export instances this will not be needed but of the file contains any other EC2
                # resources we need to exclude them
                if ($ServiceResource.Type -eq "Instance") {

                    # Get the current Tags for this instance                
                    $filter = @{
                        Name = "resource-id"
                        Values = $ServiceResource.identifier
                    }
                    $OldTags = Get-EC2Tag -Filter $filter -Region $ServiceResource.region | Select-Object Key, Value                      
                    
                    # Remove the old tags. The new tags were derived from the old tags so any we are not changing will be rewritten
                    # when we add in the new tags.
                    foreach ($OldTag in $OldTags) {     
                        if (-not $OldTag.Key.StartsWith("aws:") ) {
                            Write-Host "Removing EC2:$($ServiceResource.identifier), Tag:$($OldTag.Key)"
                            Remove-EC2Tag -Resource $ServiceResource.identifier -Tag $oldTag -Force @Param -Region $ServiceResource.region  
                        }
                    }

                    # Add the updated tags to the resource.
                    foreach($NewTag in $NewTags) {
                        if (-not $NewTag.Name.StartsWith("aws:") ) {
                            write-host "Adding EC2:$($ServiceResource.Identifier), Tag: $($NewTag.Name)"
                            $Tag = [Amazon.EC2.Model.Tag]::New($NewTag.Name, $NewTag.Value)
                            New-EC2Tag -Resource $ServiceResource.identifier -Tag $Tag -Region $ServiceResource.region @Param
                        }
                    }
                }
            }
            "S3" {      
                # Build an array of Tags                 
                $Tags = [System.Collections.Generic.List[PSObject]]::New()
                foreach ($NewTag in $NewTags) {
                    $Tag = [Amazon.S3.Model.Tag]::New()
                    $Tag.Key = $NewTag.Name
                    $Tag.Value = $NewTag.Value                    
                    $Tags.Add($Tag)
                }
                # Convert the ArrayList to a standard array
                $TagSet = $Tags.ToArray()

                # Write the new Tag set to the bucket
                Write-Host "Writing new tags to S3 Bucket: $($ServiceResource.Identifier)"
                Write-S3BucketTagging -BucketName $ServiceResource.identifier -TagSet $TagSet -Region $ServiceResource.Region @Param
            }
            "Lambda" {
                # Because Lambda requires the full ARN to retrieve the tags we need to get the current account number
                # of the identity we are running under.
                $Acct = (Get-STSCallerIdentity).Account

                # Now build an ARN
                $arn = "arn:aws:lambda:{0}:{1}:function:{2}" -f $ServiceResource.region, $Acct, $ServiceResource.identifier

                # Get the tags from this arn
                $OldTags = Get-LMResourceTag -Resource $arn -Region $ServiceResource.region
                # Create an UnDo Record.

                # Remove the old tags
                # NOTE: Get-LMResourceTag returns a Dictionary object so we geed to use the GetEnumerator() method to step through the tags
                foreach ($OldTag in $OldTags.GetEnumerator()) {
                    If (-not $OldTag.Key.StartsWith("aws:") ) {
                        Write-Host "Removing Lambda:$($ServiceResource.Identifier), Tag: $($OldKey.Key)"
                        Remove-LMResourceTag -Resource $arn -TagKey $OldTag.key -Confirm:$False -Force @Param -Region $ServiceResource.region
                    }
                }

                # Add in the new tags
                # build a hash table of the new tags
                $Tags = @{}
                foreach ($newTag in $NewTags) {
                    if (-not $newTag.Name.StartsWith("aws:") ) {
                        Write-Host "Adding Lambda:$($ServiceResource.Identifier), Tag:$($NewTag.Name)"
                        $Tags.Add($NewTag.Name, $NewTag.Value)
                    }
                }
                # Update the tags

                Add-LMResourceTag -Resource $arn -Tag $Tags @Param -Region $ServiceResource.region
            }
            "ElasticLoadBalancingV2" {
                # Because ELB requires the full ARN to retrieve the tags we nee dto get the current account number
                # of the identity we are running under.
                $Acct = (Get-STSCallerIdentity).Account

                # Now build the arn
                $arn = "arn:aws:elasticloadbalancing:{0}:{1}:loadbalancer/{2}" -f $ServiceResource.region, $Acct, $ServiceResource.identifier
                # Get tags for this arn
                $OldTags = (Get-ELB2Tag -ResourceArn $arn -Region $ServiceResource.region).Tags
                # remove the old tags
                foreach ($oldTag in $OldTags) {
                    if (-not $OldTags.Key.StartsWith("aws:") ) {
                        Write-Host "Removing ELB:$($ServiceResource.Identifier), Tag:$($OldTag.Key)"
                        Remove-ELB2Tag -ResourceArn $Arn -TagKey $OldTag.Key -Force @Param -Region $ServiceResource.region
                    }
                }
                # Add in the new tags                
                foreach ($NewTag in $NewTags) {
                    if (-not $NewTag.Name.StartsWith("aws:") ) {
                        Write-Host "Adding ELB:$($ServiceResource.Identifier), Tag:$($NewTag.Name)"
                        $Tag = [Amazon.ElasticLoadBalancingV2.Model.Tag]::New()
                        $Tag.Key = $NewTag.Name
                        $Tag.Value = $NewTag.Value
                        Add-ELB2Tag -ResourceArn $arn -Tag $Tag @Param -Region $ServiceResource.region
                    }
                }
            }
            "WorkSpaces" {
                # Get the old tags
                $OldTags = Get-WKSTag -WorkspaceId $ServiceResource.identifier -Region $ServiceResource.region
                # Loop through the old tags and remove them
                foreach ($OldTag in $OldTags) {
                    if (-not $OldTag.Key.StartsWith("aws:") ) {
                        Write-Host "Removing Workspace:$($ServiceResource.identifier), Tag:$($OldTag.Key)"
                        Remove-WKSTag -ResourceId $ServiceResource.identifier -TagKey $OldTag.Key -Force @Param -Region $ServiceResource.region
                    }
                }
                # Add in the new tags, excluding any tags with a value of "not tagged)
                foreach($NewTag in $NewTags) {
                    # Create a new Tag object and add Key and value
                    if (-not $NewTag.Name.StartsWith("aws:") ) {
                        Write-Host "Adding Workspace:$($ServiceResource.identifier), Tag:$($NewTag.Name)"
                        $Tag = [Amazon.WorkSpaces.Model.Tag]::New()
                        $Tag.Key = $NewTag.Name
                        $Tag.Value = $NewTag.Value
                        # Add the new tag to the resource
                        New-WKSTag -ResourceId $ServiceResource.identifier -Tag $Tag @Param -Region $ServiceResource.region
                    }
                }
            }
            "KMS" {
                <#
                    KMS does not allow tags on AWS managed KMS Keys.
                    When exporting the KMS tags there is no way to exclude the AWS managed Keys.
                    Therefore we need to prevent processing the AWS managed Keys as trying to retrieve tags for these keys
                    will throw an error.
                    To do this, we can use 2 approaches.
                        1. Remove any AWS managed keys from the input file.
                        2. Skip processing any keys that do not have any tags to apply.
                    In code, we cannot assume that the AWS managed Keys have been removed from the input file so we will
                    test to see if the NewTags array has values and skip processing the resource is it does not!
                #>
                If ($NewTags) {
                    # Get the old tags
                    $OldTags = Get-KMSResourceTag -KeyId $ServiceResource.identifier -Region $ServiceResource.region
                    # Loop through the old tags and Remove them
                    foreach($OldTag in $OldTags) {
                        if ($OldTag.TagKey.StartsWith("aws:") ) {
                            Remove-KMSResourceTag -KeyId $ServiceResource.identifier -TagKey $OldTag.TagKey -Force @Param -Region $ServiceResource.region
                        }
                    }
                    
                    # Add in the new Tags, excluding any tags with a value of "not tagged)"
                    foreach($NewTag in $NewTags) {
                        if (-not $NewTag.Name.StartsWith("aws:") ) {
                            # Create a new TAG object and add Key and Value
                            $Tag = [Amazon.KeyManagementService.Model.Tag]::New()
                            $Tag.TagKey = $NewTag.Name
                            $Tag.TagValue = $NewTag.Value
                            # Add the new tag to the resource
                            Add-KMSResourceTag -KeyId $ServiceResource.identifier -Tag $Tag @Param -Region $ServiceResource.region
                        }
                    }
                }
            }
        }
    }
}
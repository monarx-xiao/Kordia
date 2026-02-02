# Connect to Azure

Import-Module Az.ResourceGraph

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force


#Import-Module Az.Accounts -MinimumVersion 4.2.0 -PassThru

if (-not (Get-AzContext)) {
    Connect-AzAccount -Identity
}



$Get_Subscription = @()
$Get_Subscription_vm = @()
$vm_tags = @()

# Start for querying patching result 
$Get_Subscription = Get-Azsubscription | Select-object name,id

$Get_Subscription | ForEach-Object {
    $default_sub = Select-AzSubscription -Subscription $_.id
# Query for detailed update history with all requested columns
$query = @"
patchinstallationresources
|where type  == 'microsoft.compute/virtualmachines/patchinstallationresults'
| extend operationType = 'Customer Managed Schedules'
| extend maintenanceRunId = properties.maintenanceRunId,
    status = properties.status,
    operationStatusReason = properties.errorDetails.message,
    lastAssessedTime = tostring(properties.lastModifiedDateTime),
    operationStartTime = tostring(properties.startDateTime),
    notSelectedPatchCount = properties.notSelectedPatchCount,
    installedPatchCount = properties.installedPatchCount, 
    excludedPatchCount = properties.excludedPatchCount,
    pendingPatchCount = properties.pendingPatchCount,
    failedPatchCount = properties.failedPatchCount,
    resourceType = 'Azure virtual machine'
| project
    machineName = substring(id,indexof(id,"virtualMachines")+16, indexof(id,"patch")-indexof(id,"virtualMachines")-17),
    maintenance_Run_Id = substring(maintenanceRunId,indexof(maintenanceRunId,"applyupdates")+13),
    status,
    operationStatusReason,
    installedPatchCount,
    notSelectedPatchCount,
    excludedPatchCount,
    pendingPatchCount,
    failedPatchCount,
    updateOperation = 'Install Updates',
    operationType,
    operationStartTime,
    resourceType,
    lastAssessedTime
| union
(patchassessmentresources
|where type == 'microsoft.compute/virtualmachines/patchassessmentresults'
|extend operationType = 'Periodic assessment'
| extend maintenanceRunId = properties.maintenanceRunId,
    status = properties.status,
    operationStatusReason = properties.errorDetails.message,
    lastAssessedTime = tostring(properties.lastModifiedDateTime),
    operationStartTime = tostring(properties.startDateTime),
    resourceType = 'Azure virtual machine'
| project
    machineName = substring(id,indexof(id,"virtualMachines")+16, indexof(id,"patch")-indexof(id,"virtualMachines")-17),
    maintenance_Run_Id = substring(maintenanceRunId,indexof(maintenanceRunId,"applyupdates")+13),
    status,
    operationStatusReason,
    updateOperation = 'Assessment', 
    operationType,
    operationStartTime,
    resourceType,
    lastAssessedTime
)
"@
}

# Execute the query for patching result
$results = Search-AzGraph -Query $query -First 1000

# Virtual Machine details
# Get all enabled subscriptions
$Get_Subscription_vm = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

# Loop through each subscription
foreach ($sub in $Get_Subscription_vm) {
    Set-AzContext -Subscription $sub.Id | Out-Null
    $tenant_id = $sub.TenantId
    $tenant = Get-AzTenant -TenantId $tenant_id 
    $vms = Get-AzVM -Status

    # Collect VM details
    foreach ($vm in $vms) {
        # Format tags as key-value pairs (e.g., "Environment=Prod; Department=IT")
        $tags = if ($vm.Tags) { ($vm.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ' } else { $null }

        # Add VM data to the array
        $vm_tags += [PSCustomObject]@{
            SubscriptionName = $sub.Name
            name             = $vm.Name
            resourcegroup    = $vm.ResourceGroupName
            location         = $vm.Location
            Vm_size          = $vm.HardwareProfile.VmSize
            OS_type          = $vm.StorageProfile.osDisk.osType
            Tags             = $tags
            Status           = $vm.PowerState
            Tenant_name      = $tenant.name
        }
    }
}


# Setup destination storage account
$subscriptionName = "77f2419f-316b-4263-a550-2e9d3393713e"
Set-AzContext -Subscription $subscriptionName

# Define storage parameters
$resourceGroupName = "PowerBI"
$storageAccountName = "emrrunndata"
$containerName = "emr-patching-result"
$jsonBlobName = "patching_result.json"  
$jsonBlobName_vm = "azure_virtual_machine.json"  

# Generate patching result
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $results | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8

# Generate Virtual machine result
$tempFile_vm = [System.IO.Path]::GetTempFileName()
$vm_tags_json = $vm_tags | ConvertTo-Json -Depth 10
$vm_tags_json | Out-File -FilePath $tempFile_vm -Encoding utf8



# Retrieve storage account context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $containerName -Blob $jsonBlobName -Context $context -Force

# Export Virtual machine result to storage account
Set-AzStorageBlobContent -File $tempFile_vm -Container $containerName -Blob $jsonBlobName_vm -Context $context -Force


Write-Host "JSON file uploaded successfully to $jsonBlobName in container $containerName" -ForegroundColor Green

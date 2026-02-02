# Connect to Azure
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

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


# Execute the query
$results = Search-AzGraph -Query $query

$subscriptionName = "77f2419f-316b-4263-a550-2e9d3393713e"
Set-AzContext -Subscription $subscriptionName

# Define storage parameters
$resourceGroupName = "PowerBI"
$storageAccountName = "emrrunndata"
$containerName = "test"
$jsonBlobName = "AzureUpdateManager_result.json"  

$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $results | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8

# Retrieve storage account context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey


Set-AzStorageBlobContent -File $tempFile -Container $containerName -Blob $jsonBlobName -Context $context



Write-Host "JSON file uploaded successfully to $jsonBlobName in container $containerName" -ForegroundColor Green

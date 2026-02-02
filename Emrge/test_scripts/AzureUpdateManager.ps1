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

# Export to CSV
$outputPath = "c:\test\azureupdatemanager.json"
#$formattedResults | Export-Csv -Path $outputPath -NoTypeInformation # -Encoding UTF8
$results | ConvertTo-json | Out-File $outputPath 

Write-Host "Detailed update history report exported to: $outputPath" -ForegroundColor Green


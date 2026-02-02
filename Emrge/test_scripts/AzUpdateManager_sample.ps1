<#
.SYNOPSIS
    Exports Azure Update Manager history to a CSV file.
.DESCRIPTION
    This script connects to Azure, retrieves Update Manager assessment and deployment history,
    and exports it to a CSV file.
.NOTES
    File Name      : Export-AzUpdateManagerHistory.ps1
    Prerequisites  : Azure PowerShell module (Az)
    Version        : 1.0
#>

# Parameters
param (
    [string]$SubscriptionId,
    [string]$ResourceGroupName,
    [string]$MachineName,
    [string]$OutputFilePath = ".\AzureUpdateHistory_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Connect to Azure (if not already connected)
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Select subscription if specified
if ($SubscriptionId) {
    Set-AzContext -Subscription $SubscriptionId | Out-Null
}

try {
    # Get assessment history
    Write-Host "Retrieving update assessment history..."
    $assessments = @()
    
    if ($ResourceGroupName -and $MachineName) {
        $assessments = Get-AzUpdateAssessment -ResourceGroupName $ResourceGroupName -VMName $MachineName
    }
    else {
        $vms = Get-AzVM
        foreach ($vm in $vms) {
            $assessments += Get-AzUpdateAssessment -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name
        }
    }

    # Get update deployment history
    Write-Host "Retrieving update deployment history..."
    $deployments = @()
    
    if ($ResourceGroupName -and $MachineName) {
        $deployments = Get-AzUpdateDeployment -ResourceGroupName $ResourceGroupName -VMName $MachineName
    }
    else {
        $vms = Get-AzVM
        foreach ($vm in $vms) {
            $deployments += Get-AzUpdateDeployment -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name
        }
    }

    # Combine and format data for export
    $exportData = @()
    
    # Process assessments
    foreach ($assessment in $assessments) {
        $exportData += [PSCustomObject]@{
            "RecordType"       = "Assessment"
            "Timestamp"        = $assessment.Timestamp
            "ResourceGroup"    = $assessment.ResourceGroupName
            "MachineName"      = $assessment.VMName
            "CriticalUpdates"  = $assessment.CriticalUpdates
            "SecurityUpdates"  = $assessment.SecurityUpdates
            "OtherUpdates"     = $assessment.OtherUpdates
            "RebootPending"   = $assessment.RebootPending
            "Status"           = $assessment.Status
            "DeploymentName"   = $null
            "UpdateCount"     = $null
            "StartTime"       = $null
            "EndTime"         = $null
        }
    }

    # Process deployments
    foreach ($deployment in $deployments) {
        $exportData += [PSCustomObject]@{
            "RecordType"       = "Deployment"
            "Timestamp"        = $deployment.CreationTime
            "ResourceGroup"    = $deployment.ResourceGroupName
            "MachineName"      = $deployment.VMName
            "CriticalUpdates"  = $null
            "SecurityUpdates"  = $null
            "OtherUpdates"     = $null
            "RebootPending"    = $null
            "Status"           = $deployment.ProvisioningState
            "DeploymentName"   = $deployment.Name
            "UpdateCount"      = $deployment.Updates.Count
            "StartTime"       = $deployment.StartTime
            "EndTime"         = $deployment.EndTime
        }
    }

    # Export to CSV
    $exportData | Sort-Object Timestamp -Descending | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8
    Write-Host "Update history exported to: $OutputFilePath"
}
catch {
    Write-Error "An error occurred: $_"
}
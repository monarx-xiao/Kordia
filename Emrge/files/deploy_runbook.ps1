# Azure Automation Runbook Deployment Script
# This PowerShell script automates the deployment of the CSV merge runbook

# Configuration Parameters
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AutomationAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$SourceStorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$SourceContainerName,
    
    [Parameter(Mandatory=$true)]
    [string]$DestStorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$DestContainerName,
    
    [Parameter(Mandatory=$false)]
    [string]$SourceBlobPrefix = "",
    
    [Parameter(Mandatory=$false)]
    [string]$DestBlobName = "merged_output.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$RunbookName = "MergeCSVFiles",
    
    [Parameter(Mandatory=$false)]
    [string]$RunbookScriptPath = "merge_csv_runbook.py"
)

# Import required modules
Import-Module Az.Automation
Import-Module Az.Storage
Import-Module Az.Resources

Write-Host "Starting deployment process..." -ForegroundColor Green

# 1. Enable Managed Identity if not already enabled
Write-Host "`n1. Checking Managed Identity..." -ForegroundColor Yellow
$automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName

if ($null -eq $automationAccount.Identity) {
    Write-Host "Enabling System-Assigned Managed Identity..." -ForegroundColor Yellow
    Set-AzAutomationAccount -ResourceGroupName $ResourceGroupName `
        -Name $AutomationAccountName `
        -AssignSystemIdentity
    
    # Wait for identity propagation
    Start-Sleep -Seconds 30
    $automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
}

$managedIdentityId = $automationAccount.Identity.PrincipalId
Write-Host "Managed Identity ID: $managedIdentityId" -ForegroundColor Green

# 2. Grant Storage Permissions
Write-Host "`n2. Granting storage permissions..." -ForegroundColor Yellow

# Get storage account resource IDs
$sourceStorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $SourceStorageAccountName
$destStorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $DestStorageAccountName

# Assign Reader role to source storage
Write-Host "Assigning 'Storage Blob Data Reader' to source storage..." -ForegroundColor Yellow
New-AzRoleAssignment -ObjectId $managedIdentityId `
    -RoleDefinitionName "Storage Blob Data Reader" `
    -Scope $sourceStorageAccount.Id `
    -ErrorAction SilentlyContinue

# Assign Contributor role to destination storage
Write-Host "Assigning 'Storage Blob Data Contributor' to destination storage..." -ForegroundColor Yellow
New-AzRoleAssignment -ObjectId $managedIdentityId `
    -RoleDefinitionName "Storage Blob Data Contributor" `
    -Scope $destStorageAccount.Id `
    -ErrorAction SilentlyContinue

Write-Host "Storage permissions granted successfully" -ForegroundColor Green

# 3. Create Automation Variables
Write-Host "`n3. Creating Automation Variables..." -ForegroundColor Yellow

$variables = @{
    "SOURCE_STORAGE_ACCOUNT_NAME" = $SourceStorageAccountName
    "SOURCE_CONTAINER_NAME" = $SourceContainerName
    "SOURCE_BLOB_PREFIX" = $SourceBlobPrefix
    "DEST_STORAGE_ACCOUNT_NAME" = $DestStorageAccountName
    "DEST_CONTAINER_NAME" = $DestContainerName
    "DEST_BLOB_NAME" = $DestBlobName
    "INCLUDE_SOURCE_FILENAME" = "False"
}

foreach ($varName in $variables.Keys) {
    $varValue = $variables[$varName]
    
    # Check if variable exists
    $existingVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $varName `
        -ErrorAction SilentlyContinue
    
    if ($null -eq $existingVar) {
        New-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
            -AutomationAccountName $AutomationAccountName `
            -Name $varName `
            -Value $varValue `
            -Encrypted $false
        Write-Host "Created variable: $varName" -ForegroundColor Green
    } else {
        Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
            -AutomationAccountName $AutomationAccountName `
            -Name $varName `
            -Value $varValue `
            -Encrypted $false
        Write-Host "Updated variable: $varName" -ForegroundColor Green
    }
}

# 4. Import Python Packages
Write-Host "`n4. Python packages need to be imported manually..." -ForegroundColor Yellow
Write-Host "Please import the following packages in Azure Portal:" -ForegroundColor Yellow
Write-Host "  - azure-identity (>=1.15.0)" -ForegroundColor Cyan
Write-Host "  - azure-storage-blob (>=12.19.0)" -ForegroundColor Cyan
Write-Host "  - pandas (>=2.0.0)" -ForegroundColor Cyan
Write-Host "`nNote: Package import via PowerShell is limited. Use Azure Portal for best results." -ForegroundColor Yellow

# 5. Create/Update Runbook
Write-Host "`n5. Creating/Updating Runbook..." -ForegroundColor Yellow

if (-not (Test-Path $RunbookScriptPath)) {
    Write-Host "ERROR: Runbook script not found at: $RunbookScriptPath" -ForegroundColor Red
    exit 1
}

# Check if runbook exists
$existingRunbook = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AutomationAccountName `
    -Name $RunbookName `
    -ErrorAction SilentlyContinue

if ($null -eq $existingRunbook) {
    # Create new runbook
    Import-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Path $RunbookScriptPath `
        -Name $RunbookName `
        -Type Python3 `
        -Description "Merges multiple CSV files from source to destination storage account" `
        -Force
    Write-Host "Runbook created: $RunbookName" -ForegroundColor Green
} else {
    # Update existing runbook
    Import-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Path $RunbookScriptPath `
        -Name $RunbookName `
        -Type Python3 `
        -Force
    Write-Host "Runbook updated: $RunbookName" -ForegroundColor Green
}

# Publish the runbook
Publish-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AutomationAccountName `
    -Name $RunbookName
Write-Host "Runbook published successfully" -ForegroundColor Green

# 6. Summary
Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Import Python packages in Azure Portal (azure-identity, azure-storage-blob, pandas)" -ForegroundColor Cyan
Write-Host "2. Wait 5-10 minutes for role assignments to propagate" -ForegroundColor Cyan
Write-Host "3. Test the runbook by clicking 'Start' in Azure Portal" -ForegroundColor Cyan
Write-Host "4. (Optional) Create a schedule to run the runbook automatically" -ForegroundColor Cyan

Write-Host "`nRunbook Name: $RunbookName" -ForegroundColor White
Write-Host "Source: $SourceStorageAccountName/$SourceContainerName" -ForegroundColor White
Write-Host "Destination: $DestStorageAccountName/$DestContainerName/$DestBlobName" -ForegroundColor White

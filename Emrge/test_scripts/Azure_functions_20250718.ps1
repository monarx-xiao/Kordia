# Connect to Azure

Import-Module Az.ResourceGraph

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force


#Import-Module Az.Accounts -MinimumVersion 4.2.0 -PassThru

if (-not (Get-AzContext)) {
    Connect-AzAccount -Identity
}

$Get_Subscription_func = @()
$func_tags = @()

# 1 # Get Azure functions detail
# Get all enabled subscriptions
$Get_Subscription_func = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

# Loop through each subscription
foreach ($sub in $Get_Subscription_func) {
    Set-AzContext -Subscription $sub.Id | Out-Null
    $tenant_id = $sub.homeTenantId
#    $tenant = Get-AzTenant -TenantId $tenant_id 
    $funcs = Get-AzFunctionApp
    
    # Collect Azure function details, add Azure function data to the array
    foreach ($func in $funcs) {
        $func_setting = Get-AzFunctionAppSetting -Name $func.Name -ResourceGroupName $func.ResourceGroupName

            $func_tags += [PSCustomObject]@{
                SubscriptionName = $sub.Name
                Function_name    = $func.Name
                OS_Type          = $func.OSType
                resourcegroup    = $func.ResourceGroupName
                location         = $func.Location
                Status           = $func.Status
                Runtime          = $func_setting.FUNCTIONS_WORKER_RUNTIME
                Runtime_version  = $func_setting.FUNCTIONS_EXTENSION_VERSION
                Service_Plan     = $func.AppServicePlan 
                Tenant_id        = $tenant_id
            }
    }
}

# 2 $ Export result: Setup destination storage account
$subscriptionName = "77f2419f-316b-4263-a550-2e9d3393713e"
Set-AzContext -Subscription $subscriptionName

# Define storage parameters
$resourceGroupName = "PowerBI"
$storageAccountName = "emrrunndata"
$containerName = "emr-patching-result"
$jsonBlobName_func = "azure_functions.json"  

# Generate Azure function result
$tempFile_func = [System.IO.Path]::GetTempFileName()
$func_tags_json = $func_tags | ConvertTo-Json -Depth 10
$func_tags_json | Out-File -FilePath $tempFile_func -Encoding utf8


# Retrieve storage account context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

# Export Azure function result to storage account
Set-AzStorageBlobContent -File $tempFile_func -Container $containerName -Blob $jsonBlobName_func -Context $context -Force

Write-Host "JSON file uploaded successfully to $jsonBlobName_func in container $containerName" -ForegroundColor Green

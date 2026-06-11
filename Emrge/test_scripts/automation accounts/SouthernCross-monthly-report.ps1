# Connect to Azure
#Import-Module Az.ResourceGraph
#Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
#Import-Module Az.Accounts -MinimumVersion 4.2.0 -PassThru

if (-not (Get-AzContext)) {
    Connect-AzAccount -Identity
}

$Get_Subscription_vm = @()
$Get_Subscription_sqlserver = @()
$vm_tags = @()
$sql_tags = @()
$tenant_subs = @()

$tmpDate = (Get-date).AddDays((Get-date).Day * -1)
$RptDate = $tmpDate.toString("MM/dd/yyyy HH:mm:ss")  
$RptNamePrefix = $tmpDate.toString("yyyy-MM")

$RptSubscriptionTable = @()
$RptResourceGroupTable = @()
$RptFrontDoorTable = @()
$RptFrontDoorFrontendEndpointTable = @()
$RptAzFrontDoorWafPolicyTable = @()
$RptFrontDoorAzDiagnosticSettingTable = @()
$RptApplicationGatewayTable = @()
$RptApplicationGatewayFirewallPolicyTable = @()
$RptApplicationGatewayTable_Raw = @()
$RptApplicationGatewayListenerTable = @()
$RptApplicationGatewayListenerObject = @()
$RptFrontDoorDetailTable = @()

$RptSentinelTable = @()
$RptSentinelTopAppGatewayTable = @()
$RptSentinelTopIPTable = @()
$RptSentinelTopIPTablebyRule = @()
$RptSentinelTopRuleGroupTable = @()
$RptSentinelTopURITable = @()

# Get Subscription Table
# $RptSubscriptionTable = Get-AzSubscription | where-object Name -like "*southern cross*" || TenantId in ("fda0bafb-ea98-45e0-97a4-e0d6073f7289","91700184-c314-4dc9-bb7e-a411df456a1e") | Select-Object @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}}, Name, Id, TenantId, State, HomeTenantId, SubscriptionPolicies, ExtendedProperties, AuthorizationSource, Tags
$RptSubscriptionTable = Get-AzSubscription | where-object Name -like "*southern cross*" | Select-Object @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}}, Name, Id, TenantId, State, HomeTenantId, SubscriptionPolicies, ExtendedProperties, AuthorizationSource, Tags

$RptSubscriptionTable | ForEach-Object {
    $RptDefaultSub = Select-AzSubscription -Subscription $_.Id
# Get ResourceGroup Table
    $RptResourceGroupObject = Get-azresourcegroup
    $RptSubscriptionId = $_.Id
    $RptResourceGroupTable += $RptResourceGroupObject | Select-Object -property @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}}, ResourceGroupName, Location, ProvisioningState, ResourceId, Tags 
# Get Front Door Table
    $RptFrontDoorObject = get-AzResource -ResourceType Microsoft.Network/frontdoors 
    $RptFrontDoorTable += $RptFrontDoorObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},SubscriptionId, ResourceGroupName, Name, ResourceType, Location, ResourceId, Tags 
    $RptFrontDoorDetailObject = Get-AzFrontDoor
    $RptFrontDoorDetailTable += $RptFrontDoorDetailObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}}, ResourceGroupName, FriendlyName, FrontDoorId, RoutingRules, BackendPools, BackendPoolsSetting, EnforceCertificateNameCheck, HealthProbeSettings, LoadBalancingSettings, FrontendEndpoints, EnabledState, ResourceState, ProvisioningState, Cname, RulesEngine, Tags, Id, Name, Type
# Get Microsoft.Network/applicationGateways Table
    $RptApplicationGatewayObject = Get-AzApplicationGateway
    $RptApplicationGatewayTable += $RptApplicationGatewayObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}}, ResourceGroupName, Name, Location, Id, Sku, Type, {$_.FirewallPolicy.Id}, SslPolicy, GatewayIPConfigurations, HttpListeners, Listeners, OperationalState, ProvisioningState, Tag, Etag
# Get WAF Table
    $RptApplicationGatewayFirewallPolicyObject = Get-AzApplicationGatewayFirewallPolicy
    $RptApplicationGatewayFirewallPolicyTable += $RptApplicationGatewayFirewallPolicyObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}}, ResourceGroupName, Name, Location, Id, Type, CustomRules, PolicySettings, ManagedRules, CustomBlockResponseStatusCode, CustomBlockResponseBody, Tag, Etag 
}
# Get Front Door Frontend Endpoint Table
$RptFrontDoorTable | ForEach-Object {
    $RptDefaultSub = Select-AzSubscription -Subscription $_.SubscriptionId
    $RptFronDoorName = $_.Name
    $RptResourceGroupName = $_.ResourceGroupName
    $RptSubscriptionId = $_.SubscriptionId
    $RptFrontDoorFrontendEndpointObject = Get-AzFrontDoorFrontendEndpoint -ResourceGroupName $RptResourceGroupName -FrontDoorName $RptFronDoorName
    $RptFrontDoorFrontendEndpointTable += $RptFrontDoorFrontendEndpointObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}},@{l="ResourceGroupName";e={$RptResourceGroupName}}, @{l="FrontDoorName";e={$RptFronDoorName}} , Name, HostName, SessionAffinityEnabledState, SessionAffinityTtlSeconds, WebApplicationFirewallPolicyLink, Backends, CustomHttpsProvisioningState, CertificateSource, ProtocolType, MinimumTlsVersion, Vault, SecretName, SecretVersion, CertificateType, ResourceState, Id, Type

    $RptAzFrontDoorWafPolicyObject = Get-AzFrontDoorWafPolicy -ResourceGroupName $RptResourceGroupName
    $RptAzFrontDoorWafPolicyTable += $RptAzFrontDoorWafPolicyObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}},@{l="ResourceGroupName";e={$RptResourceGroupName}}, @{l="FrontDoorName";e={$RptFronDoorName}} , Name, PolicyMode, PolicyEnabledState, RedirectUrl, CustomBlockResponseStatusCode, CustomBlockResponseBody, RequestBodyCheck, CustomRules, ManagedRules, Etag, ProvisioningState, Sku, Tags, Id,Type

    $RptResourceID = $_.ResourceId
    $RptFrontDoorAzDiagnosticSettingObject = Get-AzDiagnosticSetting -ResourceId $RptResourceID
    $RptFrontDoorAzDiagnosticSettingTable += $RptFrontDoorAzDiagnosticSettingObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}},@{l="ResourceGroupName";e={$RptResourceGroupName}}, @{l="FrontDoorName";e={$RptFronDoorName}} , Name

  }

  # Get Application Gateway Listener Table
$RptApplicationGatewayTable | ForEach-Object {
    $RptDefaultSub = Select-AzSubscription -Subscription $_.SubscriptionId
    $RptApplicationGatewayName = $_.Name
    $RptResourceGroupName = $_.ResourceGroupName
    $RptSubscriptionId = $_.SubscriptionId
    $RptApplicationGatewayObject = Get-AzApplicationGateway -ResourceGroupName $RptResourceGroupName -Name $RptApplicationGatewayName
    $RptApplicationGatewayListenerObject = Get-AzApplicationGatewayHttpListener -ApplicationGateway $RptApplicationGatewayObject  | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}},@{l="ResourceGroupName";e={$RptResourceGroupName}}, @{l="ApplicationGatewayName";e={$RptApplicationGatewayName}}, Name, HostName, HostNames, Protocol, RequireServerNameIndication, ProvisioningState, Type, FrontendIpConfigurationText, FrontendPortText, SslCertificateText, SslProfileText, FirewallPolicyText, Etag, Id
    $RptApplicationGatewayListenerTable += $RptApplicationGatewayListenerObject

    $RptApplicationGatewayTable_Raw += $RptApplicationGatewayObject | Select-Object -property  @{l="Report Date";e={$RptDate}},@{l="Report Prefix";e={$RptNamePrefix}},@{l="SubscriptionId";e={$RptSubscriptionId}}, ResourceGroupName, Name, Location, Id, Sku, Type, {$_.FirewallPolicy.Id}, SslPolicy, GatewayIPConfigurations, HttpListeners, Listeners, OperationalState, ProvisioningState, Tag, Etag,@{l="FWEnabled";e={$_.WebApplicationFirewallConfiguration.Enabled}},@{l="FWMode";e={$_.WebApplicationFirewallConfiguration.FirewallMode}},@{l="FWRuleSetType";e={$_.WebApplicationFirewallConfiguration.RuleSetType}},@{l="FWRuleSetVersion";e={$_.WebApplicationFirewallConfiguration.RuleSetVersion}},@{l="SkuName";e={$_.Sku.Name}},@{l="SkuTier";e={$_.Sku.Tier}},@{l="SkuCapacity";e={$_.Sku.Capacity}}    
  }

#*******************************************
#RptSentinelTable
Set-AzContext -Subscription “36b7fcb3-0f52-4115-971a-e9ae8524715a"
$WorkspaceID = "aa8dded8-f260-4e44-ac7a-f2c4628b57b7"
$toDD = $tmpDate.toString("dd")

for ($i = 1; $i -le 3; $i++ )
{
    switch($i){
        1 {$frmDay="01";$toDay="10";}
        2 {$frmDay="11";$toDay="20";}
        3 {$frmDay="21";$toDay=$toDD;}
    }
    $query = 'let lastmonth = getmonth(datetime(now)) -1;
        let year = getyear(datetime(now)); 
        let RptDate="' + $RptNamePrefix + '";
        AzureDiagnostics
        | where TimeGenerated >= make_datetime(year,lastmonth,' + $frmDay + ',0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDay + ',23,59,59.9999)
        | where Category in ("ApplicationGatewayFirewallLog","ApplicationGatewayAccessLog","FrontdoorWebApplicationFirewallLog","FrontdoorAccessLog")
        | summarize count() by bin(TimeGenerated, 1d), Category, ResourceGroup, SubscriptionId, ResourceProvider, Resource, ResourceType, OperationName, ruleSetType_s, ruleSetVersion_s, ruleGroup_s, action_s, site_s, ResourceId,Message, ruleName_s, RptDate'
    
#    $query
    $kqlQuery = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $query
    $RptSentinelTable += $kqlQuery.Results
}


#RptSentinelTopAppGatewayTable
$query = 'let lastmonth = getmonth(datetime(now)) -1;
let year = getyear(datetime(now)); 
AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where Category in ("ApplicationGatewayFirewallLog","ApplicationGatewayAccessLog")
| summarize count() by ResourceId, action_s, SubscriptionId, ResourceGroup, Resource, OperationName, Category, Prefix="'+ $RptNamePrefix + '"'

$kqlQuery = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $query
$RptSentinelTopAppGatewayTable += $kqlQuery.Results

#RptSentinelTopIPTable
$query = 'let lastmonth = getmonth(datetime(now)) -1;
let year = getyear(datetime(now)); 
(AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize Count=count() by clientIp_s, action_s, Prefix="'+ $RptNamePrefix + '"
| top 20 by Count desc)
| union
(AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s == "Matched"
| summarize Count=count() by clientIp_s, action_s, Prefix="'+ $RptNamePrefix + '"
| top 20 by Count desc)
| union
(AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s == "Detected"
| summarize Count=count() by clientIp_s, action_s, Prefix="'+ $RptNamePrefix + '"
| top 20 by Count desc)'


$kqlQuery = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $query
$RptSentinelTopIPTable += $kqlQuery.Results

#RptSentinelTopIPTablebyRule

$query = 'let lastmonth = getmonth(datetime(now)) -1;
let year = getyear(datetime(now)); 
let TopIPs=
(AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize Count=count() by clientIp_s, action_s
| top 20 by Count desc
| project clientIp_s)
| union
(AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s == "Matched"
| summarize Count=count() by clientIp_s, action_s
| top 20 by Count desc
| project clientIp_s)
| union
(AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s == "Detected"
| summarize Count=count() by clientIp_s, action_s
| top 20 by Count desc
| project clientIp_s);
AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where action_s in ("Blocked","Detected","Matched")
| where clientIp_s in (TopIPs)
| summarize count() by clientIp_s, details_file_s, action_s, SubscriptionId, ResourceGroup, Resource, OperationName, Category, Prefix="'+ $RptNamePrefix + '", bin(TimeGenerated, 1d)'

$kqlQuery = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $query
$RptSentinelTopIPTablebyRule += $kqlQuery.Results

#RptSentinelTopRuleGroupTable


$query = 'let lastmonth = getmonth(datetime(now)) -1;
let year = getyear(datetime(now)); 
let TopRuleId=
AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where details_file_s contains "/REQUEST-"
| summarize Count=count() by details_file_s
| top 20 by Count desc
| project details_file_s;
AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where details_file_s in (TopRuleId)
| summarize count() by details_file_s, action_s, SubscriptionId, ResourceGroup, Resource, OperationName, Category, Prefix="'+ $RptNamePrefix + '", bin(TimeGenerated, 1d)'

$kqlQuery = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $query
$RptSentinelTopRuleGroupTable += $kqlQuery.Results

#RptSentinelTopURITable

$query = 'let lastmonth = getmonth(datetime(now)) -1;
let year = getyear(datetime(now)); 
let x = 
(AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s in ("Blocked","Detected","Matched")
| summarize Count=count() by requestUri_s, hostname_s
| top 20 by Count desc
| project requestUri_s
);
AzureDiagnostics
| where TimeGenerated >= make_datetime(year,lastmonth,1,0,0,0) and TimeGenerated <= make_datetime(year,lastmonth,' + $toDD + ',23,59,59.9999)
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| where action_s in ("Blocked","Detected","Matched")
| where requestUri_s in (x)
| summarize count() by requestUri_s, hostname_s, details_file_s, action_s, Prefix="'+ $RptNamePrefix + '"'

$kqlQuery = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $query
$RptSentinelTopURITable += $kqlQuery.Results

#*******************************************



# 3 $ Export result: Setup destination storage account
$subscriptionName = "77f2419f-316b-4263-a550-2e9d3393713e"
Set-AzContext -Subscription $subscriptionName

# Define storage parameters
$export_resourceGroupName = "PowerBI"
$export_storageAccountName = "etppowerbisa"
$export_containerName = "sc-data-json"

$export_jsonBlobName = "vm.json"  

$export_jsonBlobName_RptApplicationGatewayFirewallPolicyTable = "RptApplicationGatewayFirewallPolicyTable.json"
$export_jsonBlobName_RptApplicationGatewayListenerTable = "RptApplicationGatewayListenerTable.json"
$export_jsonBlobName_RptApplicationGatewayTable = "RptApplicationGatewayTable.json"
$export_jsonBlobName_RptApplicationGatewayTable_Raw = "RptApplicationGatewayTable_Raw.json"
$export_jsonBlobName_RptAzFrontDoorWafPolicyTable = "RptAzFrontDoorWafPolicyTable.json"
$export_jsonBlobName_RptFrontDoorAzDiagnosticSettingTable = "RptFrontDoorAzDiagnosticSettingTable.json"
$export_jsonBlobName_RptFrontDoorDetailTable = "RptFrontDoorDetailTable.json"
$export_jsonBlobName_RptFrontDoorFrontendEndpointTable = "RptFrontDoorFrontendEndpointTable.json"
$export_jsonBlobName_RptFrontDoorTable = "RptFrontDoorTable.json"
$export_jsonBlobName_RptResourceGroupTable = "RptResourceGroupTable.json"
$export_jsonBlobName_RptSubscriptionTable = "RptSubscriptionTable.json"

$export_jsonBlobName_RptSentinelTable = "RptSentinelTable.json"
$export_jsonBlobName_RptSentinelTopAppGatewayTable = "RptSentinelTopAppGatewayTable.json"
$export_jsonBlobName_RptSentinelTopIPTable = "RptSentinelTopIPTable.json"
$export_jsonBlobName_RptSentinelTopIPTablebyRule = "RptSentinelTopIPTablebyRule.json"
$export_jsonBlobName_RptSentinelTopRuleGroupTable = "RptSentinelTopRuleGroupTable.json"
$export_jsonBlobName_RptSentinelTopURITable = "RptSentinelTopURITable.json"


# Generate RptSubscriptionTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptSubscriptionTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptSubscriptionTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptSubscriptionTable in container $export_containerName" -ForegroundColor Green

# Generate RptApplicationGatewayFirewallPolicyTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptApplicationGatewayFirewallPolicyTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptApplicationGatewayFirewallPolicyTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptApplicationGatewayFirewallPolicyTable in container $export_containerName" -ForegroundColor Green

# Generate RptApplicationGatewayListenerTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptApplicationGatewayListenerTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptApplicationGatewayListenerTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptApplicationGatewayListenerTable in container $export_containerName" -ForegroundColor Green

# Generate RptApplicationGatewayTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptApplicationGatewayTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptApplicationGatewayTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptApplicationGatewayTable in container $export_containerName" -ForegroundColor Green

# Generate RptApplicationGatewayTable_Raw
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptApplicationGatewayTable_Raw | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptApplicationGatewayTable_Raw -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptApplicationGatewayTable_Raw in container $export_containerName" -ForegroundColor Green

# Generate RptAzFrontDoorWafPolicyTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptAzFrontDoorWafPolicyTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptAzFrontDoorWafPolicyTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptAzFrontDoorWafPolicyTable in container $export_containerName" -ForegroundColor Green

# Generate RptFrontDoorAzDiagnosticSettingTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptFrontDoorAzDiagnosticSettingTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptFrontDoorAzDiagnosticSettingTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptFrontDoorAzDiagnosticSettingTable in container $export_containerName" -ForegroundColor Green

# Generate RptFrontDoorDetailTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptFrontDoorDetailTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptFrontDoorDetailTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptFrontDoorDetailTable in container $export_containerName" -ForegroundColor Green

# Generate RptFrontDoorFrontendEndpointTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptFrontDoorFrontendEndpointTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptFrontDoorFrontendEndpointTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptFrontDoorFrontendEndpointTable in container $export_containerName" -ForegroundColor Green

# Generate RptFrontDoorTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptFrontDoorTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptFrontDoorTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptFrontDoorTable in container $export_containerName" -ForegroundColor Green

# Generate RptResourceGroupTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptResourceGroupTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptResourceGroupTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptResourceGroupTable in container $export_containerName" -ForegroundColor Green

# Generate RptSentinelTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptSentinelTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptSentinelTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptSentinelTable in container $export_containerName" -ForegroundColor Green

# Generate RptSentinelTopAppGatewayTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptSentinelTopAppGatewayTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptSentinelTopAppGatewayTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptSentinelTopAppGatewayTable in container $export_containerName" -ForegroundColor Green

# Generate RptSentinelTopIPTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptSentinelTopIPTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptSentinelTopIPTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptSentinelTopIPTable in container $export_containerName" -ForegroundColor Green

# Generate RptSentinelTopIPTablebyRule
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptSentinelTopIPTablebyRule | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptSentinelTopIPTablebyRule -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptSentinelTopIPTablebyRule in container $export_containerName" -ForegroundColor Green

# Generate RptSentinelTopRuleGroupTable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptSentinelTopRuleGroupTable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptSentinelTopRuleGroupTable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptSentinelTopRuleGroupTable in container $export_containerName" -ForegroundColor Green

# Generate RptSentinelTopURITable
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonData = $RptSentinelTopURITable | ConvertTo-Json -Depth 10
$jsonData | Out-File -FilePath $tempFile -Encoding utf8
# Retrieve storage account context
$export_storageAccount = Get-AzStorageAccount -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $export_resourceGroupName -Name $export_storageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $export_storageAccountName -StorageAccountKey $storageKey
# Export patching result to storage account
Set-AzStorageBlobContent -File $tempFile -Container $export_containerName -Blob $export_jsonBlobName_RptSentinelTopURITable -Context $context -Force
Write-Host "JSON file uploaded successfully to $export_jsonBlobName_RptSentinelTopURITable in container $export_containerName" -ForegroundColor Green

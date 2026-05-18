# Define variables
$subscriptionId = "caa9e6b5-6dc6-43c1-9dec-1e1d8666547d"
$resourceGroupName = "seasqldbsharedrg"
$serverName = "sea-sql-server.database.windows.net"
$outputPath = "C:\test\sealink_firewall.csv" 

# Select the correct subscription
Select-AzSubscription -SubscriptionId $subscriptionId

# Get firewall rules for the specified SQL server and export to CSV
Get-AzSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $serverName | 
    Select-Object @{Name='ServerName'; Expression={$serverName}}, StartIpAddress, EndIpAddress, FirewallRuleName |
    Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Firewall rules exported to: $outputPath"
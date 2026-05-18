Connect-AzAccount

# Optional: Set subscription
Set-AzContext -Subscription "caa9e6b5-6dc6-43c1-9dec-1e1d8666547d"

# Get all SQL servers
$servers = Get-AzSqlServer

# Collect firewall rules
$rules = foreach ($server in $servers) {
    Get-AzSqlServerFirewallRule `
        -ResourceGroupName $server.ResourceGroupName `
        -ServerName $server.ServerName |
    Select-Object ServerName, FirewallRuleName, StartIpAddress, EndIpAddress
}

# Export to CSV
$rules | Export-Csv "C:\test\sealink_fw.csv" -NoTypeInformation

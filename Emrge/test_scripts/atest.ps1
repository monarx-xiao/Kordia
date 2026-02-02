# Connect to Azure
Connect-AzAccount

# Set variables
$SubscriptionId = "77f2419f-316b-4263-a550-2e9d3393713e"
$ResourceGroup = "PowerBI"
$AutomationAccount = "emrge-scripts"
$RunAsAccountName = "AzureRunAsAccount"

# Select subscription
Set-AzContext -SubscriptionId $SubscriptionId

# Create a Run As Account
New-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $AutomationAccount -Location "Australia East "
New-AzAutomationRunAsAccount -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Name $RunAsAccountName
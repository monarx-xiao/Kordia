using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "Processing Jira worklogs on all issues."

$client_id = 'svc_jira_api@emrge.co.nz'
$client_secret = '52!pIw2NHc%pdgIu'
$base64_auth_info = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $client_id,$client_secret)))

$issue_full_list = @()
$issue_list = ' '

while ($issue_list)   
{

  $issue_list = (Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $base64_auth_info)} "https://emergingtechnologypartners.atlassian.net/rest/api/3/search/jql?jql=project=SD&fields=resolution,status,issuetype,created,resolutiondate,customfield_10002,labels,summary,worklog&nextPageToken=").issues

  $issue_full_list += $issue_list
}

$issue_full_list | Export-Csv -Path "C:\test\jira20260122.csv" -NoTypeInformation





#if (!$issue_full_list) {
#    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
#        StatusCode = [HttpStatusCode]::BadRequest
#        Body = "There was an error while pulling worklog data from Jira."
#    })
#}

#$full_worklog_report_csv = $issue_full_list | ConvertTo-Csv -NoTypeInformation -Delimiter ","
#Push-OutputBinding -Name outputBlob -value ($full_worklog_report_csv -join "`n")
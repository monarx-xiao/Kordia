using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "Processing Jira worklogs on all issues."

$client_id = (Get-Childitem env: | Where-Object {$_.Name -eq "JIRA_EMRGE_API_USER"}).Value
$client_secret = (Get-Childitem env: | Where-Object {$_.Name -eq "JIRA_EMRGE_API_SECRET"}).Value

$base64_auth_info = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $client_id,$client_secret)))

$start_at = 0
$issue_full_list = @()
$issue_list = (Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $base64_auth_info)} "https://emergingtechnologypartners.atlassian.net/rest/api/3/search?jql=project=SD&startAt=$($start_at)&maxResults=100").issues
$issue_full_list += $issue_list

while ($issue_list) {
  $start_at += 100
  $issue_list = (Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $base64_auth_info)} "https://emergingtechnologypartners.atlassian.net/rest/api/3/search?jql=project=SD&startAt=$($start_at)&maxResults=100").issues
  $issue_full_list += $issue_list
}

$full_worklog_report = foreach ($issue in $issue_full_list) {
    $issue_key = $issue.key
    $issue_description = $issue.fields.summary
    $issue_organisation = $issue.fields.customfield_10002.name

    $worklogs = (Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $base64_auth_info)} "https://emergingtechnologypartners.atlassian.net/rest/api/3/issue/$($issue_key)/worklog?expand=comment").worklogs

    if ($worklogs) {
        foreach ($worklog in $worklogs) {
            if ($worklog.comment.content.type -eq "bulletList") {
                $description = ($worklog.comment.content.content.content.content.text | ForEach-Object { if ($_) { "* $($_)" }}) -join "`n"
            } elseif ($worklog.comment.content.type -eq "paragraph") {
                $description = "* $($worklog.comment.content.content.text)"
            }

            $worklog_started_nzt = ([DateTime]$worklog.started).AddHours(12).ToString('yyyy/MM/dd HH:mm:ss')

            "" | select @{N="Organisation";E={$issue_organisation}}, @{N="Ticket ID";E={$issue_key}}, @{N="Ticket Summary";E={$issue_description}}, @{N="Resource";E={$worklog.author.displayName}}, @{N="Started At";E={$worklog_started_nzt}}, @{N="Worklog Description";E={$description}}, @{N="Time Spent (hours)";E={($worklog.timeSpentSeconds)/3600}}

            $description = ""
        }
    }
}

if (!$full_worklog_report) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = "There was an error while pulling worklog data from Jira."
    })
}

$full_worklog_report_csv = $full_worklog_report | ConvertTo-Csv -NoTypeInformation -Delimiter ","
Push-OutputBinding -Name outputBlob -value ($full_worklog_report_csv -join "`n")

# $full_worklog_report_json = $full_worklog_report | ConvertTo-Json

# Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
#     StatusCode = [HttpStatusCode]::OK
#     Body = $full_worklog_report_json
# })

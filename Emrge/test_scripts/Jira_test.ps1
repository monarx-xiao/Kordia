# For Jira Cloud
$email = "svc_jira_api@emrge.co.nz"
$apiToken = "52!pIw2NHc%pdgIu"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $email, $apiToken)))

$jiraBaseUrl = "https://emergingtechnologypartners.atlassian.net/"
$issueKey = "SD-8509"
#$apiUrl = "$jiraBaseUrl/rest/api/3/issue/$issueKey"
$apiUrl = "https://emergingtechnologypartners.atlassian.net/rest/api/3/search/jql?jql=project=SD&fields=resolution,status,issuetype,created,resolutiondate,customfield_10002,labels,summary,worklog&maxResults=1"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json" -Headers @{
        'Authorization' = "Basic $base64AuthInfo"
    }
    Write-Host "SUCCESS! You have access to issue $issueKey." -ForegroundColor Green
    # To see the raw JSON response, convert it back
    # $response | ConvertTo-Json -Depth 10
}
catch {
    Write-Host "FAILED!" -ForegroundColor Red
    # Parse the error response for details
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription
    Write-Host "HTTP Error: $statusCode ($statusDescription)" -ForegroundColor Red
    
    # Try to read the error stream for more info from Jira
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $errorBody = $reader.ReadToEnd()
        Write-Host "Message from Jira: $errorBody" -ForegroundColor Yellow
    }
}
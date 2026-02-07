# Azure Automation Runbook: CSV Merge Setup Guide

## Prerequisites

1. **Azure Automation Account** created
2. **Two Storage Accounts** (source and destination)
3. **System-assigned Managed Identity** enabled on the Automation Account
4. **Python 3.8+ runtime** configured in Automation Account

## Step 1: Enable Managed Identity

1. Go to your Automation Account in Azure Portal
2. Navigate to **Identity** under Settings
3. Enable **System assigned** managed identity
4. Note the **Object (principal) ID** for the next step

## Step 2: Grant Storage Permissions

The Automation Account's managed identity needs permissions to access both storage accounts.

### For Source Storage Account:
```bash
# Assign "Storage Blob Data Reader" role
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee <MANAGED_IDENTITY_OBJECT_ID> \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Storage/storageAccounts/<SOURCE_STORAGE_ACCOUNT>
```

### For Destination Storage Account:
```bash
# Assign "Storage Blob Data Contributor" role
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <MANAGED_IDENTITY_OBJECT_ID> \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Storage/storageAccounts/<DEST_STORAGE_ACCOUNT>
```

**Alternative: Use Azure Portal**
1. Go to Source Storage Account → Access Control (IAM)
2. Click "Add role assignment"
3. Select "Storage Blob Data Reader" role
4. Select "Managed Identity" and choose your Automation Account
5. Repeat for Destination Storage Account with "Storage Blob Data Contributor" role

## Step 3: Install Required Python Packages

Azure Automation requires Python packages to be imported.

1. Go to your Automation Account
2. Navigate to **Python packages** under Shared Resources
3. Import the following packages:
   - `azure-identity` (version 1.15.0 or later)
   - `azure-storage-blob` (version 12.19.0 or later)
   - `pandas` (version 2.0.0 or later)

**To import a package:**
- Click "+ Add a Python package"
- Select Python version (3.8 or 3.10)
- Upload the wheel file or provide PyPI package name

**Note:** You may need to download .whl files from PyPI and upload them if direct import doesn't work.

## Step 4: Create Automation Variables

Configure the following variables in your Automation Account:

1. Go to **Variables** under Shared Resources
2. Create the following variables:

| Variable Name | Type | Value | Description |
|---------------|------|-------|-------------|
| SOURCE_STORAGE_ACCOUNT_NAME | String | your-source-account | Source storage account name |
| SOURCE_CONTAINER_NAME | String | source-container | Source container name |
| SOURCE_BLOB_PREFIX | String | (optional) | Filter blobs by prefix, e.g., "data/" |
| DEST_STORAGE_ACCOUNT_NAME | String | your-dest-account | Destination storage account name |
| DEST_CONTAINER_NAME | String | dest-container | Destination container name |
| DEST_BLOB_NAME | String | merged_output.csv | Output file name |
| INCLUDE_SOURCE_FILENAME | String | False | Add source filename column (True/False) |

## Step 5: Create the Runbook

1. Go to your Automation Account
2. Navigate to **Runbooks** under Process Automation
3. Click "+ Create a runbook"
4. Configure:
   - **Name:** MergeCSVFiles
   - **Runbook type:** Python
   - **Runtime version:** Python 3.8 or 3.10
   - **Description:** Merges multiple CSV files from source to destination storage
5. Click **Create**
6. In the editor, paste the Python script content
7. Click **Save**
8. Click **Publish**

## Step 6: Test the Runbook

1. Click **Start** to run the runbook
2. Monitor the output in the **Output** tab
3. Check for any errors in the **Errors** tab
4. Verify the merged CSV file in the destination storage account

## Step 7: Schedule the Runbook (Optional)

To run the merge automatically:

1. In the Runbook, click **Schedules**
2. Click "+ Add a schedule"
3. Create a new schedule or link to an existing one
4. Configure frequency (daily, weekly, etc.)
5. Click **OK**

## Troubleshooting

### Common Issues:

**1. Authentication Errors:**
- Verify Managed Identity is enabled
- Check RBAC role assignments on both storage accounts
- Wait 5-10 minutes after role assignment for propagation

**2. Module Import Errors:**
- Ensure all Python packages are imported and fully installed
- Check package compatibility with Python runtime version
- Try re-importing packages

**3. CSV Reading Errors:**
- Verify CSV files have consistent structure (same columns)
- Check file encoding (UTF-8 is expected)
- Ensure files are valid CSV format

**4. Memory Issues:**
- For large files, consider processing in chunks
- Increase Automation Account tier if needed

**5. Container Not Found:**
- Verify container names in Automation Variables
- Ensure containers exist in respective storage accounts

## Alternative: Using Connection String (Less Secure)

If you prefer using connection strings instead of Managed Identity:

1. Create encrypted variables for connection strings:
   - `SOURCE_CONNECTION_STRING`
   - `DEST_CONNECTION_STRING`

2. Modify the script to use:
```python
from azure.storage.blob import BlobServiceClient

connection_string = os.environ.get('SOURCE_CONNECTION_STRING')
blob_service_client = BlobServiceClient.from_connection_string(connection_string)
```

**Note:** Managed Identity is the recommended approach for security.

## Monitoring and Logging

- View job history: Runbooks → Select runbook → Jobs
- Enable diagnostics: Automation Account → Diagnostic settings
- Set up alerts: Monitor → Alerts → New alert rule

## Cost Considerations

- Automation Account: First 500 minutes/month free
- Storage transactions: Read/write operations charged
- Data transfer: Egress charges may apply for cross-region transfers

## Security Best Practices

1. Use Managed Identity (avoid connection strings)
2. Apply least-privilege RBAC roles
3. Enable storage account firewalls and allow Azure services
4. Use Private Endpoints for enhanced security
5. Enable audit logging on storage accounts
6. Regularly review access logs

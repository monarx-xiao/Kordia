"""
Azure Automation Runbook: Merge Multiple CSV Files
This script merges multiple CSV files from a source storage account
into a single CSV file in a destination storage account.
"""

import os
import sys
import pandas as pd
from io import StringIO
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient

# Configuration - These should be set as Automation Account Variables or hardcoded
SOURCE_STORAGE_ACCOUNT_NAME = os.environ.get('SOURCE_STORAGE_ACCOUNT_NAME', 'your-source-storage-account')
SOURCE_CONTAINER_NAME = os.environ.get('SOURCE_CONTAINER_NAME', 'source-container')
SOURCE_BLOB_PREFIX = os.environ.get('SOURCE_BLOB_PREFIX', '')  # Optional: filter blobs by prefix

DEST_STORAGE_ACCOUNT_NAME = os.environ.get('DEST_STORAGE_ACCOUNT_NAME', 'your-dest-storage-account')
DEST_CONTAINER_NAME = os.environ.get('DEST_CONTAINER_NAME', 'dest-container')
DEST_BLOB_NAME = os.environ.get('DEST_BLOB_NAME', 'merged_output.csv')

# Option to include source filename as a column
INCLUDE_SOURCE_FILENAME = os.environ.get('INCLUDE_SOURCE_FILENAME', 'False').lower() == 'true'


def get_blob_service_client(storage_account_name):
    """
    Create a BlobServiceClient using Managed Identity (System or User Assigned)
    """
    try:
        account_url = f"https://{storage_account_name}.blob.core.windows.net"
        credential = DefaultAzureCredential()
        blob_service_client = BlobServiceClient(account_url, credential=credential)
        print(f"Successfully connected to storage account: {storage_account_name}")
        return blob_service_client
    except Exception as e:
        print(f"Error connecting to storage account {storage_account_name}: {str(e)}")
        raise


def list_csv_blobs(container_client, prefix=''):
    """
    List all CSV files in the container
    """
    try:
        blob_list = []
        blobs = container_client.list_blobs(name_starts_with=prefix)
        
        for blob in blobs:
            if blob.name.lower().endswith('.csv'):
                blob_list.append(blob.name)
                print(f"Found CSV file: {blob.name}")
        
        print(f"Total CSV files found: {len(blob_list)}")
        return blob_list
    except Exception as e:
        print(f"Error listing blobs: {str(e)}")
        raise


def download_and_read_csv(container_client, blob_name):
    """
    Download a CSV blob and return it as a pandas DataFrame
    """
    try:
        blob_client = container_client.get_blob_client(blob_name)
        download_stream = blob_client.download_blob()
        csv_data = download_stream.readall().decode('utf-8')
        
        df = pd.read_csv(StringIO(csv_data))
        print(f"Successfully read {blob_name}: {len(df)} rows")
        return df
    except Exception as e:
        print(f"Error reading CSV {blob_name}: {str(e)}")
        raise


def merge_csv_files(source_container_client, blob_list):
    """
    Merge all CSV files into a single DataFrame
    """
    try:
        merged_df = pd.DataFrame()
        
        for blob_name in blob_list:
            df = download_and_read_csv(source_container_client, blob_name)
            
            # Optionally add source filename as a column
            if INCLUDE_SOURCE_FILENAME:
                df['source_file'] = blob_name
            
            # Append to merged dataframe
            if merged_df.empty:
                merged_df = df
            else:
                merged_df = pd.concat([merged_df, df], ignore_index=True)
        
        print(f"Successfully merged {len(blob_list)} files. Total rows: {len(merged_df)}")
        return merged_df
    except Exception as e:
        print(f"Error merging CSV files: {str(e)}")
        raise


def upload_merged_csv(container_client, df, blob_name):
    """
    Upload the merged DataFrame as a CSV to the destination storage account
    """
    try:
        # Convert DataFrame to CSV string
        csv_buffer = StringIO()
        df.to_csv(csv_buffer, index=False)
        csv_data = csv_buffer.getvalue()
        
        # Upload to blob storage
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(csv_data, overwrite=True)
        
        print(f"Successfully uploaded merged CSV to {blob_name}")
        print(f"Total rows in merged file: {len(df)}")
    except Exception as e:
        print(f"Error uploading merged CSV: {str(e)}")
        raise


def main():
    """
    Main execution function
    """
    try:
        print("="*60)
        print("Starting CSV Merge Process")
        print("="*60)
        
        # Connect to source storage account
        print("\n1. Connecting to source storage account...")
        source_blob_service = get_blob_service_client(SOURCE_STORAGE_ACCOUNT_NAME)
        source_container_client = source_blob_service.get_container_client(SOURCE_CONTAINER_NAME)
        
        # List all CSV files in source container
        print("\n2. Listing CSV files in source container...")
        csv_blobs = list_csv_blobs(source_container_client, SOURCE_BLOB_PREFIX)
        
        if not csv_blobs:
            print("No CSV files found in source container. Exiting.")
            return
        
        # Merge CSV files
        print("\n3. Merging CSV files...")
        merged_df = merge_csv_files(source_container_client, csv_blobs)
        
        # Connect to destination storage account
        print("\n4. Connecting to destination storage account...")
        dest_blob_service = get_blob_service_client(DEST_STORAGE_ACCOUNT_NAME)
        dest_container_client = dest_blob_service.get_container_client(DEST_CONTAINER_NAME)
        
        # Upload merged CSV
        print("\n5. Uploading merged CSV to destination...")
        upload_merged_csv(dest_container_client, merged_df, DEST_BLOB_NAME)
        
        print("\n" + "="*60)
        print("CSV Merge Process Completed Successfully!")
        print("="*60)
        
    except Exception as e:
        print(f"\nERROR: CSV merge process failed: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()

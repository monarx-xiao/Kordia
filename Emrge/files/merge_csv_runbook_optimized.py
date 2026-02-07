"""
Azure Automation Runbook: Merge Multiple CSV Files (Optimized for Large Files)
This script merges multiple CSV files from a source storage account
into a single CSV file in a destination storage account using chunked processing.
"""

import os
import sys
import pandas as pd
from io import StringIO, BytesIO
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

# Configuration
SOURCE_STORAGE_ACCOUNT_NAME = os.environ.get('SOURCE_STORAGE_ACCOUNT_NAME', 'your-source-storage-account')
SOURCE_CONTAINER_NAME = os.environ.get('SOURCE_CONTAINER_NAME', 'source-container')
SOURCE_BLOB_PREFIX = os.environ.get('SOURCE_BLOB_PREFIX', '')

DEST_STORAGE_ACCOUNT_NAME = os.environ.get('DEST_STORAGE_ACCOUNT_NAME', 'your-dest-storage-account')
DEST_CONTAINER_NAME = os.environ.get('DEST_CONTAINER_NAME', 'dest-container')
DEST_BLOB_NAME = os.environ.get('DEST_BLOB_NAME', 'merged_output.csv')

INCLUDE_SOURCE_FILENAME = os.environ.get('INCLUDE_SOURCE_FILENAME', 'False').lower() == 'true'
CHUNK_SIZE = int(os.environ.get('CHUNK_SIZE', '10000'))  # Process files in chunks


def get_blob_service_client(storage_account_name):
    """Create a BlobServiceClient using Managed Identity"""
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
    """List all CSV files in the container"""
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


def merge_csv_files_chunked(source_container_client, dest_container_client, blob_list, dest_blob_name):
    """
    Merge CSV files using chunked processing to handle large files efficiently
    """
    try:
        dest_blob_client = dest_container_client.get_blob_client(dest_blob_name)
        is_first_file = True
        total_rows = 0
        
        for idx, blob_name in enumerate(blob_list):
            print(f"\nProcessing file {idx + 1}/{len(blob_list)}: {blob_name}")
            
            # Download blob
            blob_client = source_container_client.get_blob_client(blob_name)
            download_stream = blob_client.download_blob()
            csv_data = download_stream.readall().decode('utf-8')
            
            # Read CSV in chunks
            csv_reader = pd.read_csv(StringIO(csv_data), chunksize=CHUNK_SIZE)
            
            for chunk_idx, chunk in enumerate(csv_reader):
                # Add source filename if requested
                if INCLUDE_SOURCE_FILENAME:
                    chunk['source_file'] = blob_name
                
                # Convert chunk to CSV
                csv_buffer = StringIO()
                
                # Write header only for the first chunk
                write_header = (is_first_file and chunk_idx == 0)
                chunk.to_csv(csv_buffer, index=False, header=write_header)
                csv_string = csv_buffer.getvalue()
                
                # Append to destination blob
                if is_first_file and chunk_idx == 0:
                    # First chunk: create new blob
                    dest_blob_client.upload_blob(csv_string, overwrite=True)
                else:
                    # Subsequent chunks: append to existing blob
                    # Note: Append blob has size limits, consider using Block Blob with staging
                    existing_data = dest_blob_client.download_blob().readall().decode('utf-8')
                    combined_data = existing_data + csv_string
                    dest_blob_client.upload_blob(combined_data, overwrite=True)
                
                total_rows += len(chunk)
                print(f"  Chunk {chunk_idx + 1}: {len(chunk)} rows (Total: {total_rows})")
                
                is_first_file = False
        
        print(f"\nSuccessfully merged {len(blob_list)} files. Total rows: {total_rows}")
        return total_rows
        
    except Exception as e:
        print(f"Error merging CSV files: {str(e)}")
        raise


def merge_csv_files_memory_efficient(source_container_client, dest_container_client, blob_list, dest_blob_name):
    """
    Memory-efficient merge: write directly to blob storage without loading all data in memory
    Uses BlockBlob staging approach
    """
    try:
        dest_blob_client = dest_container_client.get_blob_client(dest_blob_name)
        block_list = []
        block_id_counter = 0
        total_rows = 0
        header_written = False
        
        for idx, blob_name in enumerate(blob_list):
            print(f"\nProcessing file {idx + 1}/{len(blob_list)}: {blob_name}")
            
            # Download blob
            blob_client = source_container_client.get_blob_client(blob_name)
            download_stream = blob_client.download_blob()
            csv_data = download_stream.readall().decode('utf-8')
            
            # Read CSV
            df = pd.read_csv(StringIO(csv_data))
            
            # Add source filename if requested
            if INCLUDE_SOURCE_FILENAME:
                df['source_file'] = blob_name
            
            # Convert to CSV
            csv_buffer = StringIO()
            df.to_csv(csv_buffer, index=False, header=(not header_written))
            csv_bytes = csv_buffer.getvalue().encode('utf-8')
            
            # Upload as a block
            block_id = f"{block_id_counter:010d}".encode('utf-8')
            import base64
            block_id_b64 = base64.b64encode(block_id).decode('utf-8')
            
            dest_blob_client.stage_block(block_id=block_id_b64, data=csv_bytes)
            block_list.append(block_id_b64)
            
            total_rows += len(df)
            header_written = True
            block_id_counter += 1
            
            print(f"  Processed: {len(df)} rows (Total: {total_rows})")
        
        # Commit all blocks
        print(f"\nCommitting {len(block_list)} blocks to blob...")
        dest_blob_client.commit_block_list(block_list)
        
        print(f"Successfully merged {len(blob_list)} files. Total rows: {total_rows}")
        return total_rows
        
    except Exception as e:
        print(f"Error merging CSV files: {str(e)}")
        raise


def main():
    """Main execution function"""
    try:
        print("="*60)
        print("Starting CSV Merge Process (Memory Efficient)")
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
        
        # Connect to destination storage account
        print("\n3. Connecting to destination storage account...")
        dest_blob_service = get_blob_service_client(DEST_STORAGE_ACCOUNT_NAME)
        dest_container_client = dest_blob_service.get_container_client(DEST_CONTAINER_NAME)
        
        # Merge CSV files using memory-efficient approach
        print("\n4. Merging CSV files...")
        total_rows = merge_csv_files_memory_efficient(
            source_container_client, 
            dest_container_client, 
            csv_blobs, 
            DEST_BLOB_NAME
        )
        
        print("\n" + "="*60)
        print("CSV Merge Process Completed Successfully!")
        print(f"Output file: {DEST_BLOB_NAME}")
        print(f"Total rows: {total_rows}")
        print("="*60)
        
    except Exception as e:
        print(f"\nERROR: CSV merge process failed: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()

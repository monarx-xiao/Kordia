#!/usr/bin/env python3
import pandas as pd
import io as io
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient
from datetime import datetime,date,time,timedelta
#from io import StringIO

# ──────────────────────────────────────────────
# CONFIGURATION  ← edit these values
# ──────────────────────────────────────────────
ACCOUNT_NAME    = "emgusagepdaue01"
ACCOUNT_KEY     = "a2BbwJ8oYBhH9VWhTeldk5QkHTFMKL0pjZKOEOjrBWpAzFnBeGYlA6RRkD+bt1ERul4xx5jntcqNSgRj9y4bIQ=="
CONTAINER_NAME  = "eom-ea-nzgt"

ACCOUNT_NAME_EXPORT    = "eomconsumption"
ACCOUNT_KEY_EXPORT     = "vk2OUQbPVEDFZPOWe7rdLj5A1VVqIKlK9rZl40eYsH6/2DZkO/iN6dEX6zXx4qYJlUNX4jBtiigE+AStgQe/cw=="
CONTAINER_NAME_EXPORT  = "eom-nzgt"

MONTH_DIFF = pd.DateOffset(months=1)
#PRE_MONTH = datetime.now() - pd.DateOffset(months=1)
#END_OF_MONTH = datetime.now().replace(day=1) - pd.DateOffset(days=1)

PRE_MONTH_ET = (datetime.now() - MONTH_DIFF).replace(day=1) - pd.DateOffset(days=1)
PRE_MONTH_ST = PRE_MONTH_ET.replace(day=1)

MONTH_RANGE = []
for i in range(1,6):
    past_month = datetime.now() - pd.DateOffset(months=i)
    MONTH_RANGE.append(past_month.strftime("%Y%m"))

#SOURCE_FOLDER = "nzgt/nzgteom/" + PRE_MONTH.replace(day=1).strftime('%Y%m%d') + "-" + END_OF_MONTH.strftime('%Y%m%d') + "/"
#SOURCE_FOLDER = "nzgt/nzgteom/" + PRE_MONTH_ST.strftime('%Y%m%d') + "-" + PRE_MONTH_ET.strftime('%Y%m%d') + "/"
SOURCE_FOLDER = "nzgt/nzgteom/"

DEST_FOLDER     = "nzgteom/"       
OUTPUT_FILENAME = "nzgteom.csv"
#OUTPUT_FILENAME = "nzgteom.json"
# ──────────────────────────────────────────────

# Source storage account connection 

SOURCE_CLIENT = BlobServiceClient.from_connection_string(f"DefaultEndpointsProtocol=https;AccountName={ACCOUNT_NAME};AccountKey={ACCOUNT_KEY};EndpointSuffix=core.windows.net")

# Destination storage account connection

DEST_CLIENT = BlobServiceClient.from_connection_string(f"DefaultEndpointsProtocol=https;AccountName={ACCOUNT_NAME_EXPORT};AccountKey={ACCOUNT_KEY_EXPORT};EndpointSuffix=core.windows.net")

def list_csv_blobs(client: SOURCE_CLIENT, container: str, prefix: str) -> list[str]:
    container_client = client.get_container_client(container)
    blobs = container_client.list_blobs(name_starts_with=prefix)
    return [b.name for b in blobs if b.name.lower().endswith(".csv")]

def download_csv(client: SOURCE_CLIENT, container: str, blob_name: str) -> pd.DataFrame:
    blob_client = client.get_blob_client(container=container, blob=blob_name)
    data = blob_client.download_blob().readall()
    return pd.read_csv(io.BytesIO(data))


def upload_csv(client: BlobServiceClient, container: str, blob_name: str, df: pd.DataFrame) -> None:
    csv_bytes = df.to_csv(index=False).encode("utf-8")
    blob_client = client.get_blob_client(container=container, blob=blob_name)
    blob_client.upload_blob(csv_bytes, overwrite=True)

def merge_and_export():
    print(f"Connecting to storage account: {ACCOUNT_NAME}")
    client = SOURCE_CLIENT
    export_client = DEST_CLIENT

    # 1. List CSV files in source folder
    csv_blobs_raw = list_csv_blobs(client, CONTAINER_NAME, SOURCE_FOLDER)
    csv_blobs = []
    for blob_raw in csv_blobs_raw:
        if blob_raw[13:19] in MONTH_RANGE:                                
            csv_blobs.append(blob_raw)                                  

    if not csv_blobs:
        print(f"No CSV files found in '{CONTAINER_NAME}/{SOURCE_FOLDER}'")
        return

    print(f"Found {len(csv_blobs)} CSV file(s):")
    for name in csv_blobs:
        print(f"  • {name}")

    # 2. Download and merge
    frames = []
    for blob_name in csv_blobs:
        print(f"  Downloading: {blob_name}")
        df = download_csv(client, CONTAINER_NAME, blob_name)
        df["_source_file"] = blob_name.split("/")[-1]   # optional: track origin
        frames.append(df)

    merged = pd.concat(frames, ignore_index=True)
    print(f"\nMerged shape: {merged.shape[0]:,} rows × {merged.shape[1]} columns")

    # 3. Upload merged file to destination folder
    dest_blob = DEST_FOLDER + OUTPUT_FILENAME
    print(f"Uploading merged file to: {CONTAINER_NAME_EXPORT}/{dest_blob}")
    upload_csv(export_client, CONTAINER_NAME_EXPORT, dest_blob, merged)

    print(f"\n✓ Done — merged CSV written to '{dest_blob}'")


if __name__ == "__main__":
    merge_and_export()

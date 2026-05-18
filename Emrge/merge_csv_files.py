import pandas as pd
import glob
import os

def merge_csv_files(folder_path, output_file='nzgteom.csv'):
    """
    Merge all CSV files in a folder into a single CSV file.
    
    Parameters:
    folder_path (str): Path to the folder containing CSV files
    output_file (str): Name of the output merged CSV file
    """
    
    # Get all CSV files in the folder
    csv_files = glob.glob(os.path.join(folder_path, '*.csv'))
    
    if not csv_files:
        print(f"No CSV files found in {folder_path}")
        return
    
    print(f"Found {len(csv_files)} CSV files:")
    for file in csv_files:
        print(f"  - {os.path.basename(file)}")
    
    # Read and concatenate all CSV files
    df_list = []
    for file in csv_files:
        try:
            df = pd.read_csv(file)
            df_list.append(df)
            print(f"✓ Read {os.path.basename(file)} ({len(df)} rows)")
        except Exception as e:
            print(f"✗ Error reading {os.path.basename(file)}: {e}")
    
    if not df_list:
        print("No CSV files were successfully read")
        return
    
    # Merge all dataframes
    merged_df = pd.concat(df_list, ignore_index=True)
    
    # Save to output file
    merged_df.to_csv(output_file, index=False)
    
    print(f"\n✓ Successfully merged {len(df_list)} files into '{output_file}'")
    print(f"  Total rows: {len(merged_df)}")
    print(f"  Total columns: {len(merged_df.columns)}")

# Example usage
if __name__ == "__main__":
    # Replace with your folder path
    folder_path = "D:\Python_host"
    
    # Optional: specify custom output filename
    output_file = "nzgteom.csv"
    
    merge_csv_files(folder_path, output_file)

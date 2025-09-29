#!/bin/bash

# The base directory containing the subfolders
BASE_DIR="."
# The new base URL for the updated links
NEW_BASE_URL="https://raw.githubusercontent.com/igvteam/igv-data/refs/heads/main/genomes/legacy/xml"

# Ensure the base directory exists
if [ ! -d "$BASE_DIR" ]; then
  echo "Error: Base directory '$BASE_DIR' not found."
  exit 1
fi

# (1) Loop through each subfolder of the "xml" directory
for subdir in "$BASE_DIR"/*/; do
  # Check if it is a directory
  if [ -d "$subdir" ]; then
    subfolder_name=$(basename "$subdir")
    echo "Processing directory: $subfolder_name"

    # Find the dataServerRegistry.txt file
    registry_file=$(find "$subdir" -name "*dataServerRegistry.txt" -print -quit)

    if [ -z "$registry_file" ]; then
      echo "  No *dataServerRegistry.txt file found in '$subdir'. Skipping."
      continue
    fi

    # Create a temporary file to store the new registry content
    temp_registry_file=$(mktemp)

    # (2) Read the contents of the "*dataServerRegistry.txt" file
    while IFS= read -r url || [[ -n "$url" ]]; do
      # Trim whitespace
      trimmed_url=$(echo "$url" | xargs)
      if [ -z "$trimmed_url" ]; then
        continue
      fi

      # Extract filename from the URL
      filename=$(basename "$trimmed_url")

      # (3) Download the contents of each URL into the current subfolder
      echo "  Downloading '$filename'..."
      # Use curl to download the file into the subdirectory
      curl -s -L -o "$subdir/$filename" "$trimmed_url"

      # (4) Construct the new URL and write it to the temporary file
      new_url="$NEW_BASE_URL/$subfolder_name/$filename"
      echo "$new_url" >> "$temp_registry_file"

    done < "$registry_file"

    # Replace the original registry file with the updated one
    mv "$temp_registry_file" "$registry_file"
    echo "  Updated '$registry_file'"
  fi
done

echo "Processing complete."

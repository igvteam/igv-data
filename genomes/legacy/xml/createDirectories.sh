#!/bin/bash

# The directory containing the files to process
TARGET_DIR="."

# Ensure the target directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' not found."
  exit 1
fi

# Loop through each file in the target directory
for file in "$TARGET_DIR"/*; do
  # Process only files, not directories
  if [ -f "$file" ]; then
    filename=$(basename "$file")

    # (1) Extract the genome ID (substring before the last underscore)
    genome_id="${filename%_*}"

    # Skip if there is no underscore in the filename
    if [ "$genome_id" == "$filename" ]; then
      continue
    fi

    # (2) Create a directory for the genome ID
    new_dir="$TARGET_DIR/$genome_id"
    mkdir -p "$new_dir"

    # (3) Move the file to the new directory
    mv "$file" "$new_dir/"

    echo "Moved '$filename' to '$new_dir/'"
  fi
done

echo "File organization complete."

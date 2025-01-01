#!/bin/bash
# Extract all subtitle streams from input media files.
# By: Ethan Jansen

shopt -s nullglob

################### Global Variables ######################



################## Functions #############################

Usage(){
  echo "Extract all subtitle streams from input media files."
  echo "Input an array of files or directories to check."
  echo "Directories are depth-1 searched."
  echo "Depends: mkvtoolnix."
  echo
  echo "Syntax: ffmpegHash.sh <destination folder> <file1> [<file2> <file3>...]"
  echo "Options:"
  echo "-h      Print this help message."
} 

############### Main ####################

# Test inputs

if [ $# -lt 2 ] || (printf -- '%s\n' "$@" | grep -Fxq -- '-h'); then
  Usage
  exit 1
fi

# read arguments and hash files
for arg; do
  if [ -f "$arg" ]; then # Handle files
    echo "Processing file: $arg"
  elif [ -d "$arg" ]; then # Handle directories
    # get all files/directories at depth=1, but omit directories
    argDir=("$arg"/*)
    for argFile in "${argDir[@]}"; do
      if [ -f "$argFile" ]; then
        echo "Processing directory file: $argFile"
      fi
    done
  else  # No valid file/directory
    echo -e "\033[31mFile/Directory not found: $arg\033[0m" >&2
    # exit 1 # Do not exit, just warn and continue
  fi
done

#!/bin/bash
# Extract all subtitle streams from input media files.
# By: Ethan Jansen

shopt -s nullglob

################### Global Variables ######################

Destination=

################## Functions #############################

Usage(){
  echo "Extract all subtitle streams from input mkv files."
  echo "Input an array of files or directories to check."
  echo "Directories are depth-1 searched for mkv files."
  echo "Depends: mkvtoolnix."
  echo
  echo "Syntax: ffmpegHash.sh <file1.mkv> [<file2.mkv> <file3.mkv>...] <destination folder>"
  echo "Options:"
  echo "-h      Print this help message."
} 

############### Main ####################

# Test inputs
if [ $# -lt 2 ] || (printf -- '%s\n' "$@" | grep -Fxq -- '-h'); then
  Usage
  exit 1
fi

# get the destination folder
Destination="${*: -1}"
if ! [ -d "$Destination" ]; then
  echo -e "\033[31m$Destination is not a valid destination!\033[0m" >&2
  exit 1
fi
echo "Using destination: $Destination"

# read arguments and hash files
for arg in "${@:1:$#}"; do
  if [ -f "$arg" ] && [[ "$arg" =~ .*\.mkv$ ]]; then # Handle files
    echo "Processing file: $arg"
  elif [ -d "$arg" ]; then # Handle directories
    # get all files/directories at depth=1, but omit directories
    argDir=("$arg"/*.mkv)
    for argFile in "${argDir[@]}"; do
      if [ -f "$argFile" ]; then
        echo "Processing directory file: $argFile"
      fi
    done
  else  # No valid file/directory
    echo -e "\033[31mInvalid file/directory: $arg\033[0m" >&2
    # exit 1 # Do not exit, just warn and continue
  fi
done

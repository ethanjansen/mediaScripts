#!/bin/bash
# Compare media files via checksums. Check complete files and individual streams (via ffmpeg).
# Compares streams within files as well as between files.
# Outputs list of files with conflicting hashes.
# Output format: "hash|filename|streamid|numConflicts". Output is organized by stream type.
# Requires `ffmpeg`. Uses sha256.
# By: Ethan Jansen

shopt -s nullglob

################### Global Variables ######################

# Format: "Hash|filename|streamNumber"
# streamNumber is always 0 for FileHashes (and for VideoHashes)
FileHashes=()
VideoHashes=()
AudioHashes=()
SubHashes=()

################## Functions #############################

Usage(){
  echo "Compare media files via checksums. Check complete files and individual streams (via ffmpeg)."
  echo "Compares streams within files as well as between files."
  echo "Outputs list of files with conflicted hashes, organized by stream type and in hash order."
  echo "Output format: \"hash|filename|streamid|numConflicts\"."
  echo "Input an array of files or directories to check."
  echo "Directories are depth-1 searched."
  echo "Uses sha256 hashes."
  echo "Depends: ffmpeg."
  echo
  echo "Syntax: ffmpegHash.sh <file1> <file2> <file3>..."
  echo "Options:"
  echo "-h      Print this help message."
} 

# input is assumed to be a valid file
# first hashes file, adding it to FileHashes array
# next hashes individual streams via ffmpeg streamhash, adding them to respective arrays
# If an error occurs during hashing, it will be printed to stderr
# This function does not return anything
GetFileHashes(){
  # hash file
  FileHashes+=("$(sha256sum "$1" | cut -f 1 -d " ")|$(basename "$1")|0")

  # hash streams
  local ffmpegOut
  if ffmpegOut=$(ffmpeg -i "$1" -v quiet -map "0:v?" -map "0:a?" -map "0:s?" -c copy -f streamhash -hash sha256 -); then
    # organize hashes (stream, type hash)
    # streamNumber, streamType, hash
    local s t h
    while IFS=$',' read -r s t h; do
      local val=
      val="$h|$(basename "$1")|$s"
      case "$t" in
        v)
          VideoHashes+=("$val");;
        a)
          AudioHashes+=("$val");;
        s)
          SubHashes+=("$val");;
      esac
    done <<< "${ffmpegOut//SHA256=/}"
  else
    echo -e "\033[31mError while hashing streams of $1\033[0m" >&2
  fi
}

# Sort hash arrays by hash->filename->stream
# Does not return anything
SortArrays(){
  readarray -t FileHashes < <(printf -- '%s\n' "${FileHashes[@]}" | sort)
  readarray -t VideoHashes < <(printf -- '%s\n' "${VideoHashes[@]}" | sort)
  readarray -t AudioHashes < <(printf -- '%s\n' "${AudioHashes[@]}" | sort)
  readarray -t SubHashes < <(printf -- '%s\n' "${SubHashes[@]}" | sort)
}

# Print elements in array with conflicting hashes.
# This does not indicate what it conflicts with,
# but the arrays should already be sorted, thus making it clear.
PrintConflicts(){
  # hash, filename, streamNumber
  local h count
  for item; do
    IFS=$'|' read -r h _ <<< "$item"
    count=$(printf -- '%s\n' "$@" | grep -cF "$h")
    if [ "$count" -gt 1 ]; then
      echo "$item|$count"
    fi
  done
}

############### Main ####################

# Test inputs

if [ $# -lt 1 ] || (printf -- '%s\n' "$@" | grep -Fxq -- '-h'); then
  Usage
  exit 1
fi

# read arguments and hash files
for arg; do
  if [ -f "$arg" ]; then # Handle files
    echo "Processing file: $arg"
    GetFileHashes "$arg"
  elif [ -d "$arg" ]; then # Handle directories
    # get all files/directories at depth=1, but omit directories
    argDir=("$arg"/*)
    for argFile in "${argDir[@]}"; do
      if [ -f "$argFile" ]; then
        echo "Processing directory file: $argFile"
        GetFileHashes "$argFile"
      fi
    done
  else  # No valid file/directory
    echo -e "\033[31mFile/Directory not found: $arg\033[0m" >&2
    # exit 1 # Do not exit, just warn and continue
  fi
done

# sort hash arrays
SortArrays

# Output Findings
echo
echo "====================================================================================="
echo "===================================== Conflicts ====================================="
echo "====================================================================================="
echo "File Hashes:"
PrintConflicts "${FileHashes[@]}"
echo
echo "Video Stream Hashes:"
PrintConflicts "${VideoHashes[@]}"
echo
echo "Audio Stream Hashes:"
PrintConflicts "${AudioHashes[@]}"
echo
echo "Subtitle Stream Hashes:"
PrintConflicts "${SubHashes[@]}"

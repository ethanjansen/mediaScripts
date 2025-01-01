#!/bin/bash
# Compare media files via checksums. Check complete files and individual streams (via ffmpeg).
# Compares streams within files as well as between files.
# Requires `ffmpeg`.
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
  echo "Input an array of files to check and/or a directory to depth=1 search."
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
  FileHashes+=("$(sha512sum "$1" | cut -f 1 -d " ")|$(basename "$1")|0")

  # hash streams
  local ffmpegOut=
  if ffmpegOut=$(ffmpeg -i "$1" -v quiet -map "0:v?" -map "0:a?" -map "0:s?" -c copy -f streamhash -hash sha512 -); then
    # organize hashes (stream, type hash)
    while IFS=',' read -r s t h; do
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
    done <<< "${ffmpegOut//SHA512=/}"
  else
    echo -e "\033[31mError while hashing streams of $1\033[0m" >&2
  fi
}

############### Main ####################

if [ $# -lt 1 ] || [ "$1" = "-h" ]; then
  Usage
  exit 1
fi

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

echo "================================================================================="
echo "=============================== Output =========================================="
echo "================================================================================="
echo "File Hashes: Count: ${#FileHashes[@]}"
printf '%s\n' "${FileHashes[@]}"
echo
echo "Video Stream Hashes: Count: ${#VideoHashes[@]}"
printf '%s\n' "${VideoHashes[@]}"
echo
echo "Audio Stream Hashes: Count: ${#AudioHashes[@]}"
printf '%s\n' "${AudioHashes[@]}"
echo
echo "Subtitle Stream Hashes: Count ${#SubHashes[@]}"
printf '%s\n' "${SubHashes[@]}"

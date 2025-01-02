#!/bin/bash
# Extract all subtitle streams from input media files.
# By: Ethan Jansen

shopt -s nullglob

################### Global Variables ######################

Destination=

################## Functions #############################

Usage(){
  echo "Extract all subtitle streams from input Matroska files."
  echo "Input an array of files or directories to check."
  echo "Directories are depth-1 searched for mkv files."
  echo "Depends: mkvtoolnix, jq"
  echo
  echo "Syntax: mkvExtractSubs.sh <file1.mkv> [<file2.mkv> <file3.mkv>...] <destination folder>"
  echo "Options:"
  echo "-h      Print this help message."
}

# Outputs filename extension corresponding to mkvtoolnix subtitle codec
# Returns nothing for no match (or S_VOBSUB as it is handled automatically by mkvextract)
GetExtension() {
  case $1 in
    "S_HDMV/PGS")
      echo ".sup";;
    "S_HDMV/TEXTST")
      echo ".textst";;
    "S_KATE")
      echo ".ogg";;
    "S_TEXT/SSA" | "S_SSA")
      echo ".ssa";;
    "S_TEXT/ASS" | "S_ASS")
      echo ".ass";;
    "S_TEXT/UTF8" | "S_TEXT/ASCII")
      echo ".srt";;
    # "S_VOBSUB") # This is handled automatically by mkvextract
    "S_TEXT/USF")
      echo ".usf";;
    "S_TEXT/WEBVTT")
      echo ".vtt";;
  esac
}

# Extract subtitles from file.
# Checks for valid Matroska file and gets subtitle track ids from mkvmerge identify.
# Prints to stderr if file is not valid.
# Finally extracts all subtitle tracks (if present) from file.
# Output file names: {sourceName}_{"forced" if forced}_[{language}]_t{trackID}.{extension}
# Extension is chosen automatically by mkvextract (this does not appear to always be the case)
# Does not return anything.
ExtractSubs(){
  local info recognized supported count id idpadded default forced lang codec filename 
  local tracks=()

  # strip extension from filename
  filename="$(basename "${1%.*}")"

  # get file information
  info="$(mkvmerge -J "$1")"

  # check if valid file
  recognized="$(echo "$info" | jq -rM '.container.recognized')"
  supported="$(echo "$info" | jq -rM '.container.supported')"
  if [[ "$recognized" == "false" ]] || [[ "$supported" == "false" ]]; then
    echo -e "\033[31mError: Unable to read Matroska file $1\033[0m" >&2
    return
  fi

  # Get subtitle streams
  info="$(echo "$info" | jq -rM '.tracks | map(select(.type == "subtitles"))')"
  count="$(echo "$info" | jq -rM '. | length')"

  # no subtitles found
  if [ "$count" -eq 0 ]; then
    return
  fi

  for (( i=0; i<count; i++ )); do
    # get information for each stream
    id="$(echo "$info" | jq -rM ".[$i].id")"
    default="$(echo "$info" | jq -rM ".[$i].properties.default_track")"
    forced="$(echo "$info" | jq -rM ".[$i].properties.forced_track")"
    lang="$(echo "$info" | jq -rM ".[$i].properties.language")"
    codec="$(echo "$info" | jq -rM ".[$i].properties.codec_id")"

    # transform default+forced -> forced
    if [[ "$default" == "true" ]] || [[ "$forced" == "true" ]]; then
      forced="_forced"
    else
      forced=""
    fi

    # get output file extension
    codec="$(GetExtension "$codec")"

    # pad id
    idpadded="$(printf '%02d' "$id")"

    tracks+=("${id}:${Destination}/${filename}${forced}_[${lang}]_t${idpadded}${codec}")
  done

  # perform extract
  mkvextract "$1" --flush-on-close tracks "${tracks[@]}"
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
Destination="$(realpath "$Destination")"
echo "Using destination: $Destination"

# read arguments and hash files
for arg in "${@:1:$#}"; do
  echo
  if [ -f "$arg" ] && [[ "$arg" =~ .*\.(mkv|mk3d|mka|mks)$ ]]; then # Handle files
    echo "Processing file: $arg"
    ExtractSubs "$arg"
  elif [ -d "$arg" ]; then # Handle directories
    # get all files/directories at depth=1, but omit directories
    argDir=("$arg"/*.{mkv,mk3d,mka,mks})
    for argFile in "${argDir[@]}"; do
      if [ -f "$argFile" ]; then
        echo "Processing directory file: $argFile"
        ExtractSubs "$argFile"
      fi
    done
  else  # No valid file/directory
    echo -e "\033[31mInvalid file/directory: $arg\033[0m" >&2
    # exit 1 # Do not exit, just warn and continue
  fi
done

#!/bin/bash
# Add subtitle streams to media files.
# By: Ethan Jansen

shopt -s nullglob

################### Global Variables ######################

Subtitles=()
Inputs=()
Destination=

################## Functions #############################

Usage(){
  echo "Add subtitle streams to Matroska files."
  echo "Input a subtitle files and a Matroska files to combine."
  echo "Subdirectories are not included when scanning directory inputs."
  echo "All matching is done via file names: subtitle file names are expected to match matroska file name before the {subs-} section."
  echo "Subtitles will be \"default\" and \"forced\", have a selected language, named, and marked as \"commentary\" based on file name."
  echo "Subtitle stream order will follow file name (t##), and follow any existing subtitles."
  echo "Depends: mkvtoolnix, jq"
  echo
  echo "Syntax: mkvAddSubs.sh -s <subtitle file/directory> -i <source mkv file/directory> -o <destination folder>"
  echo "Options:"
  echo "-s      Subtitle file list, or subtitle directory. Use option multiple times for multiple subtitles."
  echo "-i      Input mkv file (or directory of files) to add subtitles to. Use option multiple times for multiple inputs."
  echo "-o      Output destination folder."
  echo "-h      Print this help message."
}

# Sort input arrays
# Items could be added out of order (by file, or multiple directories)
SortArrays(){
  readarray -t Subtitles < <(printf -- '%s\n' "${Subtitles[@]}" | sort)
  readarray -t Inputs < <(printf -- '%s\n' "${Inputs[@]}" | sort)
}

# Test MKV input
# Ensure it is supported via mkvmerge
# Check for any existing default/forced subs
ParseMKV(){
  # file info
  local info title
  # for testing Matroska file
  local recognized supported
  # to test if default/forced sub present
  local forced default

  # loop through inputs
  for i in "${!Inputs[@]}"; do
    info="$(mkvmerge -J "${Inputs[$i]}")"
    title="${Inputs[$i]%.*}"
    
    # check if valid
    recognized="$(echo "$info" | jq -rM '.container.recognized')"
    supported="$(echo "$info" | jq -rM '.container.supported')"
    if [[ "$recognized" != "true" ]] || [[ "$supported" != "true" ]]; then
      echo -e "\033[31mError: Unable to read Matroska file ${Inputs[$i]}\033[0m" >&2
      unset "Inputs[i]"
      continue
    fi

    # check if an existing default/forced sub tracks
    # save to forced
    info="$(echo "$info" | jq -rM '.tracks | map(select(.type == "subtitles"))')"
    forced="$(echo "$info" | grep -Fc "\"forced_track\": true")"
    default="$(echo "$info" | grep -Fc "\"default_track\": true")"
    if [ "$forced" -gt 0 ] || [ "$default" -gt 0 ]; then
      forced=0 # this matches bash standards and can be used directly with subtitle inputs for mkvmerge as it is opposite
    else
      forced=1
    fi

    # save back to inputs with format: "filename|forced|title"
    Inputs[i]="${Inputs[$i]}|$forced|$title"
  done
}

# Check if language is not one of the following: und, mis, mul, zxx q[a-z]{2}
# If not, return language name
# Matches ISO 639-3
CheckLang(){
  if [[ "$1" =~ ^(und|mis|mul|zxx|q[a-z]{2})$ ]]; then
    return 1
  fi

  mkvmerge --list-languages | cut -d '|' -f1-2 | grep -m 1 -F "| $1" | cut -d '|' -f1 | sed -e 's/[[:space:]]*$//'
}

# Parse subtitle inputs
# Assume proper files (mkvmerge will eventually catch it)
# Get information from subtitle file names
# Also, if .idx check if .sub exists
# This may still end with multiple forced subs per title, plus if the title already has a forced/default sub
ParseSub(){
  # subtitle information
  local subInfo lang title forced commentary

  for i in "${!Subtitles[@]}"; do
    # check if improperly named subtitle file
    if ! [[ "${Subtitles[$i]}" =~ .*\{sub-t[0-9]{2}\.\[[a-z]{3}\].*\} ]]; then
      echo -e "\033[31mImproperly named subtitle: ${Subtitles[$i]}\033[0m" >&2
      unset "Subtitles[i]"
      continue
    fi

    subInfo="${Subtitles[$i]#*\{sub-}" 

    # check if idx
    if [[ "$subInfo" =~ .idx$ ]]; then
      # find if .sub exists in same folder
      if ! [ -f "${Subtitles[$i]%.*}.sub" ]; then
        echo -e "\033[31mMissing .sub file corresponding to ${Subtitles[$i]}\033[0m" >&2
        unset "Subtitles[i]"
        continue
      fi
    fi

    lang="$(echo "$subInfo" | cut -d '[' -f2 | cut -d ']' -f1)"
    forced="$(echo "$subInfo" | grep -Fc "forced")" # should only be 1 or 0, opposite of normal bash boolean
    commentary="$(echo "$subInfo" | grep -Fc "commentary")" # see comment above

    # get name. Precedence: forced -> commentary -> language
    if [ "$forced" -eq 1 ]; then
      title="Forced"
    elif [ "$commentary" -eq 1 ]; then
      title="Commentary"
    else
      title="$(CheckLang "$lang")"
    fi

    # save back to Subtitles with format: "filename|forced|commentary|lang|title"
    Subtitles[i]="${Subtitles[$i]}|$forced|$commentary|$lang|$title"
  done
}

############### Main ####################

# Test inputs
if [ $# -lt 6 ]; then
  Usage
  exit 1
fi

while getopts ":s:i:o:h" opt; do
  case $opt in
    s) # get subtitles list from individual subtitle file or directory
      # don't include .sub, only .idx, but later ensure .sub is in the same directory as the .idx.
      # mkvmerge will pull it automatically
      if [ -f "$OPTARG" ] && [[ "$OPTARG" =~ .*\.(sup|textst|ogg|ssa|ass|srt|idx|usf|vtt)$ ]]; then
        Subtitles+=("$(realpath "$OPTARG")")
      elif [ -d "$OPTARG" ]; then
        Subtitles+=("$(realpath "$OPTARG")"/*.{sup,textst,ogg,ssa,ass,srt,idx,usf,vtt})
      else
        echo -e "\033[31m$OPTARG is not a valid subtitle file/directory!\033[0m" >&2
        exit 1
      fi;;
    i) # get matroska input list from individual matroska file or directory
      if [ -f "$OPTARG" ] && [[ "$OPTARG" =~ .*\.(mkv|mk3d|mka|mks)$ ]]; then
        Inputs+=("$(realpath "$OPTARG")")
      elif [ -d "$OPTARG" ]; then
        Inputs+=("$(realpath "$OPTARG")"/*.{mkv,mk3d,mka,mks})
      else
        echo -e "\033[31m$OPTARG is not a valid Matroska file/directory!\033[0m" >&2
        exit 1
      fi;;
    o) # get and test destination
      if [ -n "$Destination" ]; then
        echo -e "\033[31mCan only handle one destination directory!\033[0m" >&2
        exit 1
      fi
      
      if ! [ -d "$OPTARG" ]; then
        echo -e "\033[31m$OPTARG is not a valid destination!\033[0m" >&2
        exit 1
      fi

      Destination="$(realpath "$OPTARG")"
      echo "Using destination: $Destination";;
    h) # print help message
      Usage
      exit 1;;
    \?) # invalid option 
      echo -e "\033[31mInvalid option: $opt\033[0m" >&2
      exit 1;;
  esac
done

# test that subtitles/inputs/output are all populated
if [ -z "$Destination" ]; then
  echo -e "\033[31mNo destination folder specified!\033[0m" >&2
  exit 1
fi
if [ ${#Inputs[@]} -eq 0 ]; then
  echo -e "\033[31mNo valid Matroska inputs specified!\033[0m" >&2 
  exit 1
fi
if [ ${#Subtitles[@]} -eq 0 ]; then
  echo -e "\033[31mNo valid subtitles specified!\033[0m" >&2
  exit 1
fi

# test inputs
ParseMKV
ParseSub

# sort inputs
SortArrays

# testing
printf -- '%s\n' "${Inputs[@]}"
echo
printf -- '%s\n' "${Subtitles[@]}"

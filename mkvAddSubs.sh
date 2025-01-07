#!/bin/bash
# Add subtitle streams to media files.
# By: Ethan Jansen

shopt -s nullglob

################### Global Variables ######################

QUIET=1

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
  echo "Syntax: mkvAddSubs.sh -s <subtitle file/directory> -i <source mkv file/directory> -o <destination folder> [-q]"
  echo "Options:"
  echo "-s      Subtitle file list, or subtitle directory. Use option multiple times for multiple subtitles."
  echo "-i      Input mkv file (or directory of files) to add subtitles to. Use option multiple times for multiple inputs."
  echo "-o      Output destination folder."
  echo "-q      Quiet. Do not print non-fatal error/warning messages. Errors from mkvmerge are still printed."
  echo "-h      Print this help message."
}

# Print warnings (non-fatal errors)
LogWarning(){
  if [ "$QUIET" -eq 1 ]; then
    echo -e "\033[33m$1\033[0m" >&2 # print yellow to stderr
  fi
}

# Print (fatal) errors
LogError(){
  # print red to stderr and exit
  echo -e "\033[31m$1\033[0m" >&2
  exit 1
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
  local info filebasename title
  # for testing Matroska file
  local recognized supported
  # to test if default/forced sub present
  local forced default

  # loop through inputs
  for i in "${!Inputs[@]}"; do
    info="$(mkvmerge -J "${Inputs[$i]}")"
    filebasename="$(basename "${Inputs[$i]}")"
    title="${filebasename%.*}"
    
    # check if valid
    recognized="$(echo "$info" | jq -rM '.container.recognized')"
    supported="$(echo "$info" | jq -rM '.container.supported')"
    if [[ "$recognized" != "true" ]] || [[ "$supported" != "true" ]]; then
      LogWarning "Error: Unable to read Matroska file ${Inputs[$i]}"
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

    # save back to inputs with format: "filebasename|filename|forced|title"
    Inputs[i]="$filebasename|${Inputs[$i]}|$forced|$title"
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
  # file information
  local filebasename
  # subtitle information
  local subInfo lang title forced commentary

  for i in "${!Subtitles[@]}"; do
    # check if improperly named subtitle file
    if ! [[ "${Subtitles[$i]}" =~ .*\{sub-t[0-9]{2}\.\[[a-z]{3}\].*\} ]]; then
      LogWarning "Improperly named subtitle: ${Subtitles[$i]}"
      unset "Subtitles[i]"
      continue
    fi

    filebasename="$(basename "${Subtitles[$i]}")"
    subInfo="${Subtitles[$i]##*\{sub-}" 

    # check if idx
    if [[ "$subInfo" =~ .idx$ ]]; then
      # find if .sub exists in same folder
      if ! [ -f "${Subtitles[$i]%.*}.sub" ]; then
        LogWarning "Missing .sub file corresponding to ${Subtitles[$i]}"
        unset "Subtitles[i]"
        continue
      fi
    fi

    lang="$(echo "$subInfo" | cut -d '[' -f2 | cut -d ']' -f1)"
    forced="$(echo "$subInfo" | grep -Fc "forced")" # should only be 1 or 0, opposite of normal bash boolean
    commentary="$(echo "$subInfo" | grep -Fc "commentary")" # see comment above

    # get name. Precedence: commentary -> forced -> language
    if [ "$commentary" -eq 1 ]; then
      title="Commentary"
    elif [ "$forced" -eq 1 ]; then
      title="Forced"
    else
      title="$(CheckLang "$lang")"
    fi

    # save back to Subtitles with format: "filebasename|filename|forced|commentary|lang|title"
    Subtitles[i]="$filebasename|${Subtitles[$i]}|$forced|$commentary|$lang|$title"
  done
}

# For each Matroska input, find matching subtitles (based on file name).
# Considering existing subs, determine if subtitles should be forcedi (when applicable).
# Construct mkvmerge options and run.
# Do nothing if Matroska file does not have any subtitles (create warning?)
Merge(){
  for input in "${Inputs[@]}"; do
    # subs relevant for specific input
    local subList=()
    # mkvmerge options for specific input
    local mergeStrings=()
    # metadata temp
    local lang subTitle forced commentary subFile fileTitle forcedPresent inputFile inputFilename _ 
  
    # get input info
    IFS=$'|' read -r inputFilename inputFile forcedPresent fileTitle <<< "$input"

    # get matching subtitles
    readarray -t subList < <(printf -- '%s\n' "${Subtitles[@]}" | grep -F -- "$fileTitle")
    if [ "${#subList[@]}" -eq 0 ]; then
      LogWarning "No subtitles found for $inputFile"
      continue
    fi
    for sub in "${subList[@]}"; do
      # get sub info
      IFS=$'|' read -r _ subFile forced commentary lang subTitle <<< "$sub"

      # check if forced - set to 0 if already present
      if [ "$forcedPresent" -eq 0 ] && [ "$forced" -eq 1 ]; then
        forced=0
        if [[ "$subTitle" = "Forced" ]]; then
          subTitle="$(CheckLang "$lang")"
        fi
      fi

      # create option string for sub - should already be sorted
      mergeStrings+=("--default-track-flag -1:${forced}" "--forced-display-flag -1:${forced}" "--commentary-flag -1:${commentary}" "--language -1:${lang}" "--track-name -1:${subTitle}" "${subFile}")
    done

    # perform mkvmerge
    echo "Creating ${Destination}/${inputFilename}"
    #testing
    echo "mkvmerge --flush-on-close -o ${Destination}/${inputFilename} --title $fileTitle $inputFile ${mergeStrings[@]}"
  done
}

# Find subtitles missing a matching Matroska file
FindLeftOutSubs(){
  for sub in "${Subtitles[@]}"; do
    local filebasename filename _
    local matchCount
    IFS=$'|' read -r filebasename filename _ <<< "$sub"
    matchCount="$(echo "${Inputs[@]}" | grep -Fc "${filebasename% \{sub-*}")"
    if [ "$matchCount" -eq 0 ]; then
      LogWarning "No matching Matroska file for subtitle $filename"
    fi
  done
}

############### Main ####################

# Test inputs
if [ $# -lt 6 ]; then
  Usage
  exit 1
fi

while getopts ":s:i:o:qh" opt; do
  case $opt in
    s) # get subtitles list from individual subtitle file or directory
      # don't include .sub, only .idx, but later ensure .sub is in the same directory as the .idx.
      # mkvmerge will pull it automatically
      if [ -f "$OPTARG" ] && [[ "$OPTARG" =~ .*\.(sup|textst|ogg|ssa|ass|srt|idx|usf|vtt)$ ]]; then
        Subtitles+=("$OPTARG")
      elif [ -d "$OPTARG" ]; then
        Subtitles+=("$OPTARG"/*.{sup,textst,ogg,ssa,ass,srt,idx,usf,vtt})
      else
        LogError "$OPTARG is not a valid subtitle file/directory!"
      fi;;
    i) # get matroska input list from individual matroska file or directory
      if [ -f "$OPTARG" ] && [[ "$OPTARG" =~ .*\.(mkv|mk3d|mka|mks)$ ]]; then
        Inputs+=("$OPTARG")
      elif [ -d "$OPTARG" ]; then
        Inputs+=("$OPTARG"/*.{mkv,mk3d,mka,mks})
      else
        LogError "$OPTARG is not a valid Matroska file/directory!"
      fi;;
    o) # get and test destination
      if [ -n "$Destination" ]; then
        LogError "Can only handle one destination directory!"
      fi
      
      if ! [ -d "$OPTARG" ]; then
        LogError "$OPTARG is not a valid destination!"
      fi

      Destination="$(realpath "$OPTARG")"
      echo "Using destination: $Destination";;
    q) # quiet warnings
      QUIET=0;;
    h) # print help message
      Usage
      exit 1;;
    \?) # invalid option 
      LogError "Invalid option: $opt";;
  esac
done

# test that subtitles/inputs/output are all populated
if [ -z "$Destination" ]; then
  LogError "No destination folder specified!"
fi
if [ ${#Inputs[@]} -eq 0 ]; then
  LogError "No valid Matroska inputs specified!" 
fi
if [ ${#Subtitles[@]} -eq 0 ]; then
  LogError "No valid subtitles specified!"
fi

# test inputs
ParseMKV
ParseSub

# sort inputs
SortArrays

# merge subtitles with inputs
Merge

# Check if any left out subtitles
FindLeftOutSubs

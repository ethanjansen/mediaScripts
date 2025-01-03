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
  echo "Depends: mkvtoolnix"
  echo
  echo "Syntax: mkvAddSubs.sh -s <subtitle file/directory> -i <source mkv file/directory> -o <destination folder>"
  echo "Options:"
  echo "-s      Subtitle file list, or subtitle directory. Use option multiple times for multiple subtitles."
  echo "-i      Input mkv file (or directory of files) to add subtitles to. Use option multiple times for multiple inputs."
  echo "-o      Output destination folder."
  echo "-h      Print this help message."
}

# Test MKV input
# Ensure it is supported via mkvmerge
# Find the next subtitle id and check for any existing default/forced subs
TestMKV(){
  true
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
        Subtitles+=("$OPTARG")
      elif [ -d "$OPTARG" ]; then
        Subtitles+=("$OPTARG"/*.{sup,textst,ogg,ssa,ass,srt,idx,usf,vtt})
      else
        echo -e "\033[31m$OPTARG is not a valid subtitle file/directory!\033[0m" >&2
        exit 1
      fi;;
    i) # get matroska input list from individual matroska file or directory
      if [ -f "$OPTARG" ] && [[ "$OPTARG" =~ .*\.(mkv|mk3d|mka|mks)$ ]]; then
        Inputs+=("$OPTARG")
      elif [ -d "$OPTARG" ]; then
        Inputs+=("$OPTARG"/*.{mkv,mk3d,mka,mks})
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

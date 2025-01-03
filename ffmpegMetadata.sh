#!/bin/bash
# Output specific information about a media file using ffmpeg.
# Requires `ffmpeg/ffmprobe` (and `bat` if paginating output).
# By: Ethan Jansen

# Need to check for input file name
Usage(){
  echo "Output specific information about a media file using ffmpeg/ffprobe."
  echo "Depends: ffmpeg/ffmprobe (and optionally bat)."
  echo
  echo "Syntax: ffmpegMetadata.sh <file> [-p]"
  echo "Options:"
  echo "-p      Paginate output using bat."
  echo "-h      Print this help message."
} 

Probe(){
  ffprobe -i "$1" -hide_banner -v error -show_entries format=filename,nb_streams,format_long_name,duration,size,bit_rate:format_tags:stream=index,codec_long_name,profile,codec_type,width,height,display_aspect_ratio,pix_fmt,level,color_space,color_transfer,color_primaries,chroma_location,field_order,avg_frame_rate,start_time,duration,bit_rate,max_bit_rate,sample_fmt,sample_rate,channels,channel_layout,bits_per_raw_sample:stream_side_data_list:stream_disposition=default,dub,original,comment,forced,hearing_impaired,visual_impaired,captions,descriptions,metadata:stream_tags:chapter=start_time,end_time:chapter_tags -pretty -of json
}

############### Main ####################
PAGINATE=1
PARAMS=() # index 0 should contain file name

while [ $# -gt 0 ]; do
  while getopts "ph" opt; do
    case $opt in
      h) # display help
        Usage
        exit 1;;
      p) # paginate output
        PAGINATE=0;;
      \?) # invalid
        echo "Error: Invalid argument"
        exit 1;;
    esac
  done
  if [[ ${OPTIND:-0} -gt 0 ]]; then
    shift $((OPTIND-1))
  fi

  while [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; do
    PARAMS=("${PARAMS[@]}" "$1")
    shift
  done
done

# Not perfect input handling, but whatever
if [ ${#PARAMS[@]} -ne 1 ]; then
  Usage
  exit 1
fi

if [ ! -f "${PARAMS[0]}" ]; then
  echo "Error: File not found!"
  exit 1
fi

if [[ "$PAGINATE" -eq 0 ]]; then
  Probe "${PARAMS[0]}" | bat --language json --theme TwoDark --file-name "$(basename "${PARAMS[0]}")"
else
  Probe "${PARAMS[0]}"
fi

#!/bin/bash
# Output specific information about a media file using ffmpeg.
# Requires `ffmpeg/ffmprobe` and `bat` to paginate output.
# By: Ethan Jansen

# Known issues:
# - Strips off language_ietf stream tag from output report for mkv files
# - Does not include language "und" tag in output report


Usage(){
  echo "Output specific information about a media file using ffmpeg/ffprobe."
  echo "Depends: ffmpeg/ffmprobe and bat."
  echo
  echo "Syntax: ffmpegMetadata.sh <file> "
  echo "Options:"
  echo "-h      Print this help message."
} 

Probe(){
  ffprobe -i "$1" -hide_banner -v error -show_entries format=filename,nb_streams,format_long_name,duration,size,bit_rate:format_tags:stream=index,codec_long_name,profile,codec_type,width,height,display_aspect_ratio,pix_fmt,level,color_space,color_transfer,color_primaries,chroma_location,field_order,avg_frame_rate,start_time,duration,bit_rate,max_bit_rate,sample_fmt,sample_rate,channels,channel_layout,bits_per_raw_sample:stream_side_data_list:stream_disposition=default,dub,original,comment,forced,hearing_impaired,visual_impaired,captions,descriptions,metadata:stream_tags:chapter=start_time,end_time:chapter_tags -pretty -of json
}

############### Main ####################
# check input
if [ $# -ne 1 ] || (printf -- '%s\n' "$@" | grep -Fxw -- '-h'); then
  Usage
  exit 1
fi

if [ ! -f "$1" ]; then
  echo -e "\033[31mError: File $1 not found!\033[0m"
  exit 1
fi

Probe "$1" | bat --language json --theme TwoDark --file-name "$(basename "$1")"

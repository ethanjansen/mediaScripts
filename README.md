## Media Scripts

#### [ffmpegHash](./ffmpegHash.sh)
    
* Hash media files and their individual streams.
* Used for verifying media files.
* File names cannot contain vertical bar "|"
* Requires `ffmpeg`
* Usage: `ffmpegHash.sh <file1> [<file2> <file3>...]`

#### [ffmpegMetadata](./ffmpegMetadata.sh)

* Read metadata from media files.
* Linux CLI alternative to MediaInfo.
* Requires `ffmpeg` and `bat`
* Usage: `ffmpegMetadata.sh <file>`

#### [mkvAddSubs](./mkvAddSubs.sh)

* Add subtitles to Matroska files in batch mode.
* Expects matching file names and appropriate "{subs-t\<id\>.\[\<lang\>\].\<forced\>.\<commentary\>}.\<extension\>" tags on subtitles.
* File names cannot contain vertical bar "|".
* Requires `mkvtoolnix` and `jq`
* Usage: `mkvAddSubs.sh <subtitle file/directory> -i <source mkv file/directory> -o <destination folder> [-q]`

#### [mkvExtractSubs](./mkvExtractSubs.sh)

* Extract subtitles from Matroska files in batch mode.
* Will extract subtitles with file name conventions from `mkvAddSubs`.
* Requires `mkvtoolnix` and `jq`
* Usage: `mkvExtractSubs.sh <file1.mkv> [<file2.mkv> <file3.mkv>...] <destination folder>`

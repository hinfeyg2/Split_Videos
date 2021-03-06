### Options __________________________________________________________________________________________________________
$ffmpeg = "C:\ffmpeg\bin\ffmpeg.exe"            # Set path to your ffmpeg.exe; Build Version: git-45581ed (2014-02-16)
$ffprobe = "C:\ffmpeg\bin\ffprobe.exe"
$filter = @("*.mov","*.mp4")        # Set which file extensions should be processed

### Main Program ______________________________________________________________________________________________________

### Find the path of the script
$path = split-path -parent $MyInvocation.MyCommand.Definition

### Add \* to our selected path.
$folder = $path + "\*"

### Search our folder for videos.
foreach ($video in dir $folder -include $filter -exclude "*_???.*" -r ){
  
  ### Set working directory for intermediate files which will be deleted when split is finished.
  $workingDirectory = $path + "\" + $video.basename + "_temp_dir"
    
  ### make the directory.
  & mkdir $workingDirectory
  
  ### Set path to logfile and the name of the logfile where we'll store the ffprobe results.
  $logfile = $workingDirectory + "\" + "$($video.basename)_ffprobe.log"
  
  ### we need to be working from the directory of our video.
  & cd $path
  
  ### Get the filename of our selected video.
  $videoFilename = split-path $video -leaf
  
  ### Run ffprobe on the selected video.
  & $ffprobe -show_frames -of compact=p=0 -f lavfi "movie=$videoFilename,select=gt(scene\,0.3)" > $logfile

  ### Set our regex to get the pattern which will get us the cuts in seconds from the logfile.
  $regex1 = 'pkt_pts_time=(\d+\.\d+)'
  
  ### If file is empty then create just transcode the whole file.
  If((Get-Content $logfile) -eq $Null)
  {
    ### Notice
    echo "Empty"
    
    ### Create an output template for a file with no cuts.
    $NoCutsOutput = $workingDirectory + "\" + $video.basename + "_000" + ".mp4"
    
    ### Transcode the whole file.
    & $ffmpeg -i $videoFilename -vcodec mpeg4 -qscale 2 -an -flags +global_header -map 0 -reset_timestamps 1 $NoCutsOutput
  }
  
  ### If file is not empty then create split intermediate files.
  Else
  {
  
  ### Run the regex on our log.
  $CutsInSeconds = select-string -Path $logfile -Pattern $regex1 -AllMatches | % { $_.Matches } | % { $_.Value }
  
  ### Clean up the result.
  $CutsInSeconds = $CutsInSeconds -replace 'pkt_pts_time='
  
  ### Add a 0 to the start of the list. We need this or it wont split the first video.
  $CutsInSeconds = ,0 + $CutsInSeconds
  
  ### Iterate through the cut list.
  for($i = 0; $i -le $CutsInSeconds.GetUpperBound(0); $i++)
  {
  
  ### Set our intermediate output directory. Add leading zeros.
  $IntermediateOutput = $workingDirectory + "\" + $video.basename + "_" + ( "{0:D3}" -f $i ) + ".mp4"
  
  ### Get the ClipDuration by subtracting first cut from second cut.
  $ClipDuration = $CutsInSeconds[$i + 1] - $CutsInSeconds[$i]
 
  ### Find the number of cuts.
  $NumberOfCuts = $CutsInSeconds.GetUpperBound(0)
  
  ### Test if we are on the last cut.
  If($i -eq $NumberOfCuts)
  {
    ### if we are then do not set a duration.
    & $ffmpeg -i $videoFilename -ss $CutsInSeconds[$i] -c copy -vcodec mpeg4 -qscale 2 -an -flags +global_header -map 0 -reset_timestamps 1 $IntermediateOutput
  }
  Else
  {
    ### if we are not then use our duration.
    & $ffmpeg -i $videoFilename -ss $CutsInSeconds[$i] -c copy -t $ClipDuration -vcodec mpeg4 -qscale 2 -an -flags +global_header -map 0 -reset_timestamps 1 $IntermediateOutput
  }
  
  ### Iterate through the cut list CLOSE
  }
  
  ### If file is not empty then create split intermediate files CLOSE
  }
  
  ### Iterate through or intermediate clips.
  foreach ($video in dir ($workingDirectory + "\*") -include $filter)
  {
  
  ### Set our final output directory and name.
  $FinalOutput = $path + "\" +$video.basename + ".mp4"
  
  ### Transcode intermediate mpeg4 files to x264.
  & $ffmpeg -i $video -codec:a copy -codec:v libx264 -pix_fmt yuv420p $FinalOutput
  
  ### Iterate through or intermediate clips CLOSE.
  }
  
  ### Delete working directory.
  & rm -r $workingDirectory
  
  ### Search our folder for videos CLOSE
  }
  
  
#!/bin/bash
# Vars.
SCRIPTS=~/.local/share/nautilus/scripts/Remuxer
ICON=$SCRIPTS/ffmpeg.png
SOUND=$SCRIPTS/notify.wav
LOG=/tmp/re-coding.log
EXT=$1

display () # Calculate/collect progress bar info. & pipe to Zenity.
{
START=$(date +%s); FR_CNT=0; ETA=0; ELAPSED=0
while [ -e /proc/$PID ]; do                         # Is FFmpeg running?
    sleep 1
    VSTATS=$(tail -n1 "$RM"/ffmpeg-* | egrep -o 'frame=[0-9]+' | grep -Po '\d+' | tail -n1) # Parse vstats file.
    if [ $VSTATS -gt $FR_CNT ] 2> /dev/null; then                # Parsed sane or no?
        FR_CNT=$VSTATS
        PERCENTAGE=$(( 100 * FR_CNT / TOT_FR ))     # Progbar calc.
        ELAPSED=$(( $(date +%s) - START )); echo $ELAPSED > /tmp/elapsed.value
        ETA=$(date -d @$(awk 'BEGIN{print int(('$ELAPSED' / '$FR_CNT') *\
        ('$TOT_FR' - '$FR_CNT'))}') -u +%H:%M:%S)   # ETA calc.
    echo "# Working on file: $COUNT of $OF - Length: $DUR - Frames: $TOT_FR\
    \nFilename: ${NFILE%.*}\nSaved to: $SAVEAS\
    \nRe-muxing with FFmpeg\
    \nFrame: $FR_CNT of $TOT_FR   Elapsed: $(date -d @$ELAPSED -u\
    +%H:%M:%S)   ET to finish: $ETA"                # Text for stats. output.
    echo $PERCENTAGE                                # Feed the progbar.
    fi
done | zenity\
    --progress\
    --window-icon $ICON\
    --title="Remuxing to $EXT"\
    --text="Initializing please wait..."\
    --percentage=0\
    --auto-close\
    --auto-kill
}

displayalt () # Display pulsate progress bar & pipe to Zenity.
{
START=$(date +%s); FR_CNT=0; ELAPSED=0
while [ -e /proc/$PID ]; do                         # Is FFmpeg running?
    sleep 1
    VSTATS=$(tail -n1 "$RM"/ffmpeg-* | egrep -o 'frame=[0-9]+' | grep -Po '\d+' | tail -n1) # Parse vstats file.
    if [ $VSTATS -gt $FR_CNT ] 2> /dev/null; then                # Parsed sane or no?
        FR_CNT=$VSTATS
	TOT_FR=$FR_CNT
        ELAPSED=$(( $(date +%s) - START )); echo $ELAPSED > /tmp/elapsed.value
    echo "# Working on file: $COUNT of $OF - Length: $DUR - Frames: N/A\
    \nFilename: ${NFILE%.*}\nSaved to: $SAVEAS\
    \nRe-muxing with FFmpeg\
    \nFrame: $FR_CNT of N/A   Elapsed: $(date -d @$ELAPSED -u\
    +%H:%M:%S)   ET to finish: N/A"                # Text for stats. output.
    fi
done | zenity\
    --progress\
    --window-icon $ICON\
    --title="Remuxing to $EXT"\
    --text="Initializing please wait..."\
    --pulsate \
    --auto-close\
    --auto-kill
}

SEL=$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS            # Right clicked selection.
echo $SEL >> $LOG
RM=$(pwd)
trap "killall ffmpeg; rm -f "$RM/ffmpeg2pass*" "$RM/ffmpeg-*"; exit" \
INT TERM EXIT                                       # Kill & clean if stopped.

# Select re-muxed file destination.
SAVEAS=`pwd`
#SAVEAS=$(zenity --file-selection --directory\
#    --window-icon $ICON --title ">>SELECT DESTINATION FOR RE-MUXED FILE<<")
#if [ "$?" = 1 ]; then
#    exit $?
#fi
echo "to $SAVEAS" >> $LOG

SAVEIFS=$IFS                                        # Make "for loops" handle
IFS=$(echo -en "\n\b")                              # filenames with spaces.

for FILE in $SEL; do ((OF+=1)); done                    # Count right click
echo -e $(date +%c)" - Files processed: $OF\n" >> $LOG  # selected files, log.

# Loop through counted file selection and process in turn.
for FILE in $SEL; do ((COUNT+=1))
    echo "FILE: $FILE" >> $LOG
    NFILE=$(basename "$FILE")
    # Get duration and PAL/NTSC fps then calculate total frames.
    FPS=$(ffprobe "$FILE" 2>&1 | sed -rn "s/\s*framerate:\s(.*)/\1/p")
    echo "FPS: $FPS" >> $LOG
    DUR=$(ffprobe "$FILE" 2>&1 | sed -n "s/.* Duration: \([^,]*\), .*/\1/p")
    echo "DUR: $DUR" >> $LOG
    if [ $DUR != "N/A" ]; then
    	HRS=$(echo $DUR | cut -d":" -f1)
    	MIN=$(echo $DUR | cut -d":" -f2)
    	SEC=$(echo $DUR | cut -d":" -f3)
    	TOT_FR=$(echo "($HRS*3600+$MIN*60+$SEC)*$FPS" | bc | cut -d"." -f1)
    else
	TOT_FR=0
    fi
    echo "TOTAL FRAMES: $TOT_FR" >> $LOG
    #if [ ! "$TOT_FR" -gt "0" ]; then zenity --error --text="Corrupted file, try manually with: ffmpeg -i \"$FILE\" -c copy \"$SAVEAS/${NFILE%.*}.$EXT\""; exit; fi

    if [ ! "$TOT_FR" -gt "0" ]; then 
	    #Pulsate Bar
	    FUNCTION="displayalt"
    else
	    #Progress Bar
	    FUNCTION="display"
    fi

    nice -n 15 ffmpeg -i "$FILE" \
        -c:v copy \
	-c:a copy \
        -y\
	-report -loglevel verbose -hide_banner\
        $SAVEAS/${NFILE%.*}.$EXT &                       # Background FFmpeg.
        PID=$! && $FUNCTION                               # GUI stats. func.
        rm -f "$RM"/ffmpeg-*                             # Clean up tmp files.

    # Statistics for logfile entry.
    ((BATCH+=$(cat /tmp/elapsed.value)))                # Batch time totaling.
    ELAPSED=$(cat /tmp/elapsed.value)                   # Per file time.
    echo -e $COUNT\. ${NFILE%.*}\
    "\nDuration: $DUR - Total frames: $TOT_FR" >> $LOG
    # Elapsed time for 1 pass, average for 2 passes, fps average for both.
    AV_RATE=$(( TOT_FR / ELAPSED ))
    echo -e "Re-muxing time taken: $(date -d @$ELAPSED -u +%H:%M:%S)"\
    "at an average rate of $AV_RATE""fps.\n" >> $LOG
done

# Notify finished batch ding-dong gong and message, log it, all done bye ;¬)
TEXT="Total re-muxing time: $(date -d @$BATCH -u +%H:%M:%S)."
echo -e "$TEXT\n\
__________________________________________________________________" >> $LOG
notify-send -i $ICON "Re-muxing completed" "$TEXT"
/usr/bin/canberra-gtk-play --volume 2 -f $SOUND

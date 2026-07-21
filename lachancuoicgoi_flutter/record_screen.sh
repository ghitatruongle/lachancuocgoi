#!/bin/bash

# Target device serial
SERIAL="fc2407a4"

# Desktop directory to save the file
DESKTOP_DIR="/c/Users/Acer/Desktop"

# Find ADB path
ADB="adb"
if ! command -v adb &>/dev/null; then
    ADB_PATH="/c/Users/Acer/AppData/Local/Android/Sdk/platform-tools/adb"
    if [ -f "$ADB_PATH" ]; then
        ADB="$ADB_PATH"
    else
        ADB_PATH_WIN="/c/Users/Acer/AppData/Local/Android/Sdk/platform-tools/adb.exe"
        if [ -f "$ADB_PATH_WIN" ]; then
            ADB="$ADB_PATH_WIN"
        else
            echo "Error: adb is not found. Please make sure Android SDK platform-tools is in your PATH."
            exit 1
        fi
    fi
fi

# Ensure device is connected
DEVICE_STATUS=$("$ADB" -s "$SERIAL" get-state 2>/dev/null)
if [ "$DEVICE_STATUS" != "device" ]; then
    echo "Error: Device $SERIAL is not connected or unauthorized."
    exit 1
fi

# Get maximum resolution of the device dynamically
RESOLUTION=$("$ADB" -s "$SERIAL" shell wm size | grep -oE '[0-9]+x[0-9]+' | head -n 1)
if [ -z "$RESOLUTION" ]; then
    RESOLUTION="720x1480" # Fallback to physical size of SM-J610F
fi

echo "==============================================="
echo "Android Screen Recorder (Bash)"
echo "Device: Samsung SM-J610F ($SERIAL)"
echo "Resolution: $RESOLUTION (Highest)"
echo "Save location: $DESKTOP_DIR"
echo "==============================================="
echo "Starting recording..."
echo "Press [Ctrl + C] to STOP and SAVE the video to your Desktop."
echo "==============================================="

TEMP_FILE="/sdcard/temp_recording.mp4"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="$DESKTOP_DIR/record_$TIMESTAMP.mp4"

# Handle Ctrl+C (SIGINT) to pull the file and clean up
cleanup() {
    echo -e "\nStopping recording gracefully..."
    # Give a moment to let the file finalize on the device
    sleep 2
    
    echo "Downloading video to Desktop..."
    "$ADB" -s "$SERIAL" pull "$TEMP_FILE" "$OUTPUT_FILE"
    
    if [ -f "$OUTPUT_FILE" ]; then
        echo "Success! Video saved to Desktop: $OUTPUT_FILE"
        echo "Cleaning up temporary file on device..."
        "$ADB" -s "$SERIAL" shell rm "$TEMP_FILE"
    else
        echo "Error: Failed to download the video. It might not have been recorded properly."
    fi
    exit 0
}

# Trap Ctrl+C
trap cleanup SIGINT

# Start recording in the foreground so Ctrl+C goes straight to it
# We use max-time of 180 seconds (3 minutes is the Android limit for screenrecord)
"$ADB" -s "$SERIAL" shell screenrecord --size "$RESOLUTION" --bit-rate 8000000 "$TEMP_FILE"

# If it hits the 3-minute limit naturally without Ctrl+C, run cleanup
cleanup

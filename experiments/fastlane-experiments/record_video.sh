#!/bin/bash

# Ensure the script exits if any command fails
set -e

# Arguments
DEVICE="$1"
VIDEO_LABEL="$2"
DURATION="$3"  # Duration in seconds

# Boot the device
xcrun simctl boot "$DEVICE"

# Wait for the device to boot up
xcrun simctl bootstatus "$DEVICE" -b

# Define app launch arguments based on the label
if [ "$VIDEO_LABEL" == "MainScreen" ]; then
  LAUNCH_ARGS="--screenshot-main"
elif [ "$VIDEO_LABEL" == "SettingsScreen" ]; then
  LAUNCH_ARGS="--screenshot-settings"
elif [ "$VIDEO_LABEL" == "ProfileScreen" ]; then
  LAUNCH_ARGS="--screenshot-profile"
elif [ "$VIDEO_LABEL" == "GameScreen" ]; then
  LAUNCH_ARGS="--screenshot-game"
elif [ "$VIDEO_LABEL" == "SummaryScreen" ]; then
  LAUNCH_ARGS="--screenshot-summary"
else
  LAUNCH_ARGS=""
fi

# Launch the app with arguments
xcrun simctl launch "$DEVICE" com.example.yourapp $LAUNCH_ARGS

# Start recording
xcrun simctl io "$DEVICE" recordVideo "${VIDEO_LABEL}.mp4" &

# Capture the process ID of the recording command
RECORDING_PID=$!

# Wait for the specified duration
sleep "$DURATION"

# Stop recording
kill "$RECORDING_PID"

# Shutdown the device
xcrun simctl shutdown "$DEVICE"

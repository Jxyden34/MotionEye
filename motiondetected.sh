#!/bin/bash

# Telegram Bot Configuration
BOT_TOKEN="N/A"
CHAT_ID="N/A"

# Video Directory Configuration
VIDEO_BASE_DIR="/var/lib/motioneye/Camera1"
GIF_OUTPUT_DIR="/home/jayden/Videos"  # Change this to a writable directory

# Setup logging
LOG_FILE="/var/log/video_motion.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to send a message via Telegram
send_telegram_message() {
    local text=$1
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID&text=$text" \
        > /dev/null
    log "Sent message to Telegram: $text"
}

# Function to send a gif via Telegram
send_telegram_gif() {
    local gif_path=$1
    local caption=$2
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendAnimation" \
        -F "chat_id=$CHAT_ID" \
        -F "caption=$caption" \
        -F "animation=@$gif_path" \
        > /dev/null
    log "Sent GIF to Telegram: $gif_path"
}

# Locate the most recent video file
find_latest_video() {
    find "$VIDEO_BASE_DIR" -type f -name "*.mp4" -printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d' ' -f2-
}

# Check if file is stable (not being written to)
is_file_stable() {
    local file_path=$1
    initial_size=$(stat -c %s "$file_path")
    sleep 2
    current_size=$(stat -c %s "$file_path")
    if [ "$initial_size" -eq "$current_size" ]; then
        log "File is stable: $file_path"
        return 0  # File is stable
    else
        log "File is still being written to: $file_path"
        return 1  # File is not stable
    fi
}

# Function to convert video to GIF
convert_video_to_gif() {
    local video_path=$1
    local gif_path=$2
    ffmpeg -i "$video_path" -vf "fps=10,scale=320:-1:flags=lanczos" -c:v gif "$gif_path" > /dev/null 2>&1
    log "Converted video to GIF: $gif_path"
}

# Main logic
main() {
    current_date_time=$(date '+%Y-%m-%d %H:%M:%S')
    latest_video=$(find_latest_video)

    if [ -n "$latest_video" ] && is_file_stable "$latest_video"; then
        # Ensure the GIF output directory exists
        if [ ! -d "$GIF_OUTPUT_DIR" ]; then
            mkdir -p "$GIF_OUTPUT_DIR"
        fi

        # Convert video to GIF
        gif_filename=$(basename "$latest_video" .mp4).gif
        gif_path="$GIF_OUTPUT_DIR/$gif_filename"
        convert_video_to_gif "$latest_video" "$gif_path"
        
        # Send the GIF to Telegram
        send_telegram_gif "$gif_path" "Motion detected at $current_date_time. Here is the GIF of the event."
    else
        send_telegram_message "Motion detected at $current_date_time, but no stable video could be located in $VIDEO_BASE_DIR!"
    fi
}

# Run the script
main

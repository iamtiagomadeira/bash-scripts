#!/bin/bash

# --- Configuration ---
# Set to 1 for verbose tar output (list extracted files), 0 for quiet.
VERBOSE_TAR=1
# Set to 1 to attempt creating the destination directory if it doesn't exist.
CREATE_DEST_DIR=1
# Location for log files (leave empty to use current directory)
LOG_DIR=""
# Default number of leading directory components to strip (used if not provided as arg 3)
DEFAULT_STRIP_COMPONENTS=5
# ---------------------

# --- Functions ---
log_message() {
    # Logs a message to stdout and the logfile with a timestamp.
    # Usage: log_message "Your message here"
    local message="$1"
    # Get current timestamp for the log entry
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    # Format the message with the timestamp
    local formatted_message="$timestamp - $message"
    # Print to console and append to the log file
    echo "$formatted_message" | tee -a "$logfile"
}

# --- Main Script ---

# --- Argument Parsing ---

# Check if at least the required number of arguments is provided
if [ "$#" -lt 2 ]; then
    # Updated Usage message
    echo "Usage: $0 <tar_archive_file> <destination_directory> [strip_components]"
    echo "  [strip_components] is optional. Defaults to $DEFAULT_STRIP_COMPONENTS if not provided."
    # Exit with error code 1 if arguments are incorrect
    exit 1
fi

# Assign command-line arguments to variables
tar_file=$1
destination_dir=$2

# Handle optional third argument for strip_components
strip_components_to_use=$DEFAULT_STRIP_COMPONENTS # Start with default
if [ -n "$3" ]; then
    # Check if the third argument is a non-negative integer
    if [[ "$3" =~ ^[0-9]+$ ]]; then
        strip_components_to_use=$3 # Use the provided argument
        echo "Using specified strip_components value: $strip_components_to_use"
    else
        echo "Error: Invalid value for strip_components: '$3'. Must be a non-negative integer."
        exit 1
    fi
else
    echo "Using default strip_components value: $strip_components_to_use"
fi
# End of optional argument handling


# --- Input Validation ---

# Check if the tar file exists
if [ ! -f "$tar_file" ]; then
    echo "Error: Archive file not found: $tar_file"
    exit 1
fi
# Check if the tar file is readable
if [ ! -r "$tar_file" ]; then
    echo "Error: Archive file not readable: $tar_file"
    exit 1
fi

# Check the destination directory
if [ -e "$destination_dir" ] && [ ! -d "$destination_dir" ]; then
    # Error if the destination exists but is not a directory
    echo "Error: Destination exists but is not a directory: $destination_dir"
    exit 1
elif [ ! -d "$destination_dir" ]; then
    # If the directory doesn't exist
    if [ "$CREATE_DEST_DIR" -eq 1 ]; then
        # Attempt to create it if configured to do so
        echo "Destination directory not found. Attempting to create: $destination_dir"
        mkdir -p "$destination_dir"
        # Check if directory creation was successful
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create destination directory: $destination_dir"
            exit 1
        else
             echo "Successfully created destination directory."
        fi
    else
        # Error if not configured to create the directory
        echo "Error: Destination directory not found: $destination_dir"
        exit 1
    fi
fi

# Check if the destination directory is writable
if [ ! -w "$destination_dir" ]; then
    echo "Error: Destination directory is not writable: $destination_dir"
    exit 1
fi

# --- Log File Setup ---

# Create a unique log file name with timestamp
log_base_name="extraction_log_$(date +"%Y%m%d_%H%M%S").log"
# Determine the full path for the log file
if [ -z "$LOG_DIR" ]; then
    # Use current directory if LOG_DIR is not set
    logfile="$log_base_name"
else
    # Use specified LOG_DIR, creating it if necessary
    mkdir -p "$LOG_DIR" # Ensure log dir exists
    logfile="$LOG_DIR/$log_base_name"
fi

# --- Extraction Process ---

# Start logging
log_message "Script started."
log_message "Archive file: $tar_file"
log_message "Destination directory: $destination_dir"
log_message "Log file: $logfile"
# Updated log message to use the determined value
log_message "Stripping leading components: $strip_components_to_use"

# Record start time (both human-readable and seconds since epoch)
start_seconds=$(date +%s)
start_time=$(date +"%Y-%m-%d %H:%M:%S")
log_message "Extraction started at $start_time"

# Prepare tar options based on configuration
# *** Changed how options are built to avoid clustering -xvf ***
tar_opts="-x" # Basic extract option
if [ "$VERBOSE_TAR" -eq 1 ]; then
    tar_opts="$tar_opts -v" # Add verbose option separately if configured
fi
# Note: -f option will be added explicitly in the command below

# Construct the full tar command for logging and execution
# Options are now separated: -x [-v] -f file ...
tar_command="tar $tar_opts -f \"$tar_file\" --strip-components=$strip_components_to_use -C \"$destination_dir\""
log_message "Running command: $tar_command"

# Execute the tar command
# Standard output and standard error are redirected to the log file
# $tar_opts will be either "-x" or "-x -v"
if tar $tar_opts -f "$tar_file" --strip-components=$strip_components_to_use -C "$destination_dir" >> "$logfile" 2>&1; then
    # Success case
    tar_exit_status=$? # Capture exit status (should be 0)
    log_message "tar command completed successfully (Exit Status: $tar_exit_status)."
else
    # Failure case
    tar_exit_status=$? # Capture non-zero exit status
    log_message "ERROR: tar command failed (Exit Status: $tar_exit_status). Check log for details."
    # Optional: Display last few lines of log on error to the console
    echo "--- Last 5 lines of log ($logfile) ---"
    tail -n 5 "$logfile"
    echo "---------------------------------------"
    # Log end time even on failure
    end_seconds=$(date +%s)
    end_time=$(date +"%Y-%m-%d %H:%M:%S")
    duration=$((end_seconds - start_seconds))
    log_message "Extraction failed at $end_time"
    log_message "Total duration: ${duration} seconds."
    log_message "Script finished with errors."
    exit 1 # Exit with error status
fi

# --- Final Logging ---

# Log end time and duration on success
end_seconds=$(date +%s)
end_time=$(date +"%Y-%m-%d %H:%M:%S")
duration=$((end_seconds - start_seconds))
log_message "Extraction finished successfully at $end_time"
log_message "Total duration: ${duration} seconds."
log_message "Script finished successfully."

# Final message to console indicating log file location
echo "Extraction process logged to: $logfile"

# Exit with success status
exit 0
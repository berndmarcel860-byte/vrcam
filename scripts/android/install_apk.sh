#!/bin/bash
#
# install_apk.sh - Install Android APK to connected device via adb
#
# This script automates the installation of Android APK files to connected devices.
# It handles device detection, selection (when multiple devices are present),
# and provides helpful error messages.
#
# Usage:
#   ./install_apk.sh [path/to/app.apk]
#
# Examples:
#   ./install_apk.sh                                    # Search for APKs and prompt
#   ./install_apk.sh app/build/outputs/apk/debug/app-debug.apk
#   ./install_apk.sh "app-*.apk"                        # Use glob pattern
#
# Requirements:
#   - adb (Android Debug Bridge) must be installed and in PATH
#   - At least one Android device connected via USB with USB debugging enabled
#
# Exit codes:
#   0 - Success
#   1 - General error (adb not found, no devices, etc.)
#   2 - APK file not found or invalid
#   3 - Installation failed
#

set -e  # Exit on error

# Colors for output (only if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Print functions
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

# Check if adb is available
check_adb() {
    if ! command -v adb &> /dev/null; then
        print_error "adb (Android Debug Bridge) is not found in PATH"
        echo ""
        echo "Please install Android SDK Platform-Tools:"
        echo "  - https://developer.android.com/studio/releases/platform-tools"
        echo ""
        echo "Or set ANDROID_HOME and add platform-tools to PATH:"
        echo "  export ANDROID_HOME=/path/to/Android/Sdk"
        echo "  export PATH=\$PATH:\$ANDROID_HOME/platform-tools"
        exit 1
    fi
}

# Start adb server if not running
start_adb_server() {
    print_info "Starting adb server..."
    adb start-server > /dev/null 2>&1 || true
    sleep 1
}

# Get list of connected devices
get_devices() {
    # Get device list, filter out header and empty lines
    adb devices | tail -n +2 | grep -v "^$" | grep "device$" | cut -f1
}

# Check for connected devices
check_devices() {
    local devices
    devices=$(get_devices)
    
    if [ -z "$devices" ]; then
        print_error "No Android devices found"
        echo ""
        echo "Please ensure:"
        echo "  1. Your Android device is connected via USB"
        echo "  2. USB debugging is enabled on your device"
        echo "  3. You've authorized this computer for USB debugging"
        echo ""
        echo "To enable USB debugging:"
        echo "  - Go to Settings → About Phone"
        echo "  - Tap 'Build Number' 7 times to enable Developer Options"
        echo "  - Go to Settings → System → Developer Options"
        echo "  - Enable 'USB Debugging'"
        echo ""
        exit 1
    fi
    
    echo "$devices"
}

# Select device if multiple are connected
select_device() {
    local devices=($1)
    local device_count=${#devices[@]}
    
    if [ $device_count -eq 1 ]; then
        echo "${devices[0]}"
        return
    fi
    
    # Multiple devices - prompt user to select
    print_warning "Multiple devices detected:"
    echo ""
    
    local i=1
    for device in "${devices[@]}"; do
        # Try to get device model name
        local model=$(adb -s "$device" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        local android_version=$(adb -s "$device" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
        
        if [ -n "$model" ]; then
            echo "  $i) $device - $model (Android $android_version)"
        else
            echo "  $i) $device"
        fi
        ((i++))
    done
    
    echo ""
    read -p "Select device (1-$device_count): " selection
    
    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $device_count ]; then
        print_error "Invalid selection"
        exit 1
    fi
    
    # Return selected device (array is 0-indexed, selection is 1-indexed)
    echo "${devices[$((selection-1))]}"
}

# Find APK file
find_apk() {
    local apk_pattern="$1"
    
    # If pattern is provided, search for it
    if [ -n "$apk_pattern" ]; then
        # Check if it's a direct file path
        if [ -f "$apk_pattern" ]; then
            echo "$apk_pattern"
            return 0
        fi
        
        # Try glob expansion
        local found_apks=($(ls $apk_pattern 2>/dev/null))
        if [ ${#found_apks[@]} -eq 1 ]; then
            echo "${found_apks[0]}"
            return 0
        elif [ ${#found_apks[@]} -gt 1 ]; then
            print_warning "Multiple APK files match pattern '$apk_pattern':"
            echo ""
            for apk in "${found_apks[@]}"; do
                echo "  - $apk"
            done
            echo ""
            read -p "Enter number or full path of APK to install: " selection
            if [ -f "$selection" ]; then
                echo "$selection"
                return 0
            fi
        fi
    fi
    
    # Search for APKs in common locations
    print_info "Searching for APK files..."
    local search_paths=(
        "app/build/outputs/apk/debug/app-debug.apk"
        "app/build/outputs/apk/release/app-release.apk"
        "app/build/outputs/apk/release/app-release-unsigned.apk"
        "build/outputs/apk/debug/app-debug.apk"
        "build/outputs/apk/release/app-release.apk"
    )
    
    # Also use find command to search
    local found_apks=($(find . -name "*.apk" -type f 2>/dev/null | grep -E "(app-debug|app-release)" | head -10))
    
    if [ ${#found_apks[@]} -eq 0 ]; then
        print_error "No APK files found"
        echo ""
        echo "Please build the APK first:"
        echo "  ./gradlew assembleDebug"
        echo ""
        echo "Or specify the APK path:"
        echo "  $0 path/to/your-app.apk"
        exit 2
    fi
    
    if [ ${#found_apks[@]} -eq 1 ]; then
        echo "${found_apks[0]}"
        return 0
    fi
    
    # Multiple APKs found - prompt user
    print_warning "Multiple APK files found:"
    echo ""
    local i=1
    for apk in "${found_apks[@]}"; do
        local size=$(ls -lh "$apk" 2>/dev/null | awk '{print $5}')
        local date=$(ls -l "$apk" 2>/dev/null | awk '{print $6, $7, $8}')
        echo "  $i) $apk ($size, $date)"
        ((i++))
    done
    
    echo ""
    read -p "Select APK to install (1-${#found_apks[@]}): " selection
    
    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#found_apks[@]} ]; then
        print_error "Invalid selection"
        exit 2
    fi
    
    echo "${found_apks[$((selection-1))]}"
}

# Install APK to device
install_apk() {
    local device="$1"
    local apk_path="$2"
    
    # Verify APK file exists and is valid
    if [ ! -f "$apk_path" ]; then
        print_error "APK file not found: $apk_path"
        exit 2
    fi
    
    print_info "Installing APK to device $device..."
    print_info "APK: $apk_path"
    
    # Get package name from APK if aapt is available
    if command -v aapt &> /dev/null; then
        local package_name=$(aapt dump badging "$apk_path" 2>/dev/null | grep "package:" | sed -n "s/.*name='\([^']*\)'.*/\1/p")
        if [ -n "$package_name" ]; then
            print_info "Package: $package_name"
        fi
    fi
    
    echo ""
    
    # Install with -r flag (reinstall keeping data) and -g flag (grant permissions)
    # Using -s to specify device if provided
    if [ -n "$device" ]; then
        if adb -s "$device" install -r -g "$apk_path" 2>&1; then
            print_success "APK installed successfully!"
            
            # Try to launch the app if package name is known
            if [ -n "$package_name" ]; then
                echo ""
                read -p "Launch app now? (y/n): " launch
                if [ "$launch" = "y" ] || [ "$launch" = "Y" ]; then
                    # Get main activity name
                    local main_activity=$(aapt dump badging "$apk_path" 2>/dev/null | grep "launchable-activity" | sed -n "s/.*name='\([^']*\)'.*/\1/p" | head -1)
                    if [ -n "$main_activity" ]; then
                        print_info "Launching $package_name/$main_activity..."
                        adb -s "$device" shell am start -n "$package_name/$main_activity" > /dev/null 2>&1 || true
                    else
                        print_info "Launching $package_name..."
                        adb -s "$device" shell monkey -p "$package_name" 1 > /dev/null 2>&1 || true
                    fi
                fi
            fi
            
            return 0
        else
            print_error "Failed to install APK"
            echo ""
            echo "Common issues:"
            echo "  - Device storage full: Free up space on your device"
            echo "  - Signature mismatch: Uninstall existing app first with:"
            echo "    adb -s $device uninstall $package_name"
            echo "  - Insufficient permissions: Check USB debugging is enabled"
            echo "  - SDK version mismatch: Device Android version is too old for this APK"
            exit 3
        fi
    else
        if adb install -r -g "$apk_path" 2>&1; then
            print_success "APK installed successfully!"
            return 0
        else
            print_error "Failed to install APK"
            exit 3
        fi
    fi
}

# Main function
main() {
    local apk_arg="$1"
    
    # Show usage if --help is provided
    if [ "$apk_arg" = "--help" ] || [ "$apk_arg" = "-h" ]; then
        echo "Usage: $0 [path/to/app.apk]"
        echo ""
        echo "Install Android APK to connected device via adb"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Search for APKs"
        echo "  $0 app/build/outputs/apk/debug/app-debug.apk"
        echo "  $0 \"app-*.apk\"                        # Use glob"
        echo ""
        exit 0
    fi
    
    echo "======================================"
    echo "  Android APK Installer"
    echo "======================================"
    echo ""
    
    # Check prerequisites
    check_adb
    start_adb_server
    
    # Get connected devices
    print_info "Checking for connected devices..."
    local devices_list=$(check_devices)
    local devices=($devices_list)
    print_success "Found ${#devices[@]} device(s)"
    echo ""
    
    # Select device if multiple
    local selected_device
    if [ ${#devices[@]} -gt 1 ]; then
        selected_device=$(select_device "$devices_list")
        print_info "Selected device: $selected_device"
        echo ""
    else
        selected_device="${devices[0]}"
        print_info "Using device: $selected_device"
        echo ""
    fi
    
    # Find or use provided APK
    local apk_path=$(find_apk "$apk_arg")
    
    # Install APK
    install_apk "$selected_device" "$apk_path"
}

# Run main function with all arguments
main "$@"

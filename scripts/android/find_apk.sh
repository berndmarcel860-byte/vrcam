#!/bin/bash
#
# find_apk.sh - Find Android APK files in the project
#
# This script searches for Android APK files in common output locations
# and prints their paths. Useful for locating built APKs before installation.
#
# Usage:
#   ./find_apk.sh [--all] [--release] [--debug]
#
# Options:
#   --all      Show all APK files found (default)
#   --release  Show only release APK files
#   --debug    Show only debug APK files
#   --help     Display this help message
#
# Examples:
#   ./find_apk.sh              # Find all APKs
#   ./find_apk.sh --release    # Find only release APKs
#   ./find_apk.sh --debug      # Find only debug APKs
#
# Exit codes:
#   0 - APK files found
#   1 - No APK files found
#

# Colors for output (only if terminal supports it)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Parse arguments
show_release=1
show_debug=1

while [ $# -gt 0 ]; do
    case "$1" in
        --release)
            show_debug=0
            shift
            ;;
        --debug)
            show_release=0
            shift
            ;;
        --all)
            show_release=1
            show_debug=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--all] [--release] [--debug]"
            echo ""
            echo "Find Android APK files in the project"
            echo ""
            echo "Options:"
            echo "  --all      Show all APK files found (default)"
            echo "  --release  Show only release APK files"
            echo "  --debug    Show only debug APK files"
            echo "  --help     Display this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Get script directory to find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}Searching for APK files in: $PROJECT_ROOT${NC}"
echo ""

# Define search patterns for APK files
search_paths=(
    # Native Android / Gradle
    "*/app/build/outputs/apk/debug/*.apk"
    "*/app/build/outputs/apk/release/*.apk"
    "app/build/outputs/apk/debug/*.apk"
    "app/build/outputs/apk/release/*.apk"
    "build/outputs/apk/debug/*.apk"
    "build/outputs/apk/release/*.apk"
    
    # React Native
    "android/app/build/outputs/apk/debug/*.apk"
    "android/app/build/outputs/apk/release/*.apk"
    
    # Unity (common output locations)
    "Builds/Android/*.apk"
    "Build/Android/*.apk"
    "builds/android/*.apk"
    "build/android/*.apk"
    
    # Cordova / Ionic
    "platforms/android/app/build/outputs/apk/debug/*.apk"
    "platforms/android/app/build/outputs/apk/release/*.apk"
    "platforms/android/build/outputs/apk/debug/*.apk"
    "platforms/android/build/outputs/apk/release/*.apk"
)

# Array to store found APKs
declare -a debug_apks
declare -a release_apks
declare -a other_apks

# Search for APK files
cd "$PROJECT_ROOT"

for pattern in "${search_paths[@]}"; do
    # Expand glob pattern and check each match
    shopt -s nullglob
    matches=($pattern)
    shopt -u nullglob
    
    for apk in "${matches[@]}"; do
        # Check if file actually exists
        if [ -f "$apk" ]; then
            # Categorize APK
            if [[ "$apk" == *"debug"* ]]; then
                debug_apks+=("$apk")
            elif [[ "$apk" == *"release"* ]]; then
                release_apks+=("$apk")
            else
                other_apks+=("$apk")
            fi
        fi
    done
done

# Also use find as fallback to catch any missed APKs
while IFS= read -r apk; do
    # Normalize path (remove leading ./)
    normalized_apk="${apk#./}"
    
    # Skip if already in our arrays (check both original and normalized)
    already_found=0
    for existing in "${debug_apks[@]}" "${release_apks[@]}" "${other_apks[@]}"; do
        existing_normalized="${existing#./}"
        if [ "$normalized_apk" = "$existing_normalized" ]; then
            already_found=1
            break
        fi
    done
    
    if [ $already_found -eq 0 ]; then
        if [[ "$apk" == *"debug"* ]]; then
            debug_apks+=("$apk")
        elif [[ "$apk" == *"release"* ]]; then
            release_apks+=("$apk")
        else
            other_apks+=("$apk")
        fi
    fi
done < <(find . -type f -name "*.apk" 2>/dev/null | grep -v "\.gradle" | grep -v "unaligned")

# Display results
found_count=0

if [ $show_debug -eq 1 ] && [ ${#debug_apks[@]} -gt 0 ]; then
    echo -e "${GREEN}Debug APKs:${NC}"
    for apk in "${debug_apks[@]}"; do
        size=$(ls -lh "$apk" 2>/dev/null | awk '{print $5}')
        date=$(stat -c %y "$apk" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$apk" 2>/dev/null)
        echo "  $apk"
        echo "    Size: $size, Modified: $date"
        ((found_count++))
    done
    echo ""
fi

if [ $show_release -eq 1 ] && [ ${#release_apks[@]} -gt 0 ]; then
    echo -e "${YELLOW}Release APKs:${NC}"
    for apk in "${release_apks[@]}"; do
        size=$(ls -lh "$apk" 2>/dev/null | awk '{print $5}')
        date=$(stat -c %y "$apk" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$apk" 2>/dev/null)
        echo "  $apk"
        echo "    Size: $size, Modified: $date"
        
        # Check if APK is signed
        if command -v jarsigner &> /dev/null; then
            if jarsigner -verify "$apk" &>/dev/null; then
                echo "    Status: Signed ✓"
            else
                echo "    Status: Unsigned (needs signing for production)"
            fi
        fi
        ((found_count++))
    done
    echo ""
fi

if [ ${#other_apks[@]} -gt 0 ]; then
    echo -e "${BLUE}Other APKs:${NC}"
    for apk in "${other_apks[@]}"; do
        size=$(ls -lh "$apk" 2>/dev/null | awk '{print $5}')
        date=$(stat -c %y "$apk" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$apk" 2>/dev/null)
        echo "  $apk"
        echo "    Size: $size, Modified: $date"
        ((found_count++))
    done
    echo ""
fi

# Summary
if [ $found_count -eq 0 ]; then
    echo "No APK files found."
    echo ""
    echo "To build an APK, run:"
    echo "  ./gradlew assembleDebug      # For debug build"
    echo "  ./gradlew assembleRelease    # For release build"
    echo ""
    exit 1
else
    echo -e "${GREEN}Total: $found_count APK file(s) found${NC}"
    echo ""
    echo "To install an APK, use:"
    echo "  ./scripts/android/install_apk.sh <apk-path>"
    echo ""
    exit 0
fi

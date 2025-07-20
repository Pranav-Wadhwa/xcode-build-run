#!/bin/bash

# Helper function to build and run Xcode projects
# Usage: xcode_build_run <scheme> [destination]
# Default destination: iPhone 16 Pro simulator

xcode_build_run() {
    local scheme="$1"
    local destination="${2:-platform=iOS Simulator,name=iPhone 16 Pro}"
    
    # Check if scheme parameter is provided
    if [ -z "$scheme" ]; then
        echo "Error: Scheme parameter is required"
        echo "Usage: xcode_build_run <scheme> [destination]"
        return 1
    fi
    
    # Find the .xcodeproj or .xcworkspace file in current directory
    local project_file=""
    local workspace_flag=""
    
    # Check for workspace files first
    project_file=$(find . -maxdepth 1 -name "*.xcworkspace" | head -n 1)
    if [[ -n "$project_file" ]]; then
        workspace_flag="-workspace"
    else
        # Check for project files
        project_file=$(find . -maxdepth 1 -name "*.xcodeproj" | head -n 1)
        if [[ -n "$project_file" ]]; then
            workspace_flag="-project"
        else
            echo "Error: No .xcodeproj or .xcworkspace file found in current directory"
            return 1
        fi
    fi
    
    # Remove the ./ prefix from find output
    project_file=${project_file#./}
    
    echo "Building and running project: $project_file"
    echo "Scheme: $scheme"
    echo "Destination: $destination"
    echo ""
    
    # Build the project
    echo "Building project..."
    if xcodebuild $workspace_flag "$project_file" \
                   -scheme "$scheme" \
                   -destination "$destination" \
                   -configuration Debug \
                   build; then
        echo "\nBuild completed successfully!"
        
        # Extract simulator name from destination
        simulator_name=$(echo "$destination" | sed 's/.*name=\([^,]*\).*/\1/')
        
        # Get bundle identifier
        bundle_id=$(xcodebuild $workspace_flag "$project_file" \
                              -scheme "$scheme" \
                              -destination "$destination" \
                              -showBuildSettings 2>/dev/null | \
                   grep "PRODUCT_BUNDLE_IDENTIFIER" | \
                   head -n1 | \
                   sed 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = //')
        
        # Get the built app path (use fixed path for simulator builds)
        app_name=$(xcodebuild $workspace_flag "$project_file" \
                             -scheme "$scheme" \
                             -destination "$destination" \
                             -showBuildSettings 2>/dev/null | \
                  grep "^[[:space:]]*PRODUCT_NAME =" | \
                  head -n1 | \
                  sed 's/^[[:space:]]*PRODUCT_NAME = //')
        
        # Construct the app path for simulator builds
        derived_data_path=$(xcodebuild $workspace_flag "$project_file" \
                                      -scheme "$scheme" \
                                      -destination "$destination" \
                                      -showBuildSettings 2>/dev/null | \
                           grep "BUILD_ROOT" | \
                           head -n1 | \
                           sed 's/^[[:space:]]*BUILD_ROOT = //')
        
        app_path="$derived_data_path/Debug-iphonesimulator/$app_name.app"
        
        echo "Launching app in simulator..."
        echo "Simulator: $simulator_name"
        echo "Bundle ID: $bundle_id"
        echo "App Path: $app_path"
        echo ""
        
        # Boot simulator (if not already running)
        xcrun simctl boot "$simulator_name" 2>/dev/null || true
        
        # Install the app
        if xcrun simctl install booted "$app_path"; then
            # Launch the app
            xcrun simctl launch booted "$bundle_id"
            echo "\nApp launched successfully in $simulator_name!"
        else
            echo "\nFailed to install app in simulator"
            return 1
        fi
    else
        echo "\nBuild failed!"
        return 1
    fi
}

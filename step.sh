#!/bin/bash

set -x

# We want to work with ionic and cordova
npm install -g cordova@${cordova_version} ionic@${ionic_version} || exit 1

# Then we can install all packages
npm install || exit 1

# Install dependencies if missing
if [ "${ionic_version}" = "3" ]; then
    npm install @ionic/cli-plugin-ionic-angular@latest @ionic/cli-plugin-cordova@latest
fi

# Create www directory if it's not exist
mkdir -p www

# Add platform because it should not exist
if [ "${ionic_version}" = "3" ]; then
    ionic cordova platform add ${build_for_platform} 2>&1 || exit 1
else
    ionic platform add ${build_for_platform} || exit 1
fi

# Build the project
if [ "${ionic_version}" = "3" ]; then
    ionic cordova build ${build_for_platform} ${build_parameters} 2>&1 || exit 1
else
    ionic build ${build_for_platform} ${build_parameters} || exit 1
fi

if [ "${build_for_platform}" = "ios" ]; then
    # Lets find the project path(s)
    if [ -z "${BITRISE_PROJECT_PATH}" ]; then
        for xcodeprojFolder in ./platforms/ios/*.xcodeproj
        do
            envman add --key BITRISE_PROJECT_PATH --value "${xcodeprojFolder}"
            echo "Set to ${BITRISE_PROJECT_PATH} or $BITRISE_PROJECT_PATH"
            BITRISE_PROJECT_PATH="${xcodeprojFolder}"
        done
        if [ -z "${BITRISE_PROJECT_PATH}" ]; then
            for xcworkspaceFolder in ./platforms/ios/*.xcworkspace
            do
                envman add --key BITRISE_PROJECT_PATH --value "${xcworkspaceFolder}"
                BITRISE_PROJECT_PATH="${xcworkspaceFolder}"
            done
        fi
    fi

    # Now try to change provisioning style
    sed -i -e 's/attributes = {/attributes = { TargetAttributes = { 1D6058900D05DD3D006BFB54 = { ProvisioningStyle = '"${ios_provisioning_style}"'; }; };/g' "${BITRISE_PROJECT_PATH}/project.pbxproj"
    sed -i '' 's/ProvisioningStyle = Automatic;/ProvisioningStyle = '"${ios_provisioning_style}"';/' "${BITRISE_PROJECT_PATH}/project.pbxproj"
else
    # If we have multiple apk files then we should manage the situation
    APK_PATHS=""
    for apkFile in ./platforms/android/build/outputs/apk/*.apk
    do
        echo "Found file: ${apkFile}"
        if [[ "${apkFile}" == *"-armv7-"* ]]; then
            # We need this because the sign script is not able to handle multiple files at the moment (PR is out!)
            if [ -z "${BITRISE_APK_PATH}" ]; then
                envman add --key BITRISE_APK_PATH --value "${apkFile}"
                BITRISE_APK_PATH="${apkFile}"
            fi
            envman add --key BITRISE_APK_PATH_ARMV7 --value "${apkFile}"
            BITRISE_APK_PATH_ARMV7="${apkFile}"
        elif [[ "${apkFile}" == *"-x86-"* ]]; then
            envman add --key BITRISE_APK_PATH_X86 --value "${apkFile}"
            BITRISE_APK_PATH_X86="${apkFile}"
        elif [ -z "${BITRISE_APK_PATH}" ]; then
            envman add --key BITRISE_APK_PATH --value "${apkFile}"
            BITRISE_APK_PATH="${apkFile}"
        fi
        APK_PATHS+="${apkFile}|"
    done

    APK_PATHS=${APK_PATHS%|*}

    if [ ! -z "${APK_PATHS}" ] && [ -z "${BITRISE_APK_PATH}" ]; then
        envman add --key BITRISE_APK_PATH --value "${APK_PATHS[*]}"
        BITRISE_APK_PATH="${APK_PATHS[*]}"
    fi
fi

exit 0

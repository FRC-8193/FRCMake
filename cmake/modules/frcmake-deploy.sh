#!/bin/bash

# Pushes and starts robot code 

TEAM_NUMBER=$1
PROGRAM=$2
LIBRARIES=("${@:3}")

print_usage() {
    echo "Usage: $0 <target> <program> [libraries]"
    echo "  target    - The RoboRio's IP or team number to deploy to"
    echo "  program   - The path to the robot program executable to deploy"
    echo "  libraries - [Optional] A list of shared library files to deploy"
}

if [ -z "$TEAM_NUMBER" ]; then
    echo "error: target is unspecified"
    print_usage
    exit 1
fi
if [ -z "$PROGRAM" ]; then
    echo "error: program is unspecified"
    print_usage
    exit 1
fi

if [ ! -f "$PROGRAM" ]; then
    echo "error: $PROGRAM (program) does not exist"
    print_usage
    exit 1
fi

for LIB in "${LIBRARIES[@]}"; do
    if [ ! -f "$LIB" ]; then
        echo "error: $LIB (library) does not exist"
	print_usage
	exit 1
    fi
done

TARGET_USER=lvuser
TARGET_DIR=/home/lvuser/FRCMakeProgram
ROBOTCOMMAND_DIR=/home/lvuser
CONTROL_PATH="/tmp/ssh-mux-$TARGET_USER"

# Start a persistent SSH connection
start_ssh_multiplexing() {
    local target="$1"
    ssh -o ControlMaster=auto -o ControlPath="$CONTROL_PATH" -o ControlPersist=10m -MNf "$TARGET_USER@$target" 2>/dev/null || true
}

# Close the persistent connection
stop_ssh_multiplexing() {
    local target="$1"
    ssh -o ControlPath="$CONTROL_PATH" -O exit "$TARGET_USER@$target" 2>/dev/null || true
}

deploy_program() {
    local target="$1"
    echo "RoboRio found at $target, deploying..."

    start_ssh_multiplexing "$target"

    echo "Kill running robot code"
    echo "Create program directory"
    ssh -o ControlPath="$CONTROL_PATH" "$TARGET_USER@$target" ". /etc/profile.d/natinst-path.sh &&
                                                                export PATH=\"\${PATH}:/usr/local/frc/bin\" &&
    							                                /usr/local/frc/bin/frcKillRobot.sh -t;
							                                    mkdir -p $TARGET_DIR"

    echo "Copy new robot program"
    scp -o ControlPath="$CONTROL_PATH" "$PROGRAM" "$TARGET_USER@$target:$TARGET_DIR/FRCUserProgram"

    for lib in ${LIBRARIES[@]}; do
	echo "Copy library $(basename $lib)"
	echo "  Check if file needs update..."

	local_sha256=$(sha256sum $lib | cut -d" " -f1)
	remote_sha256=$(ssh -o ControlPath="$CONTROL_PATH" "$TARGET_USER@$target" "sha256sum $TARGET_DIR/$(basename $lib)" | cut -d" " -f1)

	file_needs_update=0

	if [ ! -z "$local_sha256" ] && [ ! -z "$remote_sha256" ] && [ "$local_sha256" == "$remote_sha256" ]; then
	    echo "  SHA256 matches, check MD5"

	    local_md5=$(md5sum $lib | cut -d" " -f1)
	    remote_md5=$(ssh -o ControlPath="$CONTROL_PATH" "$TARGET_USER@$target" "md5sum $TARGET_DIR/$(basename $lib)" | cut -d" " -f1)
	
	    if [ ! -z "$local_md5" ] && [ ! -z "$remote_md5" ] && [ "$local_md5" == "$remote_md5" ]; then
		echo "  MD5 matches"
            else
		file_needs_update=1
		echo "  MD5 does not match"
	    fi
        else
	    file_needs_update=1
	    echo "  SHA256 does not match"
	fi

	if [ ! $file_needs_update == 0 ]; then
	    echo "$(basename $lib) needs update"
	    scp -o ControlPath="$CONTROL_PATH" "$lib" "$TARGET_USER@$target:$TARGET_DIR/$(basename $lib)"
        else
	    echo "$(basename $lib) does not need update"
	fi
    done

    echo "Kill network console"
    ssh -o ControlPath="$CONTROL_PATH" "$TARGET_USER@$target" "killall -q netconsole-host || :"

    echo "Upload new robotCommand"
    ssh -o ControlPath="$CONTROL_PATH" "$TARGET_USER@$target" "echo \"export LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH:$TARGET_DIR\"; $TARGET_DIR/FRCUserProgram\" > $ROBOTCOMMAND_DIR/robotCommand &&
	    						                                chmod a+x $TARGET_DIR/FRCUserProgram &&
							                                    chmod a+x $ROBOTCOMMAND_DIR/robotCommand"

    echo "Restart robot code"
    ssh -o ControlPath="$CONTROL_PATH" "$TARGET_USER@$target" "sync && 
	      						                                . /etc/profile.d/natinst-path.sh &&
                                                                export PATH=\"\${PATH}:/usr/local/frc/bin\" &&
                                                                /usr/local/frc/bin/frcKillRobot.sh -t -r"

    stop_ssh_multiplexing "$target"
}

probe_and_deploy_program() {
    local target="$1"
    echo -n "Searching for RoboRio at $target..."

    if ping -c 1 -W 1 "$target" > /dev/null 2>&1 && ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$TARGET_USER@$target" true > /dev/null 2>&1; then
        echo
        deploy_program "$target"
	exit
    fi
    echo "Not found."
}

if [[ $TEAM_NUMBER =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    TARGET=$TEAM_NUMBER
    echo "Using IP $TARGET"
    probe_and_deploy_program "$TARGET"
    exit
fi

# Try mDNS, static IP, and Ethernet-over-USB
TEAM_NUMBER_D=$(printf "%04d" "$TEAM_NUMBER")
P1=${TEAM_NUMBER_D:0:2}
P2=${TEAM_NUMBER_D:2:2}
TARGET="10.$P1.$P2.2"
probe_and_deploy_program "$TARGET"

TARGET="roborio-$TEAM_NUMBER-frc.local"
probe_and_deploy_program "$TARGET"

probe_and_deploy_program "172.22.11.2"

echo "Not found - giving up."
exit 1

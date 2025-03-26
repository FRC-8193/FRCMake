#!/bin/bash
# Based on https://github.com/Team973/2017-inseason/blob/master/deploy

# FRC team number
TEAM_NUMBER=$1

# Path (on host) of the program to deploy
PROGRAM=$2

# Command to run to start the robot
ROBOTCOMMAND=${3:-"/home/lvuser/FRCUserProgram"}

# These should never change
TARGET_USER=lvuser
TARGET_DIR=/home/lvuser

deploy_program() {
    local target="$1"
    echo "Rio found at $target, deploying..."
  
    echo "Remove existing robot program"
    ssh "$TARGET_USER@$target" "rm -f $TARGET_DIR/FRCUserProgram" > /dev/null 2>&1
    echo "Copy new robot program"
    scp "$PROGRAM" "$TARGET_USER@$target:$TARGET_DIR/FRCUserProgram" > /dev/null 2>&1
    echo "Kill network console"
    ssh "$TARGET_USER@$target" "killall -q netconsole-host || :" > /dev/null 2>&1
    echo "Copy robot startup command"
    scp "$ROBOTCOMMAND" "$TARGET_USER@$target:$TARGET_DIR" > /dev/null 2>&1
    echo "Restart robot code"
    ssh "$TARGET_USER@$target" ". /etc/profile.d/natinst-path.sh;
                                 chmod a+x $TARGET_DIR/FRCUserProgram;
                                 /usr/local/frc/bin/frcKillRobot.sh -t -r;
                                 sync" > /dev/null 2>&1
    exit # We don't want to do anything more after deploying
}

probe_and_deploy_program() {
	local target="$1"
	echo -n "Searching for Rio at $target..."
	
	# Check if the target even exists
	ping -c 1 -W 1 $target > /dev/null 2>&1 && \
	# Check if SSH is open and the target has 'lvuser' (standard for RoboRIO)
	ssh "$TARGET_USER@$target" true > /dev/null 2>&1 && \
	echo && deploy_program "$target"
	echo "Not found."
}

# mDNS (roborio-TEAM-frc.local)
TARGET="roborio-$TEAM_NUMBER-frc.local"
probe_and_deploy_program $TARGET

# Local IP (10.TE.AM.2)
TEAM_NUMBER=$(printf "%04d" "$TEAM_NUMBER")
P1=${TEAM_NUMBER:0:2}
P2=${TEAM_NUMBER:2:2}
TARGET="10.$P1.$P2.2"
probe_and_deploy_program $TARGET

# Ethernet-over-USB
probe_and_deploy_program "172.22.11.2"

# womp womp
echo "Not found - giving up."
exit 1


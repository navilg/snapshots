#!/usr/bin/env bash

snapshotName="backup"
maxSnap=5
backupDir="/home/navi/MyWorkspace/snapshots"
includeFile="/home/navi/MyWorkspace/snapshots/include.list"
excludeFile="/home/navi/MyWorkspace/snapshots/exclude.list"

if [ "${EUID}" -ne 0 ]; then
    echo "Run as root"
    exit 1
fi

mkdir "$backupDir" > /dev/null 2>&1

maxSnapNum=$(expr $maxSnap - 1)

if [ -d "$backupDir/$snapshotName.$maxSnapNum" ]; then
    mv "$backupDir/$snapshotName.$maxSnapNum" "$backupDir/$snapshotName.$maxSnapNum.backup"
fi

init=$(expr $maxSnapNum - 1)

for i in $(seq $init -1 0); do
    j=$(expr $i + 1)
    if [ ! -d "$backupDir/$snapshotName.$i" ]; then
        continue
    fi

    if [ $i -eq 0 ]; then
        cp -al "$backupDir/$snapshotName.$i" "$backupDir/$snapshotName.$j"
        continue
    fi
    mv "$backupDir/$snapshotName.$i" "$backupDir/$snapshotName.$j"  
done

mkdir "$backupDir/$snapshotName.0" > /dev/null 2>&1
chmod 0755 "$backupDir/$snapshotName.0"

while read line
do
    if [ -e "$line" ]; then
        rsync -a --delete --numeric-ids --relative --delete-excluded --exclude-from="$excludeFile" "$line" "$backupDir/$snapshotName.0/"
    fi
done < "$includeFile"
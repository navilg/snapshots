#!/usr/bin/env bash

source snapshot.properties
datetime=$(date "+%Y-%m-%d %H:%M:%S")
datetimenum=$(date "+%Y%m%d%H%M%S")
statusfile="$backupDir/$snapshotName.0/snapshot.status"
logfile="$logdir/snapshot.log"
statusflag=1

rootCheck()
{
    if [ "${EUID}" -ne 0 ]; then
        echo "Run as root"
        exit 1
    fi
}

renameExistingBackup()
{
    mkdir "$backupDir" > /dev/null 2>&1
    mkdir "$logdir" > /dev/null 2>&1
    echo "---------------" >> "$logfile"
    echo "$datetime" >> $logfile
    echo >> "$logfile"

    maxSnapNum=$(expr $maxSnap - 1)

    if [ -d "$backupDir/$snapshotName.$maxSnapNum" ]; then
        echo "Creating backup of $snapshotName.$maxSnapNum" | tee -a "$logfile"
        mv  "$backupDir/$snapshotName.$maxSnapNum" "$backupDir/$snapshotName.$maxSnapNum.$datetimenum.backup"
        echo "DONE... $snapshotName.$maxSnapNum.$datetimenum.backup created." | tee -a "$logfile"
    fi

    init=$(expr $maxSnapNum - 1)

    for i in $(seq $init -1 0); do
        j=$(expr $i + 1)
        if [ ! -d "$backupDir/$snapshotName.$i" ]; then
            continue
        fi

        if [ $i -eq 0 ]; then
            echo "$snapshotName.$i  -->  $snapshotName.$j" |  tee -a "$logfile"
            cp -al "$backupDir/$snapshotName.$i" "$backupDir/$snapshotName.$j"
            if [ $? -eq 0 ]; then
                echo "DONE" |  tee -a "$logfile"
            else
                echo "ERROR Detected."
                statusflag=0
                break
            fi
            continue
        fi
        echo "$snapshotName.$i  -->  $snapshotName.$j" |  tee -a "$logfile"
        mv "$backupDir/$snapshotName.$i" "$backupDir/$snapshotName.$j"
        if [ $? -eq 0 ]; then
            echo "DONE" |  tee -a "$logfile"
        else
            echo "ERROR Detected."
            statusflag=0
            break
        fi 

    done
}

createBackup()
{
    echo "Creating $snapshotName.0" | tee -a "$logfile"
    mkdir "$backupDir/$snapshotName.0" > /dev/null 2>&1
    chmod 0755 "$backupDir/$snapshotName.0"

    echo "$datetime" > "$statusfile"
    echo "--------------------" >> "$statusfile"
    echo >> "$statusfile"

    while read line
    do
        if [ -e "$line" ]; then
            echo "Backup ... $line  -->  $backupDir/$snapshotName.0/" | tee -a "$logfile"
            rsync -a --delete --numeric-ids --relative --delete-excluded --exclude-from="$excludeFile" --log-file="$logfile" "$line" "$backupDir/$snapshotName.0/"
            if [ $? -eq 0 ]; then
                echo "DONE" | tee -a "$logfile"
                echo "$line,OK" >> "$statusfile"
            else
                echo "ERROR Detected." | tee -a "$logfile"
                echo "$line,KO" >> "$statusfile"
                statusflag=0
            fi
        fi
    done < "$includeFile"

    if [ $statusflag -eq 1 ]; then
        if [ -d "$backupDir/$snapshotName.$maxSnapNum.$datetimenum.backup" ]; then
            echo "Deleting $snapshotName.$maxSnapNum.$datetimenum.backup" | tee -a "$logfile"
            rm -rfv "$backupDir/$snapshotName.$maxSnapNum.$datetimenum.backup" >> "$logfile"
            echo "Backup successfully created." | tee -a "$logfile"
        fi
        exit 0
    else
        echo "ERROR detected while backing up." | tee -a "$logfile"
        echo "Retaining backed-up backup as $snapshotName.$maxSnapNum.$datetimenum.backup" | tee -a "$logfile"
        exit 1
    fi
}

resumeBackup()
{
    echo "Resuming $snapshotName.0" | tee -a "$logfile"
    mkdir "$backupDir/$snapshotName.0" > /dev/null 2>&1
    chmod 0755 "$backupDir/$snapshotName.0"

    resumestatus=0

    while read line
    do
        if [[ $(grep -i "$line" "$statusfile" | cut -d "," -f 2) == "OK" ]]; then
            continue
        fi
        resumestatus=1
        if [ -e "$line" ]; then
            echo "Backup ... $line  -->  $backupDir/$snapshotName.0/" | tee -a "$logfile"
            rsync -a --delete --numeric-ids --relative --delete-excluded --exclude-from="$excludeFile" --log-file="$logfile" "$line" "$backupDir/$snapshotName.0/"
            if [ $? -eq 0 ]; then
                echo "DONE" | tee -a "$logfile"
                if [[ $(grep -i "$line" "$statusfile" | cut -d "," -f 2) == "KO" ]]; then
                    sed -i "s@$line,KO@$line,OK@g" "$statusfile"
                else
                    echo "$line,OK" >> "$statusfile"
                fi
            else
                echo "ERROR Detected." | tee -a "$logfile"
                statusflag=0
            fi
        fi
    done < "$includeFile"

    if [ $resumestatus -eq 0 ]; then
        echo "Upto date. Nothing remaining to backup." | tee -a "$logfile"
        exit 0
    elif [ $statusflag -eq 1 ]; then
        echo "Backup successfully created." | tee -a "$logfile"
        exit 0
    else
        echo "ERROR detected while backing up." | tee -a "$logfile"
        exit 1
    fi
}

###########################

rootCheck
if [ $# -eq 0 ]; then
    renameExistingBackup
    createBackup
elif [ $(echo "$1" | tr [:upper:] [:lower:]) == "resume" ]; then
    resumeBackup
else
    echo "To create new backup, run, snapshot.sh"
    echo "To resume a failed backup, run, snapshot.sh resume"
fi
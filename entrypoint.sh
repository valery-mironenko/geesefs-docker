#!/usr/bin/env bash

set -e

# Defaults
AWS_S3_MOUNTPOINT=${AWS_S3_MOUNTPOINT:='/mnt'}
AWS_S3_URL=${AWS_S3_URL:='https://s3.amazonaws.com'}
USER_ID=${USER_ID:-1000}
GROUP_ID=${GROUP_ID:-1000}
FUSE_ALLOW_OTHER=${FUSE_ALLOW_OTHER:-false}

err=0

# check vars
if [ -z "$AWS_ACCESS_KEY_ID" ]
    then
    echo "Error: AWS_ACCESS_KEY_ID is not specified"
    err=1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]
    then
    echo "Error: AWS_SECRET_ACCESS_KEY is not specified"
    err=1
fi

if [ -z "$AWS_STORAGE_BUCKET_NAME" ]
    then
    echo "Error: AWS_STORAGE_BUCKET_NAME is not specified"
    err=1
fi

if [ $err -eq 1 ]
    then
    exit 1
fi

GROUP=$(getent group "$GROUP_ID" | cut -d":" -f1)
if [ $GROUP_ID -gt 0 ] && [ -z "$GROUP" ]
    then
    addgroup --gid $GROUP_ID geesefs
    GROUP=geesefs
fi

if [ $USER_ID -gt 0 ]
    then
    USER=$(getent passwd "$USER_ID" | cut -d":" -f1)
    if [ -z "$USER" ]; then
        adduser geesefs --system --shell /bin/sh --uid $USER_ID --gid $GROUP_ID
        USER=geesefs
    fi
    chown $USER:$GROUP $AWS_S3_MOUNTPOINT
fi

if [ "$FUSE_ALLOW_OTHER" = "true" ]
    then
    echo "user_allow_other" >> /etc/fuse.conf
    OPT="-o allow_other"
else
    OPT=
fi

exit_script() {
    echo "Caught signal! Unmounting ${AWS_S3_MOUNT}..."
    proc=$(ps -e -o pid= -o comm= | grep geesefs|grep -v grep | awk '{ print $1; }')
    if [ -n "$proc" ]
        then
        kill -9 "$proc"
    fi
    for i in 1 2 3 4 5
        do
        fusermount -u "${AWS_S3_MOUNTPOINT}" && break
        sleep 1
    done
    exit
}

trap "exit_script " SIGINT SIGQUIT SIGHUP SIGTERM


echo "==> Mounting S3 Filesystem from AWS_S3_URL=$AWS_S3_URL"
mkdir -p ${AWS_S3_MOUNTPOINT}


su --preserve-environment $USER -c "/bin/geesefs-linux-amd64 -f $OPT --endpoint $AWS_S3_URL $AWS_STORAGE_BUCKET_NAME $AWS_S3_MOUNTPOINT" &
wait

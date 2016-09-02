#!/bin/ash

if [ ! -z $PASSWORD ]; then
    echo "Setting password for autossh user."
    echo "autossh:$PASSWORD" | chpasswd
else
    echo "If you wish to set a password for autossh user,"
    echo "provide it in the PASSWORD env variable when"
    echo "you start the container."
fi

echo
echo "Starting SSH server"
exec /usr/sbin/sshd -D

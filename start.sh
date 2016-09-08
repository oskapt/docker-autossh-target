#!/bin/ash

if [ ! -z $PASSWORD ]; then
    echo "Setting password for autossh user."
    echo "autossh:$PASSWORD" | chpasswd
else
    echo "If you wish to set a password for autossh user,"
    echo "provide it in the PASSWORD env variable when"
    echo "you start the container."
    echo 
    
    PASSWORD=$(head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9~!@#$%^&*_-' | fold -w 15 | head -n 1)
    echo "Setting random password for autossh user: $PASSWORD"
    echo "autossh:$PASSWORD" | chpasswd
fi

# Set directory perms in case we are mounting a volume
chown -R autossh:autossh /home/autossh/.ssh

echo
echo "Starting SSH server"
exec /usr/sbin/sshd -D

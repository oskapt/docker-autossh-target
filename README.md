# AutoSSH Target

This is a container to keep your SSH connections in an isolated environment. I use it as a target for remote environments using [AutoSSH](http://www.harding.motd.ca/autossh/).

## Why Bother?

I manage many environments remotely. I've started using the [Lan Turtle](http://www.lanturtle.com) from [Hak5](http://hak5.org) to do so, leveraging [OpenVPN Access Server](https://openvpn.net/index.php/access-server/overview.html) and [AutoSSH](http://www.harding.motd.ca/autossh/). It's important that I keep these environments distinct - traffic traversing one tunnel should not be able to access any other tunnel to any other environment, no matter how secure I believe those connections to be.

Enter this container. With this, it's possible to fire up an unlimited number of isolated SSH environments, each totally oblivious to the others, and all of them separated from the actual host where the containers are running.

## Why This Container Over Others?

There are other SSH containers. I looked at some of them. Many make unnecessary assumptions about the environment and are targeted at proof-of-concept rather than production use. One of the first issues I encountered was how to get the public key from the remote host into the container securely. This requires SSH with a password, and other containers use insecure passwords and do not provide any way to change them.

One of the best features of this container is how it handles passwords. If you provide a password in the `PASSWORD` variable, the container will set that password for the `autossh` user. If not, it will generate a random 15-character _strong_ password and set that instead. This password is printed to stdout. You can use `scp` to bring over the remote user's public key via the very same SSH channel you will use for future connections. This validates that the container works while keeping communication secure. Once you've brought over the key, you can bounce the container to generate a new random password.

The container also uses the [dumb-init](https://github.com/Yelp/dumb-init) init system from Yelp. This keeps signal processing within the container sane.

Finally, it's built on top of [Alpine Linux](https://github.com/gliderlabs/docker-alpine/blob/master/docs/usage.md) to keep the image size small.

## Getting Started

In the examples below I'm using the following ports:

  * **2209**: Public port mapped to container SSH port. This is the port that a remote host will connect to via SSH to log into the container. If you're using AutoSSH from some host out in the Internet, it will connect to this port.
  * **2222**: Container port mapped to remote host. This is the port that the remote AutoSSH host will forward back to its local SSH daemon on port 22
  * **22229**: Private port mapped from the Docker host directly to the forwarded port inside the container. This is for convenience and will be explained later.

I'll also use a host volume mounted from `/opt/docker/autossh-target/ssh_home` to `/home/autossh/.ssh` inside the container. If you already have the public key for your remote user, you can create this directory and put that key into `authorized_keys` within the directory. Set its mode to `0600` with `chmod` and when you start the container, you'll be able to log in.

Don't worry if you don't have the key yet; I'll provide a workflow for installing it.

Finally, I'll be using the following host references:

  * **Docker host** (`dockerhost`): the host where the container is running. This has an IP and is connected to the Internet. From the ports list above, this host exposes port 2209.
  * **Remote host** (`remotehost`): The host out on the Internet from which you'll be initiating an SSH connection. If using AutoSSH, it runs here.
  * **Container** (`autossh`): this container. It is the target for your remote host SSH connection.

### Pull It

The easiest way to get started is to just pull the container.
```
dockerhost:~$ docker pull monachus/autossh-target
```
### Build It

You can also build it. If you know the public key for your remote user, you can add it to `authorized_keys` in the build environment, and it will be copied into the container. Doing it this way means that you don't need the host volume configured during the startup, and it may be more convenient for you.
```
dockerhost:~$ docker build -t monachus/autossh-target .
```

### Start It

```
dockerhost:~$ docker run --rm --name autossh \
-p 2209:22 -p 127.0.0.1:22229:2222 \
-v /opt/docker/autossh/ssh_home:/home/autossh/.ssh \
monachus/autossh-target

If you wish to set a password for autossh user,
provide it in the PASSWORD env variable when
you start the container.

Setting random password for autossh user: fGOx2^pxEJ@9gR3
Password for 'autossh' changed

Starting SSH server
```
This sets up the ports and host volume as described above.

### Connect!

(You might need to open your inbound port via `iptables`, `ufw`, an external firewall, or a network policy. If you're here, you probably already know how to do that. If not, go figure it out and then come back.)

From your remote host, make a connection to your Docker host on the designated port:
```
remotehost:~$ ssh -p 2209 -R2222:localhost:22 autossh@dockerhost.example.com
The authenticity of host '[localhost]:2209 ([::1]:2209)' can't be established.
ECDSA key fingerprint is 83:4b:76:ca:b6:04:c1:1e:3f:4c:69:8f:45:21:a6:36.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[localhost]:2209' (ECDSA) to the list of known hosts.
autossh@localhost's password:

24401519d2d6:~$
```
You should now be able to see port 2222 listening from within the container:
```
dockerhost:~$ docker exec autossh netstat -lnt
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 0.0.0.0:2222            0.0.0.0:*               LISTEN
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN
tcp        0      0 :::2222                 :::*                    LISTEN
tcp        0      0 :::22                   :::*                    LISTEN
```

Congratulations! Read on for options on how to connect to your remote host.

### Copy In Your Public Key (Optional)

If you didn't know your remote host's public key when building the container (or if you're using the same container multiple times for multiple remote hosts), you'll have to use `scp` to bring over the public key.

The LAN Turtle has an option for bringing over the public key and appending it to `authorized_keys` for you. If you're using a different system as your remote host, execute the following:
```
remotehost:~$ cat ~/.ssh/id_rsa.pub | ssh -p 2209 autossh@dockerhost.example.com tee -a .ssh/authorized_keys
```
This will append the public key to `authorized_keys`, after which you should be able to log in without a password. For extra security, bounce the container to reset the password.

## Connecting Back To Your Remote Host

Technically this has nothing to do with the container, but I want to give you the full solution. You have two ways for connecting back to `remotehost` over the tunnel that it opens up. One is from within the container, and the other is from outside of the container. Either way is fine - it depends on how you want to structure your workflow and the commands that you want to type.

### Connecting From Within The Container

The sloppy way would be to exec `/bin/ash` to get a shell in the container and then run `ssh` from there. Yuck.

You could instead fire the `ssh` command directly as part of your exec:

```
dockerhost:~$ docker exec -it autossh ssh -p 2222 user@localhost
```

Okay, but now you have to remember your user, the port, and so on. Let's clean it up.

This will presume that you mounted a host volume when you started the container, and that it lives under `/opt/docker/autossh/ssh_home` as in the startup above.

We want to create `~/.ssh/config` for the `autossh` user. That equates to `/opt/docker/autossh/ssh_home/config` on our Docker host. Inside that file, we want to put the following:
```
Host remotehost
  User user
  Port 2222
  Hostname localhost
```
This sets up an SSH command like that which we used above, but allows us to instead do the following:
```
dockerhost:~$ docker exec -it autossh ssh remotehost
```
Cleaner, right? Sure, but we can do better.

### Connecting _Through_ The Container

When we created our port mapping, we mapped `22229` off of `localhost` to `2222` within the container. We can use this to SSH directly from our Docker host, through the container, to the remote host.

Create an entry in _your_ `~/.ssh/config` on the Docker host that looks like the following:
```
Host remotehost
  User user
  Port 22229
  Hostname localhost
```
Now, from the Docker host, you only need to run the following:
```
dockerhost:~$ ssh remotehost
```
This will connect you to `22229` on localhost, which Docker maps to `2222` inside the container, which is a tunnel back to `22` on `remotehost`.

And like that, you have secure SSH isolation within Docker and almost no change at all to your workflow.

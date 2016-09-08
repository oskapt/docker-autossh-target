FROM gliderlabs/alpine

MAINTAINER Adrian Goins <mon@chus.cc>

# Do our basic installation and setup
RUN apk add --no-cache openssh openssl ca-certificates \
    && update-ca-certificates \
    && ssh-keygen -A \
    && sed -i 's/^#GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config \
    && adduser -D autossh \
    && mkdir /home/autossh/.ssh 

# Add our init system
RUN wget -O /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.1.3/dumb-init_1.1.3_amd64 \
    && chmod +x /usr/bin/dumb-init

# Copy in our startup and key files
ADD start.sh /start.sh
ADD authorized_keys /home/autossh/.ssh/authorized_keys

# Set ownership correctly
RUN chown -R autossh:autossh /home/autossh

# Rock the startup
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/start.sh"]

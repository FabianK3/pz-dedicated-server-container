FROM ubuntu:26.04 AS build

# Install SteamCMD and dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates software-properties-common \
    && add-apt-repository -y multiverse \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && printf 'steam steam/question select I AGREE\nsteam steam/license note ""\n' | debconf-set-selections \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends steamcmd \
    && rm -rf /var/lib/apt/lists/*

# Set up Project Zomboid server directory
RUN mkdir -p /opt/pzserver \
    && chown ubuntu:ubuntu /opt/pzserver

USER ubuntu
WORKDIR /home/ubuntu

# Download and install Project Zomboid server using SteamCMD
RUN /usr/games/steamcmd \
    +force_install_dir /opt/pzserver/ \
    +login anonymous \
    +app_update 380870 validate \
    +quit

FROM ubuntu:26.04 AS server

# Expose env configurations
ENV MAX_RAM_ALLOC_GB=8 \
    AUTO_UPDATE_MODS=true \
    AUTO_RESTART_HOURS="24"

# Dependencies for server and toolchain
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

# Copy the built Project Zomboid server from the build stage
COPY --from=build --chown=ubuntu:ubuntu /opt/pzserver/ /opt/pzserver/
COPY --chown=ubuntu:ubuntu src/entrypoint.sh /opt/pzserver/entrypoint.sh
# Add helper scripts for first boot and admin
COPY --chmod=755 --chown=ubuntu:ubuntu src/set-admin-password.sh /opt/pzserver/set-admin-password.sh
COPY --chmod=755 --chown=ubuntu:ubuntu src/add-player-admin.sh /opt/pzserver/add-player-admin.sh

# Directory pathing for workshop mount
RUN mkdir -p /opt/pzserver/steamapps/workshop \
    && chown ubuntu:ubuntu /opt/pzserver/steamapps/workshop

USER ubuntu
WORKDIR /opt/pzserver

VOLUME ["/home/ubuntu/Zomboid", "/opt/pzserver/steamapps/workshop"]
EXPOSE 16261/udp 16262/udp
ENTRYPOINT ["/bin/bash", "/opt/pzserver/entrypoint.sh"]

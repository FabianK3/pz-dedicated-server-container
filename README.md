# Project Zomboid dedicated server as container

This project contains the build and configuration for running a Project Zomboid dedicated server in a container.

> [!CAUTION]
> Due to how Project Zomboid dedicated servers work, this approach is explictly discouraged by Zomboid Devs.
> This approach was created during PZ build 42.21.0 and tested with a small player base (October 2026).
> You can find more information on this approach on the official PZ wiki under the Systemd section.
> Use on your own risk.

## TL;DR

1. Acknowledge caution note above.
2. `make build`
3. Check the `compose.yml` and adjust if needed. Make sure the volume binds exists and a write-able.
4. `docker compose up`

## Requirements

Docker, Docker Compose (optional but highly recommended) and Make.

## Setup

### Build

Everything needed is handled in the Dockerfile. It runs SteamCMD, pulls the newest version of the PZ dedicated server and builds it.

Run `make build`.

### Data

The container features two volume mount points:

- ./volumes/data:/home/ubuntu/Zomboid # Server configuration, world data, misc. server data
- ./volumes/mods:/opt/pzserver/steamapps/workshop # Mod cache - Do not re-use this dir for multiple servers

Before starting the server with compose (or any other orchastration tool), make sure these mount dirs exist on the host or set them to named volumes.

The bind-mounted directories must be writable by the container's `ubuntu` user (UID/GID 1000).

### Networking

The PZ server in the container is listening to the default ports UDP 16261 and 16262.  
*Do not changes these ports in the server.ini configuration file, instead change the ports specified in the compose file!*

### Run

Once build was finished, you will have the `pzserver` container image.  
You can either start it manually using `make start` or with compose `make start-compose`.

If you need to move the image to another host, use `make export` to receive the file `pzserver.tar`.  
On the target host, use `docker load -i pzserver.tar` to import the image and then continue with the `compose.yml`.

If you aren't using make to start/stop the server (which is made for build and debugging primarily), the compose file:  
`docker compose up -d` and `docker compose down`.

**Note:** Both the Make and compose approach make use of host-bind volumes, see below!

During first boot the PZ Server prompts for an admin password, watch the boot process using the docker logs (`docker logs -f pzserver`) and wait for the prompt, then run:

```sh
docker exec -it pzserver ./set-admin-password.sh
```

To grant admin access to a player who has already connected once, you can run:

```sh
docker exec -it pzserver ./add-player-admin.sh
```

From here on all configuration can be found in the `./volumes/data:/home/ubuntu/Zomboid` volume.  
Most if not everything can be configured ingame using an admin account.

### Compose configuration

Edit `compose.yaml` before starting the container:

| Setting | Compose value | Behavior |
| --- | --- | --- |
| `MAX_RAM_ALLOC_GB` | `8` | Maximum JVM heap in GiB; minimum is 2. |
| `AUTO_UPDATE_MODS` | `"true"` | Check for Workshop updates every 30 minutes. When an update is needed, warn players and restart the server to download it. Set to `"false"` to disable automatic checks and update restarts. |
| `AUTO_RESTART_HOURS` | `"24"` | Restart the server after this many hours. Use a positive whole number; set to `""` to disable. |

The image defaults `AUTO_UPDATE_MODS` to `false` and `AUTO_RESTART_HOURS` to empty. Both Compose settings are optional: remove `AUTO_UPDATE_MODS` to disable workshop checks, or remove `AUTO_RESTART_HOURS` to disable scheduled restarts. Setting them explicitly to `"false"` or `""` also works.

### Update

To update the PZ server itself, you need to rebuild and redeploy the project. `make build; make export`.  
Remove the old container image and start with the new one.

## More

For more detailed information, look at the `Makefile` and `compose.yml`.  
The entrypoint script for the container follows the concept similar to a guide posted on the [PZ forum](https://theindiestone.com/forums/topic/63563-4178-multiplayer-zomboid-dedicated-server-does-not-handle-sigterm/#comment-376957). This approach is considered not recommended as of october 2026. See caution note at start.

**All rights for components used in this project go to their respective owner.**  

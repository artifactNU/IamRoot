# Docker Cheat Sheet

Practical reference for container lifecycle, images, networking, storage, and troubleshooting.

---

## Table of Contents

- [Basics](#basics)
- [Images](#images)
- [Containers](#containers)
- [Logs and Exec](#logs-and-exec)
- [Copying Files](#copying-files)
- [Networks](#networks)
- [Volumes and Bind Mounts](#volumes-and-bind-mounts)
- [Resource Limits](#resource-limits)
- [Cleanup](#cleanup)
- [Docker Compose](#docker-compose)
- [Registry Operations](#registry-operations)
- [Debugging and Inspection](#debugging-and-inspection)
- [Security Notes](#security-notes)
- [Useful One-Liners](#useful-one-liners)

---

## Basics

- Show Docker version
  - `docker version`

- Show system information
  - `docker info`

- List Docker objects summary
  - `docker system df`

- Show active context
  - `docker context ls`

---

## Images

- Search images
  - `docker search nginx`

- Pull image
  - `docker pull nginx:stable`

- List local images
  - `docker images`
  - `docker image ls`

- Build image from current directory
  - `docker build -t myapp:1.0 .`

- Build without cache
  - `docker build --no-cache -t myapp:1.0 .`

- Tag image
  - `docker tag myapp:1.0 myrepo/myapp:1.0`

- Remove image
  - `docker rmi myapp:1.0`

- Remove dangling images
  - `docker image prune`

---

## Containers

- Run interactive shell and remove on exit
  - `docker run --rm -it ubuntu:24.04 bash`

- Run detached with a name and port mapping
  - `docker run -d --name web -p 8080:80 nginx:stable`

- List running containers
  - `docker ps`

- List all containers
  - `docker ps -a`

- Start / stop / restart
  - `docker start web`
  - `docker stop web`
  - `docker restart web`

- Kill immediately
  - `docker kill web`

- Remove container
  - `docker rm web`

- Force remove running container
  - `docker rm -f web`

- Rename container
  - `docker rename web web-prod`

---

## Logs and Exec

- Follow logs
  - `docker logs -f web`

- Tail last N lines
  - `docker logs --tail 100 web`

- Include timestamps
  - `docker logs -t web`

- Run command in running container
  - `docker exec web nginx -v`

- Open shell in running container
  - `docker exec -it web sh`
  - `docker exec -it web bash`

---

## Copying Files

- Copy host file into container
  - `docker cp ./config.conf web:/etc/nginx/conf.d/default.conf`

- Copy file from container to host
  - `docker cp web:/var/log/nginx/access.log ./access.log`

---

## Networks

- List networks
  - `docker network ls`

- Inspect network
  - `docker network inspect bridge`

- Create user-defined bridge
  - `docker network create app-net`

- Run container on a network
  - `docker run -d --name api --network app-net myapi:latest`

- Connect existing container to network
  - `docker network connect app-net web`

- Disconnect container from network
  - `docker network disconnect app-net web`

- Remove network
  - `docker network rm app-net`

---

## Volumes and Bind Mounts

- Create named volume
  - `docker volume create pgdata`

- List volumes
  - `docker volume ls`

- Inspect volume
  - `docker volume inspect pgdata`

- Use named volume
  - `docker run -d --name db -v pgdata:/var/lib/postgresql/data postgres:16`

- Use bind mount (absolute host path)
  - `docker run -d --name site -v /srv/site:/usr/share/nginx/html:ro nginx:stable`

- Preferred mount syntax
  - `docker run -d --name site --mount type=bind,src=/srv/site,dst=/usr/share/nginx/html,readonly nginx:stable`

- Remove unused volumes
  - `docker volume prune`

---

## Resource Limits

- Limit memory and CPU
  - `docker run -d --name worker --memory=512m --cpus=1.5 myworker:latest`

- Limit PIDs
  - `docker run -d --name worker --pids-limit=200 myworker:latest`

- Update running container limits
  - `docker update --memory=1g --cpus=2 worker`

---

## Cleanup

- Remove stopped containers
  - `docker container prune`

- Remove unused networks
  - `docker network prune`

- Remove unused images
  - `docker image prune -a`

- Remove unused volumes
  - `docker volume prune`

- Remove everything unused
  - `docker system prune -a --volumes`

---

## Docker Compose

- Validate compose file
  - `docker compose config`

- Start services in background
  - `docker compose up -d`

- Show service status
  - `docker compose ps`

- Follow logs
  - `docker compose logs -f`

- Rebuild and restart
  - `docker compose up -d --build`

- Stop and remove stack
  - `docker compose down`

- Stop and remove stack plus volumes
  - `docker compose down -v`

---

## Registry Operations

- Login to registry
  - `docker login`

- Login to a specific registry
  - `docker login registry.example.com`

- Push image
  - `docker push myrepo/myapp:1.0`

- Pull image from private registry
  - `docker pull registry.example.com/team/app:latest`

---

## Debugging and Inspection

- Show detailed container info
  - `docker inspect web`

- Show container process list
  - `docker top web`

- Show live resource usage
  - `docker stats`

- Show low-level events
  - `docker events`

- Show image history
  - `docker history myapp:1.0`

- Show exposed ports and mappings
  - `docker port web`

---

## Security Notes

- Prefer non-root images or set a user
  - In Dockerfile: `USER 10001:10001`

- Drop Linux capabilities when possible
  - `docker run --cap-drop ALL --cap-add NET_BIND_SERVICE ...`

- Make root filesystem read-only when possible
  - `docker run --read-only ...`

- Avoid mounting Docker socket into containers unless absolutely required.

- Pin image tags (or digests) in production to avoid drift.

---

## Useful One-Liners

- Remove all exited containers
  - `docker rm $(docker ps -aq -f status=exited)`

- Remove all dangling images
  - `docker rmi $(docker images -q -f dangling=true)`

- Show container names with image and status
  - `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'`

- Show image sizes
  - `docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'`

- Find containers publishing a host port
  - `docker ps --filter publish=8080`

- Run temporary debug container on another container network namespace
  - `docker run --rm -it --network container:web nicolaka/netshoot`

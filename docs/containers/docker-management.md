# Docker Management

## Overview

Docker provides a container runtime that packages applications with their dependencies into isolated units. From a sysadmin perspective, understanding Docker means understanding:

- How the daemon manages containers and resources
- Where things live on disk and how storage is managed
- How containers communicate with each other and the host
- What can go wrong and how to diagnose it

This guide covers **operational understanding**, not development or deployment workflows.

---

## Docker Architecture at the System Level

Docker consists of several key components:

**Docker Daemon** (`dockerd`)  
The background service that manages containers, images, and volumes. It runs as a privileged process (usually as root or in a special group) and is responsible for all container lifecycle operations.

**Docker CLI**  
The command-line tool (`docker`) that communicates with the daemon via a Unix socket (usually `/var/run/docker.sock`). The CLI is stateless; all state is managed by the daemon.

**containerd**  
The low-level runtime that Docker uses to actually start and manage container processes. containerd handles the linux namespace and cgroup setup.

**runc**  
The OCI (Open Container Initiative) runtime that containerd uses. This is the actual process that creates containers.

**Storage Driver**  
Manages how container filesystems are created and stored. Common drivers include overlay2 (preferred on modern systems), aufs, and devicemapper. The choice affects performance, space usage, and what operations are possible.

---

## Container Lifecycle

A container has several states:

**Created**  
The container exists but is not running. Resource allocation has occurred but the process has not started.

**Running**  
The container process is active. It has a PID (inside its namespace) and is consuming resources.

**Paused**  
The container process is frozen in place. It still exists but is not scheduled. This is rare and usually only used for debugging.

**Stopped**  
The container has exited. The container object still exists on disk but the process is not running.

**Removed**  
The container has been deleted from disk.

Understanding this distinction is critical because **a stopped container still takes up disk space** and can be restarted. This is different from traditional VMs and often surprises new operators.

---

## Storage

Docker storage has multiple layers, each with different implications.

### Image Layers

Images are built in layers. Each instruction in a Dockerfile creates a new layer. When you run a container, Docker creates a **read-only stack of these layers** and adds a **writable layer** on top.

This means:
- Multiple containers can share the same base image layers (space efficient)
- Changes made inside a container are written to the writable layer
- Stopping or removing a container does not delete the image layers

### Container Storage

When a container makes changes (writes files, modifies configs), these go into the **container layer**. This layer is ephemeral by default—if the container is removed, the layer is deleted.

Persistent data must use:
- **Volumes**: Named storage managed by Docker, stored in a dedicated directory on the host
- **Bind mounts**: Direct mounts of host directories or files into the container
- **tmpfs**: Temporary in-memory filesystems

### Disk Space Issues

Common disk problems:

**Dangling images**  
Images with no name or tag, often left behind after rebuilding. These can accumulate and consume significant space.

**Stopped containers**  
Each stopped container has a writable layer. An accumulation of stopped containers can exhaust disk space.

**Build cache**  
Docker keeps intermediate layers from builds. This can grow large over time.

**Volume retention**  
Volumes are not automatically cleaned up when containers are removed. Orphaned volumes persist on disk.

Diagnosis:
```bash
docker system df                    # Show space usage by type
docker images --dangling            # List untagged images
docker volume ls --dangling         # List orphaned volumes
docker ps -a --filter "status=exited" | wc -l  # Count stopped containers
```

Cleanup (carefully):
```bash
docker system prune                 # Remove unused resources
docker system prune --volumes       # Also remove orphaned volumes
docker image prune --all            # Remove all unused images
```

---

## Networking

Docker provides several networking modes, each with different implications for container-to-container and container-to-host communication.

### Bridge Network (Default)

By default, containers connect to a bridge network. Each container gets an IP on a virtual network (usually 172.17.x.x). The bridge acts as a gateway between containers and the host.

Important characteristics:
- Containers can reach the host via `host.docker.internal` (on Docker Desktop) or the bridge gateway IP
- Host cannot automatically reach containers by IP
- Containers on the same bridge can reach each other by container name (DNS resolution provided by Docker)
- Port mapping is required to expose services outside the host

### Host Network

With `--network host`, the container does not get its own network namespace. It shares the host's network directly.

Implications:
- Container services are directly accessible on the host's ports (no port mapping)
- Better performance (no NAT overhead)
- No port isolation between containers
- Dangerous—a compromised container can sniff all host network traffic

### Custom Bridges

You can create custom bridge networks. Containers on the same custom bridge automatically register in DNS, enabling service discovery by name.

### Networking Issues and Diagnosis

**Container cannot reach external network**
- Check if the container has internet access: `docker exec <container> curl -I https://8.8.8.8`
- Verify host firewall or DNS: `docker exec <container> cat /etc/resolv.conf`
- Check if container was started with `--network none`

**Containers cannot reach each other**
- Verify they are on the same network: `docker network inspect <network>`
- Check if a firewall rule is blocking communication
- Ensure you are using container names (or IPs from `docker inspect`) for reaching other containers

**Port mapping not working**
- Verify port is exposed: `docker port <container>`
- Check if host firewall is blocking the port: `sudo iptables -L -n | grep <port>`
- Ensure the container process is actually listening on that port: `docker exec <container> ss -tlnp`

---

## Resource Limits and Constraints

Containers can be constrained to use a maximum amount of resources, but without limits, a single container can consume all available CPU and memory.

### Memory Limits

```bash
docker run --memory 512m <image>    # Hard limit: 512 MB
docker run --memory-reservation 256m <image>  # Soft limit
```

**Hard limit** (`--memory`)  
If a container exceeds this, it is killed with an out-of-memory error. This is aggressive.

**Soft limit** (`--memory-reservation`)  
The daemon tries to enforce this when there is memory pressure, but does not kill the container if it exceeds it.

**Swap**  
By default, containers can also use swap. Disable with `--memory-swap` if swap should be included in the limit.

### CPU Limits

```bash
docker run --cpus 1.5 <image>       # Can use up to 1.5 CPUs
docker run --cpuset-cpus 0,1 <image>  # Pin to specific cores
```

**Soft limit** (`--cpus`)  
The container can use more if the host is not under load. This is more flexible than memory limits.

**CPU pinning** (`--cpuset-cpus`)  
Force a container to run on specific cores. Useful for pinning workloads.

### Disk I/O Limits

The `--blkio-*` flags allow limiting block device I/O. These are less commonly used but available if I/O is a constraint.

### Monitoring Resource Usage

```bash
docker stats                        # Real-time CPU, memory, network, disk usage
docker stats --no-stream <container>  # One-shot snapshot
docker inspect <container> | grep -A 10 '"HostConfig"'  # See configured limits
```

---

## Logs and Debugging

Docker stores container logs centrally. Understanding where they are and how to access them is critical for troubleshooting.

### Log Storage

By default, logs are written to:
```
/var/lib/docker/containers/<container-id>/<container-id>-json.log
```

This is JSON-formatted and contains stdout and stderr from the container.

Log storage can be configured:
- **json-file** (default): Stores in the path above
- **syslog**: Sends to syslog
- **journald**: Sends to systemd journal
- **splunk**, **awslogs**, **gelf**: Send to remote services

### Viewing Logs

```bash
docker logs <container>             # View all logs
docker logs -f <container>          # Follow logs in real-time
docker logs --tail 100 <container>  # Show last 100 lines
docker logs --since 10m <container>  # Logs from the last 10 minutes
```

### Debugging a Running Container

```bash
docker exec -it <container> /bin/bash  # Interactive shell
docker exec <container> ps aux       # See running processes
docker exec <container> netstat -tlnp  # See listening ports
docker exec <container> df -h        # Disk usage inside container
```

### Inspecting Container Metadata

```bash
docker inspect <container>          # All details (very verbose)
docker inspect --format '{{.State.Pid}}' <container>  # Get PID on host
docker inspect --format '{{.Mounts}}' <container>  # See mounted volumes
```

### Debugging Dead or Unresponsive Containers

If a container is stuck or not responding:

```bash
docker stats <container>            # Check if it's using CPU/memory
docker logs <container> | tail -50  # Check recent logs
docker ps -a --filter "id=<container>"  # Verify its state
```

If you need to forcefully stop it:
```bash
docker stop --time 10 <container>   # Give 10 seconds before kill
docker kill <container>             # Immediate termination
```

---

## Common Failure Modes

### Container Exits Immediately After Starting

The container runs its entrypoint or command and exits. This is not an error—it's expected if the command completes quickly.

If unexpected, check logs:
```bash
docker logs <container>
```

Common causes:
- Missing environment variables or configuration
- Entrypoint script has a bug or fails early
- Application does not have required permissions
- Port is already in use (if the app binds to a port)

### Out-of-Memory Kills

If a container suddenly disappears, check dmesg:
```bash
dmesg | grep -i "oom\|kill"
```

The Linux kernel kills processes when memory is exhausted. Solution:
- Increase `--memory` limit
- Reduce memory usage in the application
- Add memory to the host

### Disk Space Exhaustion

The container can exhaust the host's disk. The daemon and containers have no built-in mechanism to prevent this.

Solution:
- Monitor `/var/lib/docker` regularly
- Clean up stopped containers and dangling images
- Use volume limits if the underlying filesystem supports them

### Daemon Crashes or Becomes Unresponsive

If the Docker daemon stops responding:

```bash
sudo systemctl status docker         # Check daemon status
sudo journalctl -u docker --no-pager | tail -50  # Recent daemon logs
sudo systemctl restart docker        # Restart the daemon
```

Warning: Restarting the daemon stops all containers.

If the daemon is crashed and will not start, check for corruption:
```bash
sudo docker system prune --all       # Clean up cruft
sudo systemctl start docker
```

---

## Security Considerations

Containers share the host kernel, so a compromised container can potentially compromise the host or other containers.

### Privileged vs. Unprivileged Containers

By default, containers run with reduced privileges (inside user namespaces). However:

```bash
docker run --privileged <image>     # Dangerous: full host access
```

Avoid `--privileged` unless absolutely necessary. Instead, grant specific capabilities:

```bash
docker run --cap-add NET_ADMIN <image>  # Add just what you need
docker run --cap-drop ALL --cap-add NET_RAW <image>  # Drop all, add specific ones
```

### Volumes and Host Access

Volumes and bind mounts can expose sensitive host data to containers:

```bash
docker run -v /etc:/etc:ro <image>  # Container can read /etc (bad idea)
```

Be very careful about what you mount. Prefer:
- Volumes managed by Docker
- Read-only mounts when possible
- Specific subdirectories, not broad paths

### Image Security

Pull images from trusted registries. Unknown images could be compromised:

```bash
docker pull ubuntu:20.04            # Use specific versions, not 'latest'
docker inspect ubuntu:20.04 | grep -i digest  # Verify image hash
```

---

## Maintenance and Monitoring

### Regular Health Checks

Docker supports health checks defined in an image or at runtime:

```bash
docker run --health-cmd="curl http://localhost" \
           --health-interval=30s \
           --health-timeout=3s \
           --health-retries=3 <image>
```

Check health status:
```bash
docker inspect --format='{{.State.Health.Status}}' <container>
```

### Monitoring Daemon Health

The daemon itself should be monitored:

```bash
docker info                         # Check overall daemon status
docker version                      # Verify daemon is running
```

### Regular Cleanup

Dangling resources accumulate. Regular maintenance prevents disk exhaustion:

```bash
# Weekly or monthly
docker system prune --all --force
docker image prune --all --force
docker volume prune --force
```

### Updating and Patching

Keep Docker updated for security and stability:

```bash
sudo apt update && sudo apt upgrade docker.io  # Debian/Ubuntu
docker --version                              # Verify version
```

Images also need updating. Rebuilt images incorporate the latest base layer patches.

---

## When to Use Containers

Containers are excellent for:
- Packaging consistent application environments
- Scaling stateless services
- Isolating workloads on shared hardware

Containers are **not ideal** for:
- Long-running services where you need to debug or introspect (VMs may be simpler)
- Workloads requiring direct hardware access
- Systems where you need strong isolation boundaries (VMs are better)
- Persistent stateful databases (possible but operationally complex)

Understanding the trade-offs helps you make better decisions about what to containerize.

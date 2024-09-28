# warp-docker

[![Docker Pulls](https://img.shields.io/docker/pulls/caomingjun/warp)](https://hub.docker.com/r/caomingjun/warp)
![WARP version in latest image](https://img.shields.io/endpoint?url=https%3A%2F%2Fapi.caomingjun.com%2Fdockerhub-label%3Frepo%3Dcaomingjun%2Fwarp%26label%3DWARP_VERSION%26display%3DWARP%2520in%2520image
)
![GOST version in latest image](https://img.shields.io/endpoint?url=https%3A%2F%2Fapi.caomingjun.com%2Fdockerhub-label%3Frepo%3Dcaomingjun%2Fwarp%26label%3DGOST_VERSION%26display%3DGOST%2520in%2520image
)

Run official [Cloudflare WARP](https://1.1.1.1/) client in Docker.

> [!NOTE]
> Cannot guarantee that the [GOST](https://github.com/ginuerzh/gost) and WARP client contained in the image are the latest versions. If necessary, please [build your own image](#build).

## Usage

### Start the container

To run the WARP client in Docker, just write the following content to `docker-compose.yml` and run `docker-compose up -d`.

```yaml
version: '3'

services:
  warp:
	image: caomingjun/warp
	container_name: warp
	restart: always
	ports:
	  - '1080:1080'
	environment:
	  - WARP_SLEEP=2
	  # - GOST_ARGS=-L=ss+ohttp://aes-256-gcm:password@:8338 # sample to expose shadowsocks protocol service with obfs
	  # - WARP_LICENSE_KEY= # optional
	  # - WARP_PROXY_PORT=40000 # set proxy port will change to proxy only mode
	cap_add:
	  - NET_ADMIN
	sysctls:
	  - net.ipv6.conf.all.disable_ipv6=0
	  - net.ipv4.conf.all.src_valid_mark=1
	volumes:
	  - ./data:/var/lib/cloudflare-warp
```

Try it out to see if it works:

```bash
curl --socks5-hostname 127.0.0.1:1080 https://cloudflare.com/cdn-cgi/trace
```

If the output contains `warp=on` or `warp=plus`, the container is working properly. If the output contains `warp=off`, it means that the container failed to connect to the WARP service.

### Configuration

You can configure the container through the following environment variables:

- `WARP_SLEEP`: The time to wait for the WARP daemon to start, in seconds. The default is 2 seconds. If the time is too short, it may cause the WARP daemon to not start before using the proxy, resulting in the proxy not working properly. If the time is too long, it may cause the container to take too long to start. If your server has poor performance, you can increase this value appropriately.

- `WARP_LICENSE_KEY`: The license key of the WARP client, which is optional. If you have subscribed to WARP+ service, you can fill in the key in this environment variable. If you have not subscribed to WARP+ service, you can ignore this environment variable.

- `WARP_DNS_MODE`: The [dns famillies modes](https://developers.cloudflare.com/warp-client/get-started/linux/#using-1111-for-families) for the 1.1.1.1 support. default is `off`.

- `WARP_PROXY_PORT`: The port of the warp proxy, which is optional. If not set, the warp will be the default mode. Othewise, it should be a valid port number and warp will run in [proxy only mode](https://blog.cloudflare.com/announcing-warp-for-linux-and-proxy-mode). WARP will bind a socks5 proxy on this port of localhost interface. And the socks5 could be exposed to host by gost, which default is 1080.

Data persistence: Use the host volume `./data` to persist the data of the WARP client. You can change the location of this directory or use other types of volumes. If you modify the `WARP_LICENSE_KEY`, please delete the `./data` directory so that the client can detect and register again.

### Change proxy type

The container uses [GOST](https://github.com/ginuerzh/gost) to provide proxy, where the environment variable `GOST_ARGS` is used to pass parameters to GOST. The default is `-L :1080`, that is, to listen on port 1080 in the container at the same time through HTTP and SOCKS5 protocols. If you want to have UDP support or use advanced features provided by other protocols, you can modify this parameter. For more information, refer to [GOST documentation](https://v2.gost.run/en/).

If you modify the port number, you may also need to modify the port mapping in the `docker-compose.yml`.

### Health check

The health check of the container will verify if the WARP client inside the container is working properly. If the check fails, the container will automatically restart. Specifically, 10 seconds after starting, a check will be performed every 15 seconds. If the inspection fails for 3 consecutive times, the container will be marked as unhealthy and trigger an automatic restart.

If `BETA_FIX_HOST_CONNECTIVITY=1` is passed, host connectivity check will be added to the health check. If the check fails, the container will automatically fix it. This may prevent you from accessing certain intranet services of your organization, as the docker network subnet may conflict with the addresses of these services. This is a beta feature and may not work in all cases. If you encounter any issues, please report them.

If you don't want the container to restart automatically, you can remove `restart: always` from the `docker-compose.yml`. You can also modify the parameters of the health check through the `docker-compose.yml`.

### Setting up as WARP connector

If you want to setup [WARP Connector](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/warp-connector)

> [!NOTE]
> If you have already started the container, stop it and delete the data directory.

1. Create mdm.xml as explained in Cloudflare WARP Connector [step 4](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/warp-connector/#4-install-a-warp-connector)
2. Mount the mdm.xml to path `/var/lib/cloudflare-warp/mdm.xml`
3. Start the container

<details>

```yaml
services:
  warp:
	image: caomingjun/warp
	container_name: warp
	restart: always
	ports:
	  - '1080:1080'
	environment:
	  - WARP_SLEEP=2
	  # - GOST_ARGS=-L=ss+ohttp://aes-256-gcm:password@:8338 # sample to expose shadowsocks protocol service with obfs
	  # - WARP_LICENSE_KEY= # optional
	cap_add:
	  - NET_ADMIN
	sysctls:
	  - net.ipv6.conf.all.disable_ipv6=0
	  - net.ipv4.conf.all.src_valid_mark=1
	  - net.ipv4.ip_forward=1
	volumes:
	  - ./data:/var/lib/cloudflare-warp
	  - ./config/warp/mdm.xml:/var/lib/cloudflare-warp/mdm.xml
```

<summary><i>Sample Docker Compose File</i></summary  >
</details>

### Use with Cloudflare Zero Trust

If you want to use the WARP client with Cloudflare Zero Trust, just start the container without specifying license key, use `docker exec -it warp bash` to get into the container and follow these steps:

1. `warp-cli registration delete` to delete current registration
2. `warp-cli teams-enroll <your-team-name>` to enroll the device
3. Open the link in the output in a browser and follow the instructions to complete the registration
4. On the success page, right-click and select **View Page Source**.
5. Find the HTML metadata tag that contains the token. For example, `<meta http-equiv="refresh" content"=0;url=com.cloudflare.warp://acmecorp.cloudflareaccess.com/auth?token=yeooilknmasdlfnlnsadfojDSFJndf_kjnasdf..." />`
6. Copy the URL field: `com.cloudflare.warp://<your-team-name>.cloudflareaccess.com/auth?token=<your-token>`
7. In the terminal, run the following command using the URL obtained in the previous step: `warp-cli registration token com.cloudflare.warp://<your-team-name>.cloudflareaccess.com/auth?token=<your-token>`. If you get an API error, then the token has expired. Generate a new one by refreshing the web page and quickly grab the new token from the page source.
8. `warp-cli connect` to reconnect using new registration.
9. Wait untill `warp-cli status` shows `Connected`.
10. Try `curl --socks5-hostname 127.0.0.1:1080 https://cloudflare.com/cdn-cgi/trace` to verify the connection.

This is only needed for the first time. After the device is enrolled, the registration information will be stored in the `./data` directory, if you don't delete them, the container will automatically use the registration information to connect to the WARP service after restart or recreate.

### Use other versions

The tag of docker image is in the format of `{WARP_VERSION}-{GOST_VERSION}`, for example, `2023.10.120-2.11.5` means that the WARP client version is `2023.10.120` and the GOST version is `2.11.5`. If you want to use other versions, you can specify the tag in the `docker-compose.yml`.

You can also use the `latest` tag to use the latest version of the image.

> [!NOTE]
> You can access the image built by a certain commit by using the tag `{WARP_VERSION}-{GOST_VERSION}-{COMMIT_SHA}`. Not all commits have images built.

> [!NOTE]
> Not all version combinations are available. Do check [the list of tags in Docker Hub](https://hub.docker.com/r/caomingjun/warp/tags) before you use one. If the version you want is not available, you can [build your own image](#build).

## Build

You can use Github Actions to build the image yourself.

1. Fork this repository.
2. Create necessary variables and secrets in the repository settings:
   1. variable `REGISTRY`: for example, `docker.io` (Docker Hub)
   2. variable `IMAGE_NAME`: for example, `caomingjun/warp`
   3. variable `DOCKER_USERNAME`: for example, `caomingjun`
   4. secret `DOCKER_PASSWORD`: generate a token in Docker Hub and fill in the token
3. Manually trigger the workflow `Build and push image` in the Actions tab.

This will build the image with the latest version of WARP client and GOST and push it to the specified registry. You can also specify the version of GOST by giving input to the workflow. Building image with custom WARP client version is not supported yet.

If you want to build the image locally, you can use [`.github/workflows/build-publish.yml`](.github/workflows/build-publish.yml) as a reference.

## Common problems

### Proxying UDP or even ICMP traffic

The default `GOST_ARGS` is `-L :1080`, which provides HTTP and SOCKS5 proxy. If you want to proxy UDP or even ICMP traffic, you need to change the `GOST_ARGS`. Read the [GOST documentation](https://v2.gost.run/en/) for more information.

### How to connect from another container

You may want to use the proxy from another container and find that you cannot connect to `127.0.0.1:1080` in that container. This is because the `docker-compose.yml` only maps the port to the host, not to other containers. To solve this problem, you can use the service name as the hostname, for example, `warp:1080`. You also need to put the two containers in the same docker network.

### Container runs well but cannot connect from host

This issue often arises when using Zero Trust. You may find that you can run `curl --socks5-hostname 127.0.0.1:1080 https://cloudflare.com/cdn-cgi/trace` inside the container, but cannot run this command outside the container (from host or another container). This is because  Cloudflare WARP client is grabbing the traffic. There are three solutions.

If you have permission to edit the [split tunnel settings](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/configure-warp/route-traffic/split-tunnels/), you can add the subnet of your docker network to the split tunnel.

If you don't have the permission, use `docker exec warp-test warp-cli --accept-tos tunnel dump` to list your current excluded subnets, and carefully select one of them to set as the docker network subnet. The subnet you choose should be within the [private address range](https://en.wikipedia.org/wiki/Private_network#Private_IPv4_addresses); using a public address will prevent you from accessing certain services properly. This solution can be quite brittle and manual as you may need to change the subnet when your organization changes the excluded subnets, but it won't cause any other problems.

The third solution is to pass environment variable `BETA_FIX_HOST_CONNECTIVITY=1` to container, the container will add checks for host connectivity into healthchecks and automatically fix it if necessary. **This may prevent you from accessing certain intranet services of your organization**, as the docker network subnet may conflict with the addresses of these services. This is a beta feature and may not work in all cases. If you encounter any issues, please report them.

## Further reading

Read in my [blog post](https://blog.caomingjun.com/run-cloudflare-warp-in-docker/en/#How-it-works).

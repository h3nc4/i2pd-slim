# Slim i2pd Container

Docker container for [i2pd](https://github.com/PurpleI2P/i2pd) (**<20MB**), the C++ I2P router, built as one statically linked binary with no OS layer.

**Why use this?** The upstream image is a full Alpine with a shell, a package manager and the boost libraries beside the router. This one runs i2pd in a `FROM scratch` environment holding the binary, its reseed certificates and a default config. The source release is checked against the signed `SHA512SUMS` before it builds.

## Running

Minimal steps to run the container as an I2P HTTP proxy:

```bash
# In case you want to build the image yourself instead of pulling it from Docker Hub:
# docker build -t h3nc4/i2pd-slim .

docker run -d --name i2pd \
  -p 127.0.0.1:4444:4444 -p 127.0.0.1:7070:7070 \
  -v i2pd-data:/var/lib/i2pd \
  h3nc4/i2pd-slim

curl -x http://127.0.0.1:4444 http://7tbay5p4kzeekxvyvbf6v7eauazemsnnl2aoyqhg5jzpr5eke7tq.b32.i2p/   # stats.i2p
```

A new router needs a few minutes to integrate before `.i2p` names answer. The console is at http://localhost:7070, and it refuses any Host header other than `localhost`, so open it by that name rather than by `127.0.0.1`. That check is what keeps a DNS rebinding page from driving the router.

## Configuration

The built-in `/etc/i2pd/i2pd.conf` binds the console on 7070, the HTTP proxy on 4444 and the SOCKS proxy on 4447 to every interface inside the container. A port published with `-p` then connects to them. SAM, BOB and I2CP are off. Publish ports on `127.0.0.1` only, since the proxies answer anyone who reaches them.

Tunnels go in `/etc/i2pd/tunnels.d/`, where i2pd reads every `.conf` file. Mount one or more there to serve a site without replacing the default config:

```bash
docker run -d --name i2pd \
  -v ./mysite.conf:/etc/i2pd/tunnels.d/mysite.conf:ro \
  -v i2pd-data:/var/lib/i2pd \
  h3nc4/i2pd-slim
```

To replace the configuration wholesale instead, mount over `/etc/i2pd/i2pd.conf`, or pass `--conf=` with a path of your own after the image name. Passing any argument replaces the default `--datadir=/var/lib/i2pd --conf=/etc/i2pd/i2pd.conf`, so repeat whichever of the two you still want.

`/var/lib/i2pd` is the data directory, owned by 65534 with mode 0700, which a new named volume takes from the image on first mount. It holds the router identity and every tunnel key. Back it up, since a lost key is a lost address. `tunnels.d` is root-owned and read-only to i2pd.

The image has no shell, so a Docker healthcheck has nothing to run. Probe the console or the proxy from outside the container instead.

## License

i2pd Slim is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

i2pd Slim is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with i2pd Slim. If not, see <https://www.gnu.org/licenses/>.

i2pd itself is BSD-3-Clause, under the copyright of the PurpleI2P project.

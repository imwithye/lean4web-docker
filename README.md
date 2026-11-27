# lean4web-docker

Docker image for [lean4web](https://github.com/leanprover-community/lean4web),
the Lean 4 web editor.

The image is **always built from an upstream release tag** (e.g. `v0.2.2`), never from `main`.
A GitHub Actions workflow checks for a new upstream release every day and
publishes it to GHCR.

## Usage

```sh
docker run -d -p 8080:8080 ghcr.io/imwithye/lean4web:latest
# or pin a release
docker run -d -p 8080:8080 ghcr.io/imwithye/lean4web:v0.2.2
```

Open http://localhost:8080.

### Image tags

| tag               | meaning                                                      |
| ----------------- | ------------------------------------------------------------ |
| `latest`          | latest upstream release                                      |
| `vX.Y.Z`          | that upstream release (most recent build)                    |
| `vX.Y.Z-YYYYMMDD` | that release, built on that date (Mathlib snapshot is fixed) |

> Note: the upstream `MathlibDemo` project always pulls the **latest Mathlib**
> at build time, so the Mathlib version depends on the build date. Use the
> dated tag if you need a reproducible Mathlib.

## Build locally

```sh
docker build --build-arg LEAN4WEB_VERSION=v0.2.2 -t lean4web:v0.2.2 .

# Smaller image without Mathlib (only the "Stable Lean" project)
docker build --build-arg LEAN4WEB_VERSION=v0.2.2 --build-arg WITH_MATHLIB=false -t lean4web:v0.2.2-nomathlib .
```

## Configuration

| env                             | default    | description                                          |
| ------------------------------- | ---------- | ---------------------------------------------------- |
| `PORT`                          | `8080`     | HTTP port                                            |
| `NO_BWRAP`                      | `true`     | Bubblewrap is disabled; the container is the sandbox |
| `VITE_COLLAB`                   | (upstream) | Collaboration feature                                |
| `SSL_CRT_FILE` / `SSL_KEY_FILE` | —          | Serve HTTPS directly (mount the files)               |

Since Lean runs without bubblewrap inside the container, consider running it
with resource limits, e.g. `--memory 8g --cpus 4 --pids-limit 512`, and
behind a reverse proxy.

## Publishing a specific release

Actions → *Build & publish image* → *Run workflow*, enter a tag such as `v0.2.1`.
Only tags that are real upstream **releases** are accepted.

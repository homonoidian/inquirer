## Inquirer

Inquirer is an integral part of the [Ven programming language](https://github.com/homonoidian/ven).

- At its core, Inquirer is a daemon that recursively watches
  for changes in the *origin directory* (your home directory
  by default), and specifically changes in `.ven` files and
  in the directory structure (in order to establish/remove
  watchers).
- The other part of Inquirer is the Inquirer server. It makes
  it easy for the outer world to interact with the daemon. It
  has direct access to, as well as full control of the daemon.

### Building

#### With Docker

1. Build the image with `docker build -t inquirer .`.
2. Build Inquirer with `docker run --rm -v $(pwd)/bin:/build/bin inquirer`.

#### Without Docker

1. Install the dependencies with `shards install`.
2. Build with `shards build --release --no-debug`.

<div align="center">
  <img src="https://i.imgur.com/pOfRSr2.png" alt="Logo" width="150">
</div>

## Inquirer

Inquirer is an integral part of the [Ven programming language](https://github.com/homonoidian/ven).
It provides an abstract interface between the hard drive and Ven programs *on it*.
As it is pretty complex on its own, I decided to make it a separate project.

Inquirer consists of:

- The *inquirer daemon*, which watches for changes in Ven files and updates the stuff
  that has to be updated after those changes.
- The *inquirer server*, which provides REST-like API interface to the daemon, making
  it easy for IDEs and for Ven itself to know where Ven ecosystem is on the disk.

### Building

#### With Docker

1. Build the image with `docker build -t inquirer .`.
2. Build Inquirer with `docker run --rm -v $(pwd)/bin:/build/bin inquirer`.

#### Without Docker

1. Install the dependencies with `shards install`.
2. Build with `shards build --release --no-debug`.

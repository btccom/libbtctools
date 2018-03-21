A core library of BTCTools
==================

`libbtctools` is a library of `BTCTools`, it provides the basic ability of scanning, configuration and rebooting some miners.

It can build on Windows, Linux and macOS, as dynamic or static library.

# Dependency
There are 4 dependencies:
* Boost 1.59 or later (1.65 or later is validated and recommended)
* OpenSSL (both 1.0 or 1.1 are OK)
* Lua-5.1 or LuaJIT-2.0 (LuaJIT is recommended but incompatibly with macOS)
* Crypto++ (5.6.5 or later)
And `libpthread` is required on Linux and macOS.

# Build on Linux
Example on Ubuntu 16.04 x64:
```bash
# build boost 1.65
wget https://dl.bintray.com/boostorg/release/1.65.1/source/boost_1_65_1.tar.gz
tar zxf boost_1_65_1.tar.gz
cd boost_1_65_1
./bootstrap.sh
./b2
./b2 install

# install other dependencies
apt update
apt install libssl-dev libluajit-5.1-dev libcrypto++-dev

# clone and build
git clone https://github.com/btccom/libbtctools.git
cd libbtctools
mkdir build
cd build

# build as static library
cmake -DBTCTOOLS__LIB_TYPE=STATIC ..
make

# or build as dynamic library
cmake -DBTCTOOLS__LIB_TYPE=STATIC ..
make

# running demos
./ipGeneratorDemo
./scanMinerDemo
./configMinerDemo
```

# Build on Windows
TODO: it's not easy. I will finish the document next days.

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
Example on Ubuntu 18.04 x64:
```bash
# install boost via apt
apt install libboost-dev

# or build boost 1.65 if you want (optional)
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
cmake -DBTCTOOLS__LIB_TYPE=SHARED ..
make

# create a link for lua script
ln -s ../src/lua .

# running demos
./ipGeneratorDemo
./scanMinerDemo
./configMinerDemo
./rebootMinerDemo
```

# Build on macOS
It seems like build on Linux. Search and install dependencies with `brew` first.

Tips: install `lua-5.1` instead of `luajit-2.0`. The demo will segmentation fault with `luajit-2.0` and I don't know the reason.

The command will be:
```bash
brew install boost openssl lua@5.1 cryptopp

# static library
cmake -DBTCTOOLS__LIB_TYPE=STATIC -DBTCTOOLS__LUA_TYPE=NORMAL ..

# or dynamic library
cmake -DBTCTOOLS__LIB_TYPE=SHARED -DBTCTOOLS__LUA_TYPE=NORMAL ..

# build
make
```

# Build on Windows

### install vcpkg

```
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```

> PS G:\work\vcpkg> .\vcpkg integrate install
> Applied user-wide integration for this vcpkg root.
> 
> All MSBuild C++ projects can now #include any installed libraries.
> Linking will be handled automatically.
> Installing new libraries will make them instantly available.
> 
> CMake projects should use: "-DCMAKE_TOOLCHAIN_FILE=G:/work/vcpkg/scripts/buildsystems/vcpkg.cmake"

### install packages via vcpkg

```
.\vcpkg install boost:x86-windows-static openssl:x86-windows-static cryptopp:x86-windows-static luajit:x86-windows-static
```

### cmake & build

```
cmake -DCMAKE_BUILD_TYPE=Release -A win32 -DCMAKE_TOOLCHAIN_FILE=G:/work/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x86-windows-static -DBTCTOOLS__STATIC_LINKING_VC_LIB=ON -DBTCTOOLS__LIB_TYPE=STATIC ..
start libbtctools.sln
```

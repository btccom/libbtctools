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
# build tools
apt-get install -y build-essential autotools-dev libtool autoconf automake pkg-config cmake gcc g++

# install boost via apt
apt install libboost-all-dev

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
cmake -DCMAKE_INSTALL_PREFIX=/opt/btctools -DBTCTOOLS__LIB_TYPE=STATIC ..
make
make install

# or build as dynamic library
cmake -DCMAKE_INSTALL_PREFIX=/opt/btctools -DBTCTOOLS__LIB_TYPE=SHARED ..
make
make install

# running demos
cd /opt/btctools/bin/btctools
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
brew install cmake boost openssl lua@5.1 cryptopp

# static library
cmake -DCMAKE_INSTALL_PREFIX=/opt/btctools -DBTCTOOLS__LIB_TYPE=STATIC -DBTCTOOLS__LUA_TYPE=NORMAL ..

# or dynamic library
cmake -DCMAKE_INSTALL_PREFIX=/opt/btctools -DBTCTOOLS__LIB_TYPE=SHARED -DBTCTOOLS__LUA_TYPE=NORMAL ..

# build & install
make
make install
```

# Build on Windows

### Install Visual Studio

Please install the C/C++ Development Kit with Visual Studio.

See https://visualstudio.microsoft.com/ for more details.

### Install CMake

See https://cmake.org/download/ for more details.

### Install vcpkg

See https://github.com/Microsoft/vcpkg/ for more details.


Quick Steps:
```
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```

Example output for `.\vcpkg integrate install`:

> PS G:\work\vcpkg> .\vcpkg integrate install
> Applied user-wide integration for this vcpkg root.
> 
> All MSBuild C++ projects can now #include any installed libraries.
> Linking will be handled automatically.
> Installing new libraries will make them instantly available.
> 
> CMake projects should use: "-DCMAKE_TOOLCHAIN_FILE=G:/work/vcpkg/scripts/buildsystems/vcpkg.cmake"

### install packages via vcpkg


#### 32bit
```
.\vcpkg install boost:x86-windows-static openssl:x86-windows-static cryptopp:x86-windows-static luajit:x86-windows-static
```

#### 64bit
```
.\vcpkg install boost:x64-windows-static openssl:x64-windows-static cryptopp:x64-windows-static luajit:x64-windows-static
```

### cmake & build

#### 32bit
```
md build.32
cd build.32
cmake -DCMAKE_BUILD_TYPE=Release -A win32 -DCMAKE_TOOLCHAIN_FILE=G:/work/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x86-windows-static -DBTCTOOLS__STATIC_LINKING_VC_LIB=ON -DBTCTOOLS__LIB_TYPE=STATIC -DCMAKE_INSTALL_PREFIX=G:\work\lib32\btctools ..
start libbtctools.sln
```

#### 64bit
```
md build.64
cd build.64
cmake -DCMAKE_BUILD_TYPE=Release -A x64 -DCMAKE_TOOLCHAIN_FILE=G:/work/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-static -DBTCTOOLS__STATIC_LINKING_VC_LIB=ON -DBTCTOOLS__LIB_TYPE=STATIC -DCMAKE_INSTALL_PREFIX=G:\work\lib64\btctools ..
start libbtctools.sln
```

Replace `G:/work/vcpkg/scripts/buildsystems/vcpkg.cmake` to your `vcpkg.cmake` path.

Replace `G:\work\lib[32|64]\btctools` to the install path what you want.

Select **Release** instead of the default **Debug** in the build type drop-down box, then build the **INSTALL** project to install.

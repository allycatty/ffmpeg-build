#!/bin/sh

CWD=`pwd`

# create and change to working directory
mkdir /tmp/ffmpeg && cd /tmp/ffmpeg

# update and install needed packages
apt update
apt -y --force-yes install autoconf automake libtool patch make \
  cmake bzip2 unzip wget git mercurial cmake build-essential pkg-config \
  texi2html software-properties-common libfreetype6-dev libgpac-dev \
  libsdl1.2-dev libtheora-dev libva-dev libvdpau-dev libvorbis-dev \
  libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev zlib1g-dev libfribidi-dev \
  libfontconfig1-dev nvidia-cuda-toolkit

# install cuda-repo-ubuntu1804
apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
apt install ./cuda-repo-ubuntu1804_10.0.130-1_amd64.deb

# set up nv-codec-headers
git clone --depth=1 https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
cd nv-codec-headers
make
make install PREFIX="/tmp/ffmpeg/dist"
cd ..

# compile nasm
wget "http://www.nasm.us/pub/nasm/releasebuilds/2.14rc15/nasm-2.14rc15.tar.gz"
tar xf nasm-2.14rc15.tar.gz
cd nasm-2.14rc15
./configure --prefix="/tmp/ffmpeg/dist" --bindir="/tmp/ffmpeg/dist/bin"
make install distclean
cd ..

# compile yasm
wget "http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz"
tar xf yasm-1.3.0.tar.gz
cd yasm-1.3.0
./configure --prefix="/tmp/ffmpeg/dist" --bindir="/tmp/ffmpeg/dist/bin"
make install distclean
cd ..

export PATH="$PATH:/tmp/ffmpeg/dist/bin"

# compile libx264
wget https://download.videolan.org/pub/x264/snapshots/x264-snapshot-20191216-2245.tar.bz2
tar xf x264-snapshot-20191216-2245.tar.bz2
cd x264-snapshot-20191216-2245
./configure --prefix="/tmp/ffmpeg/dist" --bindir="/tmp/ffmpeg/dist/bin" --enable-static --enable-pic
make install distclean
cd ..

# compile libx265
hg clone https://bitbucket.org/multicoreware/x265
cd x265/build/linux
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/tmp/ffmpeg/dist" -DENABLE_SHARED:bool=off ../../source
make install
sed -i -e 's,^ *x265_param\* zoneParam,struct x265_param* zoneParam,' /tmp/ffmpeg/dist/include/x265.h
cd ../../..

# compile libaom
git clone --depth=1 https://aomedia.googlesource.com/aom
cd aom
mkdir output && cd output
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/tmp/ffmpeg/dist" -DBUILD_SHARED_LIBS=off -DENABLE_NASM=on ..
make install
cd ../..

# compile libfdkcc
git clone --depth=1 https://github.com/mstorsjo/fdk-aac
cd fdk-aac
autoreconf -fiv
./configure --prefix="/tmp/ffmpeg/dist" --disable-shared
make install distclean
cd ..

# compile libmp3lame
wget "http://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"
tar xf lame-3.100.tar.gz
cd lame-3.100
./configure --prefix="/tmp/ffmpeg/dist" --enable-nasm --disable-shared
make install distclean
cd ..

# compile libopus
wget "http://downloads.xiph.org/releases/opus/opus-1.2.1.tar.gz"
tar xf opus-1.2.1.tar.gz
cd opus-1.2.1
./configure --prefix="/tmp/ffmpeg/dist" --disable-shared
make install distclean
cd ..

# compile libvpx
git clone --depth=1 https://github.com/webmproject/libvpx/
cd libvpx
./configure --prefix="/tmp/ffmpeg/dist" \
  --disable-examples --enable-runtime-cpu-detect --enable-vp9 --enable-vp8 \
  --enable-postproc --enable-vp9-postproc --enable-multi-res-encoding \
  --enable-webm-io --enable-better-hw-compatibility \
  --enable-vp9-highbitdepth --enable-onthefly-bitpacking \
  --enable-realtime-only --as=nasm --disable-docs
make
make install
cd ..

# compile libass
wget "https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.xz"
tar xf libass-0.14.0.tar.xz
cd libass-0.14.0
autoreconf -fiv
./configure --prefix="/tmp/ffmpeg/dist" --disable-shared
make install distclean
cd ..

# compile ffmpeg
git clone --depth=1 https://github.com/FFmpeg/FFmpeg -b master
cd FFmpeg
PKG_CONFIG_PATH="/tmp/ffmpeg/dist/lib/pkgconfig:/tmp/ffmpeg/dist/lib64/pkgconfig" \
./configure \
  --pkg-config-flags="--static" \
  --prefix="/usr/local" \
  --extra-cflags="-I /tmp/ffmpeg/dist/include" \
  --extra-ldflags="-L /tmp/ffmpeg/dist/lib" \
  --extra-libs="-lpthread" \
  --enable-cuda \
  --enable-cuda-nvcc \
  --enable-cuvid \
  --enable-libnpp \
  --enable-gpl \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-vaapi \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-nonfree \
  --enable-libaom \
  --enable-nvenc
make
make install

# cleanup
cd $CWD
rm -rf /tmp/ffmpeg


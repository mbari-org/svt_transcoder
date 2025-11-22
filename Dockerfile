FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
            ca-certificates \
            build-essential \
            git cmake nasm \
            pkg-config openssl libssl-dev \
            libpng-dev libfreetype6-dev wget unzip \
            autoconf automake libtool libnuma-dev \
            cmake-curses-gui && \
    rm -fr /var/lib/apt/lists/*

WORKDIR /work

# Clone FFmpeg
RUN git clone --depth 1 --branch n7.1 https://github.com/FFmpeg/FFmpeg ffmpeg

# Build x264 (H.264 encoder)
RUN git clone https://code.videolan.org/videolan/x264.git
WORKDIR /work/x264
RUN ./configure --prefix=/opt/cvision --enable-shared
RUN make -j8 && make install

# Build x265 (H.265 encoder)
WORKDIR /work
RUN git clone https://bitbucket.org/multicoreware/x265_git.git
WORKDIR /work/x265_git/build/linux
RUN cmake -G "Unix Makefiles" ../../source -DCMAKE_INSTALL_PREFIX=/opt/cvision
RUN make -j8 && make install

COPY files/cvision.conf /etc/ld.so.conf.d
RUN ldconfig

# Build FFmpeg with only x264 and x265 support
WORKDIR /work/ffmpeg
ENV PKG_CONFIG_PATH=/opt/cvision/lib/pkgconfig
RUN ./configure --prefix=/opt/cvision \
    --enable-libfreetype \
    --enable-libx264 \
    --enable-libx265 \
    --enable-openssl \
    --enable-nonfree \
    --enable-gpl
RUN make -j8 && make install

# Remove static
RUN rm -f /opt/cvision/lib/*.a


WORKDIR /bento4
RUN wget http://zebulon.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-632.x86_64-unknown-linux.zip
COPY files/md5sum_checks.txt /tmp/checks.txt
RUN md5sum --check /tmp/checks.txt
RUN unzip Bento4-SDK-1-6-0-632.x86_64-unknown-linux.zip

FROM ubuntu:24.04 AS encoder
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
            ca-certificates libx265-199 libx264-164 libpng16-16 libfreetype6 libssl3 && \
    rm -fr /var/lib/apt/lists/*
COPY --from=builder /opt/cvision /opt/cvision
COPY files/cvision.conf /etc/ld.so.conf.d
COPY files/test.sh /test.sh
RUN chmod +x /test.sh

# Install Bento4
COPY --from=builder /bento4/Bento4-SDK-1-6-0-632.x86_64-unknown-linux/bin/mp4dump /opt/cvision/bin
COPY --from=builder /bento4/Bento4-SDK-1-6-0-632.x86_64-unknown-linux/bin/mp4info /opt/cvision/bin

ENV PATH="/opt/cvision/bin:${PATH}"
RUN ldconfig /



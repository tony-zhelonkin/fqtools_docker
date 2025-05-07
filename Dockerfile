###############################################################################
# FQ Toolbox: samtools 1.21 • bcftools 1.21 • htslib 1.21 • fqtools (patched)
###############################################################################
FROM ubuntu:22.04
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL maintainer="Anton Zhelonkin <anton.bioinf.md@gmail.com>"

# ─── 1. user / locale / tz ────────────────────────────────────────────────────
ARG USER_ID=1001 GROUP_ID=1001
ARG USER=mogilenko_lab GROUP=mogilenko_lab
ENV DEBIAN_FRONTEND=noninteractive TZ=America/Chicago \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ >/etc/timezone && \
    groupadd -g $GROUP_ID $GROUP && useradd -m -u $USER_ID -g $GROUP_ID $USER

# ─── 2. build-time deps ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
       build-essential automake autoconf libtool pkg-config \
       zlib1g-dev libbz2-dev liblzma-dev libcurl4-openssl-dev \
       libncurses5-dev libncursesw5-dev \
       wget git ca-certificates locales tzdata && \
    locale-gen en_US.UTF-8

# ─── 3. HTS stack 1.21 (sam/bam headers still in project root) ───────────────
WORKDIR /build
ARG HTS_VER=1.21
RUN wget -q \
      https://github.com/samtools/htslib/releases/download/${HTS_VER}/htslib-${HTS_VER}.tar.bz2 \
      https://github.com/samtools/bcftools/releases/download/${HTS_VER}/bcftools-${HTS_VER}.tar.bz2 \
      https://github.com/samtools/samtools/releases/download/${HTS_VER}/samtools-${HTS_VER}.tar.bz2 && \
    tar -xf htslib-${HTS_VER}.tar.bz2 && cd htslib-${HTS_VER} && \
    ./configure && make -j"$(nproc)" && make install && cd .. && \
    tar -xf bcftools-${HTS_VER}.tar.bz2 && cd bcftools-${HTS_VER} && \
    make -j"$(nproc)" && make install && cd .. && \
    tar -xf samtools-${HTS_VER}.tar.bz2 && cd samtools-${HTS_VER} && \
    make -j"$(nproc)" && make install && cd .. && \
    rm -rf /build/* && ldconfig   # refresh linker cache

# ─── 4. build fqtools (patched) ──────────────────────────────────────────────
WORKDIR /build
RUN git clone --depth 1 https://github.com/alastair-droop/fqtools && \
    cd fqtools && \
    # 1. pull a *header-compatible* copy of HTSlib 1.21
    git clone --branch 1.21 --depth 1 \
              --recurse-submodules --shallow-submodules \
              https://github.com/samtools/htslib && \
    # 2. patch the outdated #include’s              (GitHub issue #18)
    sed -i 's|<sam.h>|"htslib/sam.h"|' src/fqheader.h && \
    sed -i 's|<bam.h>|"htslib/bam.h"|' src/fqheader.h && \
    # 3. build the vendored HTSlib just for the headers
    cd htslib && autoreconf -fi && ./configure && make -j"$(nproc)" && make install && \
    # 4. build fqtools itself (GCC≥10 needs -fcommon)
    cd ..   && make CFLAGS="-O2 -g -fcommon" -j"$(nproc)" && \
    # 5. install the binary that ends up in ./bin/
    install -m 755 bin/fqtools /usr/local/bin/fqtools && \
    cd / && rm -rf /build/*

# ─── 5. strip tool-chain ─────────────────────────────────────────────────────
RUN apt-get purge -y --auto-remove build-essential automake autoconf libtool && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ─── 6. final image ──────────────────────────────────────────────────────────
USER ${USER}
WORKDIR /data
ENV PATH=/usr/local/bin:$PATH
CMD ["/bin/bash"]
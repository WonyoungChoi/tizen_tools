########################################
### Stage for toolchains and sysroot ###
########################################

FROM ubuntu:20.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y git curl rpm2cpio cpio zip pciutils libncurses5 libpython2.7 python2.7 python3
RUN apt-get clean

# Only non-root users can install Tizen Studio.
RUN useradd -ms /bin/bash user
USER user
WORKDIR /home/user

# Install Tizen Studio
ENV TIZEN_STUDIO=/home/user/tizen-studio
RUN curl -o installer.bin http://download.tizen.org/sdk/Installer/tizen-studio_4.1.1/web-cli_Tizen_Studio_4.1.1_ubuntu-64.bin
RUN chmod a+x installer.bin
RUN ./installer.bin --accept-license ${TIZEN_STUDIO}
RUN ${TIZEN_STUDIO}/package-manager/package-manager-cli.bin install NativeToolchain-Gcc-9.2

# Create tizen_tools directory first to grant privileges to user.
ENV TIZEN_TOOLS=/home/user/tizen_tools
RUN mkdir -p ${TIZEN_TOOLS}
WORKDIR ${TIZEN_TOOLS}

# Prepare for copying.
ENV TOOLCHAINS_PATH=${TIZEN_TOOLS}/toolchains
RUN mkdir -p ${TOOLCHAINS_PATH}
ENV SYSROOT_PATH=${TIZEN_TOOLS}/sysroot
RUN mkdir -p ${SYSROOT_PATH}

# Copy toolchains.
SHELL ["/bin/bash", "-c"]
RUN mkdir -p ${TOOLCHAINS_PATH}/bin
RUN for f in ${TIZEN_STUDIO}/tools/arm-linux-gnueabi-gcc-9.2/bin/arm-linux-*; do \
    b=$(basename $f); \
    cp $f ${TOOLCHAINS_PATH}/bin/armv7l-tizen-${b:4}; \
    done
RUN for f in ${TIZEN_STUDIO}/tools/aarch64-linux-gnu-gcc-9.2/bin/aarch64-linux-*; do \
    b=$(basename $f); \
    cp $f ${TOOLCHAINS_PATH}/bin/aarch64-tizen-${b:8}; \
    done
RUN for f in ${TIZEN_STUDIO}/tools/i586-linux-gnueabi-gcc-9.2/bin/i586-linux-*; do \
    b=$(basename $f); \
    cp $f ${TOOLCHAINS_PATH}/bin/i586-tizen-${b:5}; \
    done

# FIXME: https://github.com/flutter-tizen/tizen_tools/pull/7#discussion_r611339789
RUN ln -s aarch64-tizen-linux-gnu-ld ${TOOLCHAINS_PATH}/bin/ld

# FIXME: This should not be necessary.
RUN mkdir -p ${SYSROOT_PATH}/arm64/usr/lib
RUN cp -r ${TIZEN_STUDIO}/tools/aarch64-linux-gnu-gcc-9.2/lib/gcc/aarch64-tizen-linux-gnu/9.2.0/*.{o,a} ${SYSROOT_PATH}/arm64/usr/lib

# FIXME: This should not be necessary.
RUN mkdir -p ${TOOLCHAINS_PATH}/lib/gcc
RUN cp -r ${TIZEN_STUDIO}/tools/i586-linux-gnueabi-gcc-9.2/lib/gcc/i586-tizen-linux-gnueabi ${TOOLCHAINS_PATH}/lib/gcc

# Construct sysroots.
COPY sysroot/build-rootfs.py ${SYSROOT_PATH}
COPY sysroot/*.patch ${SYSROOT_PATH}
RUN ${SYSROOT_PATH}/build-rootfs.py --arch arm
RUN ${SYSROOT_PATH}/build-rootfs.py --arch arm64
RUN ${SYSROOT_PATH}/build-rootfs.py --arch x86


#############################
### Image for tizen-tools ###
#############################

FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install packages for engine build.
RUN apt-get update && \
    apt-get install -y git curl ca-certificates python && \
    apt-get clean

# Copy tizen_tools from the previous stage.
COPY --from=builder /home/user/tizen-studio/tools/llvm-10/  /tizen_tools/toolchains/
COPY --from=builder /home/user/tizen_tools/toolchains/  /tizen_tools/toolchains/
COPY --from=builder /home/user/tizen_tools/sysroot/  /tizen_tools/sysroot/

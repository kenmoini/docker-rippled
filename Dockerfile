ARG CACHE_BREAKER=1
FROM registry.access.redhat.com/ubi10/ubi-minimal:latest

# Labels for OpenShift/Kubernetes
LABEL name="rippled" \
      summary="XRP Ledger Daemon" \
      description="Runs rippled, the XRP Ledger Daemon, commonly as a validator node" \
      maintainer="Ken Moini" \
      version="1.0" \
      io.k8s.display-name="rippled" \
      io.k8s.description="Runs rippled, the XRP Ledger Daemon, commonly as a validator node" \
      io.openshift.tags="cryptocurrency,xrp,ripple,rippled"

# Only works on x86
#COPY ripple.repo /etc/yum.repos.d/

WORKDIR /opt/app-root/src

# Install and update
RUN microdnf update -y && \
    microdnf install -y ca-certificates gcc g++ python3 python3-pip python3-devel curl wget git cmake && \
    microdnf clean all && \
    rm -rf /var/cache/yum

# Build Conan and rippled
RUN git clone https://github.com/conan-io/conan.git conan-io && \
    cd conan-io && pip install -e . && \
    cd .. && \
    git clone https://github.com/XRPLF/rippled.git && \
    cd rippled && \
    git checkout master && \
    conan config install conan/profiles/ -tf $(conan config home)/profiles/ && \
    conan remote add --index 0 xrplf https://conan.ripplex.io && \
    mkdir .build && cd .build && \
    conan install .. --output-folder . --build missing --settings build_type=Release

WORKDIR /opt/app-root/src/rippled/.build

RUN cmake -DCMAKE_TOOLCHAIN_FILE:FILEPATH=build/generators/conan_toolchain.cmake -DCMAKE_BUILD_TYPE=Release -Dxrpld=ON -Dtests=ON ..

RUN cmake --build . && \
    ./xrpld --unittest --unittest-jobs 4 && \
    mv xrpld /usr/local/bin

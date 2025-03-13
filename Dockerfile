#!UseOBSRepositories

#!BuildTag: rancher/image-build-k8s-metrics-server:v0.7.2
#!BuildTag: rancher/image-build-k8s-metrics-server:latest
#!BuildName: image-build-k8s-metrics-server

ARG GO_IMAGE=rancher/image-build-base:latest

FROM ${GO_IMAGE} as base-builder
ARG TARGETPLATFORM
# setup required packages
RUN set -euo pipefail; \
    zypper -n install --no-recommends \
    # file \
    gcc \
    # git \
    libselinux-devel \
    libseccomp-devel \ 
    # glibc \
    # glibc-devel-static \    
    musl-gcc \
    musl-libc-static \
    make; \
    # zypper -n install -t pattern devel_basis; \
    zypper -n clean; \
    rm -rf {/target,}/var/log/{alternatives.log,lastlog,tallylog,zypper.log,zypp/history,YaST2}


# setup the build
FROM base-builder as metrics-builder
ARG PKG="github.com/kubernetes-incubator/metrics-server"
ARG SRC="github.com/kubernetes-sigs/metrics-server"
ARG TAG=v0.7.2
ARG TARGETARCH

COPY metrics-server ${GOPATH}/src/${PKG}
ADD vendor.tar.gz ${GOPATH}/src/${PKG}

WORKDIR $GOPATH/src/${PKG}

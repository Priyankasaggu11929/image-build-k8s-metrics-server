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
    # gcc \
    # git \
    libselinux-devel \
    libseccomp-devel \ 
    # glibc \
    # glibc-devel-static \    
    musl-gcc \
    musl-libc-static \
    make; \
    # TODO(psaggu): check which repo provides this in SLE BCI images
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
ADD vendor.tar.gz ${GOPATH}/src/${PKG}/cmd

WORKDIR $GOPATH/src/${PKG}

RUN ls $GOPATH/src/${PKG}

RUN go install -mod=readonly -modfile=scripts/go.mod -mod=vendor k8s.io/kube-openapi/cmd/openapi-gen && \
    ${GOPATH}/bin/openapi-gen --logtostderr \
    -i k8s.io/metrics/pkg/apis/metrics/v1beta1,k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/api/resource,k8s.io/apimachinery/pkg/version \
    -p ${PKG}/pkg/generated/openapi/ \
    -O zz_generated.openapi \
    -h $(pwd)/scripts/boilerplate.go.txt \
    -r /dev/null;
# cross-compilation setup
ARG TARGETPLATFORM
RUN CGO_ENABLED=1 \
    GO_LDFLAGS="-linkmode=external \
    -X ${PKG}/pkg/version.Version=${TAG} \
    -X ${PKG}/pkg/version.gitCommit=$(git rev-parse HEAD) \
    -X ${PKG}/pkg/version.gitTreeState=clean \
    " \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod=vendor -o bin/metrics-server ./cmd/metrics-server
RUN go-assert-static.sh bin/*
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
       go-assert-boring.sh bin/*; \
    fi
RUN install bin/metrics-server /usr/local/bin

FROM ${GO_IMAGE} as strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=metrics-builder /usr/local/bin/metrics-server /usr/local/bin
RUN metrics-server --help
RUN strip /usr/local/bin/metrics-server

FROM scratch as k8s-metrics-server
COPY --from=strip_binary /usr/local/bin/metrics-server /
ENTRYPOINT ["/metrics-server"]

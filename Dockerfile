FROM registry.access.redhat.com/ubi8

ARG PARALLEL_JOBS=4

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

RUN yum --disableplugin=subscription-manager update -y && \
    yum --disableplugin=subscription-manager install -y \
    make \
    cmake \
    git \
    gcc \
    gcc-c++ \
    wget \
    rpm-build \
    re2-devel \
    zlib-devel \
    openssl-devel

# rpmdevtools is required to set up the RPM build environment and create the source tarball
RUN wget https://rpmfind.net/linux/almalinux/8.10/AppStream/ppc64le/os/Packages/rpmdevtools-8.10-8.el8.noarch.rpm && \
    rpm -ivh rpmdevtools-8.10-8.el8.noarch.rpm

RUN yum --disableplugin=subscription-manager clean all

# Set up the RPM build directory structure
WORKDIR /root
RUN rpmdev-setuptree

ARG GRPC_VERSION=1.62.2
WORKDIR /tmp
RUN set -eux; \
    GRPC_DIR="grpc-${GRPC_VERSION}"; \
    git clone --depth 1 -b "v$GRPC_VERSION" https://github.com/grpc/grpc "$GRPC_DIR"; \
    cd "$GRPC_DIR"; \
    git submodule update --init --recursive; \
    cd /tmp; \
    tar -czf ~/rpmbuild/SOURCES/"${GRPC_DIR}".tar.gz "$GRPC_DIR"

RUN rm -rf /tmp/grpc-*

# Create the RPM spec file for gRPC
RUN cd  ~/rpmbuild/SPECS && \
    cat <<EOF > grpc.spec
Name:           grpc
Version:        ${GRPC_VERSION}
Release:        1%{?dist}
Summary:        gRPC - A high-performance, open-source universal RPC framework
License:        Apache-2.0
URL:            https://grpc.io/
Source0:        %{name}-%{version}.tar.gz

# Disable automatic debug packages
%global debug_package %{nil}

%ifarch x86_64
%global _libdir %{_prefix}/lib
%endif

BuildRequires:  cmake
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  openssl-devel
BuildRequires:  re2-devel
BuildRequires:  zlib-devel

%description
gRPC is a modern open-source high performance Remote Procedure Call (RPC)
framework that can run in any environment.

%package devel
Summary:        Development files for grpc
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description devel
Headers, pkg-config files, and CMake configuration files for developing
applications using gRPC.

%prep
%setup -q

%build
mkdir -p build
cd build

cmake .. \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
  -DCMAKE_BUILD_TYPE=Release \
  -DgRPC_INSTALL=ON \
  -DgRPC_BUILD_TESTS=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DgRPC_SSL_PROVIDER=package \
  -DgRPC_ZLIB_PROVIDER=package \
  -DgRPC_RE2_PROVIDER=package  \
  -DgRPC_ABSL_PROVIDER=module \
  -DgRPC_CARES_PROVIDER=module \
  -DgRPC_RE2_PROVIDER=package \
  -DgRPC_PROTOBUF_PROVIDER=module

make -j ${PARALLEL_JOBS}

%install
rm -rf %{buildroot}
cd build
make install DESTDIR=%{buildroot}

%files
%license LICENSE
%doc README.md
%doc %{_datadir}/man/

%{_bindir}/grpc_*
%{_bindir}/protoc*
%{_bindir}/adig
%{_bindir}/ahost
%{_bindir}/acountry
%{_libdir}/*.a
%{_datadir}/grpc/roots.pem

%files devel
%{_includedir}/grpc*
%{_includedir}/google/
%{_includedir}/absl/
%{_includedir}/ares*
%{_includedir}/utf8*
%{_includedir}/java/
%{_libdir}/cmake/grpc
%{_libdir}/pkgconfig/*.pc
%{_libdir}/cmake/*/*.cmake

EOF

RUN mkdir -p /tmp/rpms/

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["rpmbuild -ba /root/rpmbuild/SPECS/grpc.spec && cp /root/rpmbuild/RPMS/*/*.rpm /tmp/rpms/"]
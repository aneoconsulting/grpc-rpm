FROM registry.access.redhat.com/ubi8

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
    abseil-cpp-devel \
    protobuf \
    protobuf-compiler \
    openssl-devel

# rpmdevtools is required to set up the RPM build environment and create the source tarball
RUN wget https://rpmfind.net/linux/almalinux/8.10/AppStream/ppc64le/os/Packages/rpmdevtools-8.10-8.el8.noarch.rpm && \
    rpm -ivh rpmdevtools-8.10-8.el8.noarch.rpm

# gRPC requires c-ares >= 1.13.0 and c-ares-devel >= 1.13.0, which are not available in the default repositories, so we need to download and install them manually
RUN wget https://rpmfind.net/linux/centos-stream/9-stream/BaseOS/x86_64/os/Packages/c-ares-1.17.1-4.el9.x86_64.rpm && \
    rpm -ivh c-ares-1.17.1-4.el9.x86_64.rpm
RUN wget https://rpmfind.net/linux/centos-stream/9-stream/AppStream/x86_64/os/Packages/c-ares-devel-1.17.1-4.el9.x86_64.rpm && \
    rpm -ivh c-ares-devel-1.17.1-4.el9.x86_64.rpm

# gRPC protobuf-devel which is not available in the default repositories, so we need to download and install them manually
RUN wget https://rpmfind.net/linux/almalinux/8.10/PowerTools/x86_64/os/Packages/protobuf-devel-3.5.0-17.el8_10.x86_64.rpm && \
    rpm -ivh protobuf-devel-3.5.0-17.el8_10.x86_64.rpm

RUN yum --disableplugin=subscription-manager clean all

# Set up the RPM build directory structure
WORKDIR /root
RUN rpmdev-setuptree

ARG GRPC_VERSION=1.14.2
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
BuildRequires:  abseil-cpp-devel
BuildRequires:  c-ares-devel 
BuildRequires:  openssl-devel
BuildRequires:  re2-devel
BuildRequires:  protobuf-devel
BuildRequires:  protobuf-compiler
BuildRequires:  zlib-devel

Requires:       protobuf

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
  -DBUILD_SHARED_LIBS=ON \
  -DgRPC_SSL_PROVIDER=package \
  -DgRPC_ZLIB_PROVIDER=package \
  -DgRPC_RE2_PROVIDER=package  \
  -DgRPC_ABSL_PROVIDER=package \
  -DgRPC_CARES_PROVIDER=package \
  -DgRPC_RE2_PROVIDER=package \
  -DgRPC_PROTOBUF_PROVIDER=package

make -j 6

%install
rm -rf %{buildroot}
cd build
make install DESTDIR=%{buildroot}

%files
%license LICENSE
%doc README.md

%{_bindir}/grpc_*
%{_libdir}/libgrpc*.so*
%{_libdir}/libgpr*.so*
%{_libdir}/libgflags*.so*
/usr/share/grpc/roots.pem
/usr/bin/gflags_completions.sh
/usr/lib/libaddress_sorting.so

%exclude %{_includedir}/benchmark
%exclude /root/.cmake/*
%exclude %{_libdir}/cmake/benchmark/*
%exclude %{_libdir}/libbenchmark*

%files devel
%{_includedir}/grpc*
%{_includedir}/gflags/*
%{_includedir}/benchmark/*

%{_libdir}/cmake/grpc
%{_libdir}/cmake/gflags
/usr/lib/pkgconfig/gflags.pc

EOF

#RUN rpmbuild -ba /root/rpmbuild/SPECS/grpc.spec && \
#    mkdir -p /tmp/rpms && \
#    cp /root/rpmbuild/RPMS/*/*.rpm /tmp/rpms/ && \
#    cp /root/rpmbuild/SRPMS/*.rpm /tmp/rpms/
#
#VOLUME ["/tmp/rpms"]
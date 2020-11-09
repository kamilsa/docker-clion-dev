FROM ubuntu:20.04

########################################################
# Essential packages for remote debugging and login in
########################################################

ARG DEBIAN_FRONTEND=noninteractive

# add llvm repo
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        gpg \
        gpg-agent \
        wget \
        software-properties-common \
        git \
        curl \
        python \
        python3 \
        python3-pip \
        python3-setuptools \
        apt-utils gcc g++ openssh-server build-essential gdb gdbserver rsync vim \
    && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    add-apt-repository -y "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-10 main" && \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && rm -rf /var/lib/apt/lists/*

# RUN apt-get update && apt-get upgrade -y && apt-get install -y \
#     apt-utils gcc g++ openssh-server build-essential gdb gdbserver rsync vim python3 python3-pip python3-setuptools

# install cmake and dev dependencies
RUN python3 -m pip install --no-cache-dir --upgrade pip
RUN pip3 install --no-cache-dir scikit-build cmake requests gitpython gcovr pyyaml
RUN pip install requests

# install rustc
ENV RUST_VERSION=nightly-2020-08-27
ENV RUSTUP_HOME="/opt/rust/.rustup"
ENV CARGO_HOME="/opt/rust/.cargo"
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN whoami
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain ${RUST_VERSION}
RUN echo "RUSTUP_HOME=${RUSTUP_HOME}" >> /etc/environment
RUN echo "CARGO_HOME=${CARGO_HOME}" >> /etc/environment

# install go
ENV GOPATH="/opt/go"
RUN mkdir ${GOPATH} && wget -c https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz -O - | tar -xz -C /opt
ENV PATH $GOPATH/bin:$PATH
RUN echo "GOPATH=${GOPATH}" >> /etc/environment


RUN echo "PATH=${PATH}" >> /etc/environment

ADD . /code
WORKDIR /code

# Taken from - https://docs.docker.com/engine/examples/running_ssh_service/#environment-variables

RUN mkdir /var/run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# 22 for ssh server. 7777 for gdb server.
EXPOSE 22 7777

RUN useradd -ms /bin/bash debugger
RUN chmod ugo+rwx ${RUSTUP_HOME}
RUN chmod ugo+rwx ${CARGO_HOME}
RUN chmod -R 777 ${GOPATH}
RUN echo 'debugger:pwd' | chpasswd

########################################################
# Add custom packages and development environment here
########################################################

########################################################
USER root
RUN whoami
CMD ["/usr/sbin/sshd", "-D"]

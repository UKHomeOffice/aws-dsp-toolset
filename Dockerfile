FROM fedora:24

RUN dnf upgrade -y -q && dnf clean all
RUN dnf install -y -q procps-ng openssl gettext git jq docker which tar openssh-clients ruby unzip && dnf clean all

RUN pip3 install awscli testinfra

RUN curl -s https://pkg.cfssl.org/R1.1/cfssl_linux-amd64 -o /usr/bin/cfssl && chmod +x /usr/bin/cfssl \
  && curl -s https://pkg.cfssl.org/R1.1/cfssljson_linux-amd64 -o /usr/bin/cfssljson && chmod +x /usr/bin/cfssljson \
  && pip3 install git+https://github.com/cfstacks/stacks.git@v0.3.4 \
  && curl -s -L https://github.com/UKHomeOffice/s3secrets/releases/download/v1.0.0/s3secrets-linux-amd64 -o /usr/bin/s3secrets && chmod +x /usr/bin/s3secrets \
  && curl -s -L https://github.com/coreos/fleet/releases/download/v0.11.8/fleet-v0.11.8-linux-amd64.tar.gz | tar -xzf - -C /usr/bin --strip-components=1 '*/fleetctl' \
  && curl -s -L https://storage.googleapis.com/kubernetes-release/release/v1.3.8/bin/linux/amd64/kubectl -o /usr/bin/kubectl && chmod +x /usr/bin/kubectl \
  && curl -s -L https://s3-eu-west-1.amazonaws.com/hod-dsp-tools/coreos-cloudinit-1.10.0-linux-amd64 -o /usr/bin/coreos-cloudinit && chmod +x /usr/bin/coreos-cloudinit \
  && export KB8OR_VER=0.6.13 && \
      curl -s -L https://github.com/UKHomeOffice/kb8or/archive/v${KB8OR_VER}.tar.gz | tar -xzf - -C /var/lib && \
      cd /var/lib/kb8or-${KB8OR_VER}/ && \
      gem install bundler && \
      bundle install && \
      ln -s /var/lib/kb8or-${KB8OR_VER}/kb8or.rb /usr/bin/kb8or

COPY bin/* /usr/local/bin/

RUN /usr/bin/aws --version \
  && /usr/bin/docker --version \
  && /usr/bin/cfssl version \
  && /usr/bin/stacks --version \
  && /usr/bin/kubectl version --client \
  && /usr/bin/fleetctl version \
  && /usr/bin/coreos-cloudinit -version \
  && /usr/bin/s3secrets --help > /dev/null \
  && /usr/bin/kb8or --version > /dev/null

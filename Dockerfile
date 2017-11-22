FROM fedora:25

RUN dnf upgrade -y -q && dnf clean all
RUN dnf install -y -q procps-ng openssl gettext git jq docker which tar openssh-clients unzip && dnf clean all

RUN pip3 install awscli testinfra

RUN curl -s https://pkg.cfssl.org/R1.1/cfssl_linux-amd64 -o /usr/bin/cfssl && chmod +x /usr/bin/cfssl \
  && curl -s https://pkg.cfssl.org/R1.1/cfssljson_linux-amd64 -o /usr/bin/cfssljson && chmod +x /usr/bin/cfssljson \
  && pip3 install git+https://github.com/cfstacks/stacks.git@v0.4.0 \
  && curl -s -L https://github.com/UKHomeOffice/s3secrets/releases/download/v1.0.0/s3secrets-linux-amd64 -o /usr/bin/s3secrets && chmod +x /usr/bin/s3secrets \
  && curl -s -L https://storage.googleapis.com/kubernetes-release/release/v1.8.4/bin/linux/amd64/kubectl -o /usr/bin/kubectl && chmod +x /usr/bin/kubectl \
  && curl -s -L https://s3-eu-west-1.amazonaws.com/hod-dsp-tools/coreos-cloudinit-1.10.0-linux-amd64 -o /usr/bin/coreos-cloudinit && chmod +x /usr/bin/coreos-cloudinit \
  && curl -s -L https://github.com/UKHomeOffice/kd/releases/download/v0.5.0/kd_linux_amd64 -o /usr/bin/kd && chmod +x /usr/bin/kd

COPY bin/* /usr/local/bin/

RUN /usr/bin/aws --version \
  && /usr/bin/docker --version \
  && /usr/bin/cfssl version \
  && /usr/bin/stacks --version \
  && /usr/bin/kubectl version --client \
  && /usr/bin/coreos-cloudinit -version \
  && /usr/bin/s3secrets --help > /dev/null \
  && /usr/bin/kd --version

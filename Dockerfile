FROM fedora:23

RUN dnf upgrade -y -q && dnf clean all
RUN dnf install -y -q git jq docker which tar && dnf clean all

RUN pip3 install awscli

RUN curl -s https://pkg.cfssl.org/R1.1/cfssl_linux-amd64 -o /usr/bin/cfssl && chmod +x /usr/bin/cfssl
RUN curl -s https://pkg.cfssl.org/R1.1/cfssljson_linux-amd64 -o /usr/bin/cfssljson && chmod +x /usr/bin/cfssljson
RUN curl -s -L https://github.com/cfstacks/stacks/releases/download/v0.2.4/stacks-0.2.4-linux-amd64.pex -o /usr/bin/stacks && chmod +x /usr/bin/stacks
RUN curl -s -L https://github.com/UKHomeOffice/s3secrets/releases/download/0.1.2/s3secrets_0.1.2_linux_x86_64 -o /usr/bin/s3secrets && chmod +x /usr/bin/s3secrets

RUN curl -s -L https://github.com/coreos/fleet/releases/download/v0.11.5/fleet-v0.11.5-linux-amd64.tar.gz | tar -xzf - -C /usr/bin --strip-components=1 '*/fleetctl'
RUN curl -s -L https://storage.googleapis.com/kubernetes-release/release/v1.1.1/bin/linux/amd64/kubectl -o /usr/bin/kubectl && chmod +x /usr/bin/kubectl
RUN curl -s -L https://s3-eu-west-1.amazonaws.com/hod-dsp-tools-eu-west-1/coreos-cloudinit-1.7.1-linux-amd64 -o /usr/bin/coreos-cloudinit && chmod +x /usr/bin/coreos-cloudinit

RUN /usr/bin/aws --version
RUN /usr/bin/docker --version
RUN /usr/bin/cfssl version
RUN /usr/bin/stacks --version
RUN /usr/bin/kubectl version -c
RUN /usr/bin/fleetctl version
RUN /usr/bin/coreos-cloudinit -version
RUN /usr/bin/s3secrets --help > /dev/null


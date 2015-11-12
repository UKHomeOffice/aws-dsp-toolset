FROM fedora:23

RUN dnf upgrade -y -q && dnf clean all
RUN dnf install -y -q git jq docker which tar && dnf clean all

RUN pip3 install awscli

RUN curl -s https://pkg.cfssl.org/R1.1/cfssl_linux-amd64 -o /usr/bin/cfssl && chmod +x /usr/bin/cfssl
RUN curl -s https://pkg.cfssl.org/R1.1/cfssljson_linux-amd64 -o /usr/bin/cfssljson && chmod +x /usr/bin/cfssljson
RUN curl -s -L https://github.com/cfstacks/stacks/releases/download/v0.2.0/stacks-0.2.0-linux-amd64 -o /usr/bin/stacks && chmod +x /usr/bin/stacks

RUN /usr/bin/aws --version
RUN /usr/bin/docker --version
RUN /usr/bin/cfssl version
RUN /usr/bin/stacks --version


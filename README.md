# AWS Digital Services Platform Toolset Container
[![Build Status](https://drone.digital.homeoffice.gov.uk/api/badges/UKHomeOffice/aws-dsp-toolset/status.svg)](https://drone.digital.homeoffice.gov.uk/UKHomeOffice/aws-dsp-toolset)

### Overview
This container is responsible for holding the necessary tools for working with AWS to build infrastructure:
* stacks
* aws cli
* cfssl
* coreos-cloudinit
* vaultctl
* docker
* s3secrets
* kubectl
* fleetctl

This is so we have versioned tools that we can test and validate against CI.

### Additions

Alongside the core tools are additional scripts that enable functionality in a central place.

* peer_vpc
* encrypt_secrets
* decrypt_secrets
* instances-list

#### Peer VPC

This is used to peer VPC's together, (VPC Peering)

#### Encrypt Secrets

This is used to encrypt secrets in a specific path and based on environment. If there are any files:
```
stacks/config.d/secrets_${stacks_env}.yaml
```

It will use the kms key to encrypt those files leaving them as base64 encoded files e.g.

```
stacks/config.d/secrets_dev.yaml.enc
```

#### Decrypt Secrets

This is used to decrypt secrets based on the above leaving the yaml data as native data to be used by stacks
allowing you to use potentially more sensitive information inside your templates without compromising the security

```
cat stacks/config.d/secrets_dev.yaml
dev:
  some_secret: 'some_data'

{{some_secret}} now becomes a variable inside your templates for the development environment
```
This is done when run.sh is initiated, decrypt_secrets will be executed before it runs stacks.

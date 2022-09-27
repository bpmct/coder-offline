FROM ghcr.io/coder/coder:latest

USER root

RUN apk add curl unzip

# Create directory for the Terraform CLI (and assets)
RUN mkdir -p /opt/terraform

# In order to run Coder airgapped or within private networks,
# Terraform has to be bundled into the image in PATH or /opt.
#
# See https://github.com/coder/coder/blob/main/provisioner/terraform/serve.go#L24-L25
# for supported Terraform versions.
ARG TERRAFORM_VERSION=1.3.0
RUN curl -LOs https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && mv terraform /opt/terraform \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
ENV PATH=/opt/terraform:${PATH}

# Additionally, a Terraform mirror needs to be configured
# to download the Terraform providers used in Coder templates.
#
# There are two options:

# Option 1) Use a filesystem mirror. We can seed this at build-time
#    or by mounting a volume to /opt/terraform/plugins in the container.
#    https://developer.hashicorp.com/terraform/cli/config/config-file#filesystem_mirror
#
#    Be sure to add all the providers you use in your templates to /opt/terraform/plugins

RUN mkdir -p /opt/terraform/plugins
ADD filesystem-mirror-example.tfrc /opt/terraform/config.tfrc

# Optionally, we can "seed" the filesystem mirror with common providers.
# Coder and Docker. Comment out lines 37-47 if you plan on only using a
# volume or network mirror:
RUN mkdir -p /opt/terraform/plugins/registry.terraform.io
WORKDIR /opt/terraform/plugins/registry.terraform.io
ARG CODER_PROVIDER_VERSION=0.4.15
RUN echo "Adding coder/coder v${CODER_PROVIDER_VERSION}" \
    && mkdir -p coder/coder && cd coder/coder \
    && curl -LOs https://github.com/coder/terraform-provider-coder/releases/download/v${CODER_PROVIDER_VERSION}/terraform-provider-coder_${CODER_PROVIDER_VERSION}_linux_amd64.zip
ARG DOCKER_PROVIDER_VERSION=2.22.0
RUN echo "Adding kreuzwerker/docker v${DOCKER_PROVIDER_VERSION}" \
    && mkdir -p kreuzwerker/docker && cd kreuzwerker/docker \
    && curl -LOs https://github.com/kreuzwerker/terraform-provider-docker/releases/download/v${DOCKER_PROVIDER_VERSION}/terraform-provider-docker_${DOCKER_PROVIDER_VERSION}_linux_amd64.zip

RUN chown -R coder:coder /opt/terraform/plugins
WORKDIR /home/coder

# Option 2) Use a network mirror.
#    https://developer.hashicorp.com/terraform/cli/config/config-file#network_mirror

#    Be sure uncomment line 56 and edit network-mirror-example.tfrc to
#    specify the HTTPS base URL of your mirror.

# ADD network-mirror-example.tfrc /opt/terraform/config.tfrc

USER coder

# Use the tfrc file to inform
ENV TF_CLI_CONFIG_FILE=/opt/terraform/config.tfrc

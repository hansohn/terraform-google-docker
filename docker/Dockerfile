ARG UBUNTU_VERSION=latest


# builder
FROM hansohn/terraform:${TERRAFORM_VERSION} AS builder
ARG GCLOUD_CLI_VERSION=latest
ARG TFLINT_VERSION=latest
COPY dotfiles/. /root/
ENV CURL='curl -fsSL --netrc-optional'
RUN apt-get update && apt-get install --no-install-recommends -y \
      bash \
      ca-certificates \
      curl \
      jq \
      libc6 \
      unzip

# tflint
RUN /bin/bash -c 'TFLINT_GOOGLE_VERSION=$(${CURL} "https://api.github.com/repos/terraform-linters/tflint-ruleset-google/releases/latest" | jq -r .tag_name | sed -e "s:^v::") \
      && sed -ie "s:TFLINT_GOOGLE_VERSION:$TFLINT_GOOGLE_VERSION:" /root/.tflint.hcl \
      && GITHUB_TOKEN=${GITHUB_TOKEN:-$(awk "'"c&&!--c;/github.com/{c=2}"'" /root/.netrc | awk "'"{print $2;exit}"'")} \
      && tflint --version \
      && tflint --init'

# gcloud cli
RUN /bin/bash -c 'ARCH=$(uname -m | sed -re "s/(arm)64/\1/g") \
      && if [[ "${GCLOUD_CLI_VERSION}" == "latest" ]]; then GCLOUD_CLI_VERSION=$(${CURL} "https://raw.githubusercontent.com/google-github-actions/setup-cloud-sdk/main/data/versions.json" | jq -r "last"); fi \
      && ${CURL} https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-${ARCH}.tar.gz -o google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-${ARCH}.tar.gz \
      && mkdir /usr/local/google-cloud-sdk \
      && tar -xzf google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-${ARCH}.tar.gz -C /usr/local/google-cloud-sdk --strip-components 1 \
      && /usr/local/google-cloud-sdk/install.sh --usage-reporting false --rc-path false --bash-completion false --quiet \
      && source /usr/local/google-cloud-sdk/path.bash.inc \
      && gcloud --version'


# main
FROM hansohn/terraform:${TERRAFORM_VERSION} AS main
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
      bash \
      curl \
      ca-certificates \
      git \
      jq \
      unzip \
      vim \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*
COPY --from=builder /root/.tflint.d/. /root/.tflint.d/
COPY --from=builder /root/.tflint.hcl /root/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/google-cloud-sdk/ /usr/local/google-cloud-sdk/
RUN /bin/bash -c 'terraform --version'
RUN echo '\n\
if [ -f "/usr/local/google-cloud-sdk/path.bash.inc" ]; then . "/usr/local/google-cloud-sdk/path.bash.inc"; fi\n\
if [ -f "/usr/local/google-cloud-sdk/completion.bash.inc" ]; then . "/usr/local/google-cloud-sdk/completion.bash.inc"; fi' >> /root/.bashrc

ENTRYPOINT []

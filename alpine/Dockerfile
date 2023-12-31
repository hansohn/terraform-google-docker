ARG ALPINE_VERSION=latest


# builder
FROM alpine:${ALPINE_VERSION} as builder
ARG GCLOUD_CLI_VERSION=latest
ARG TERRAFORM_DOCS_VERSION=latest
ARG TERRAFORM_VERSION=latest
ARG TERRAGRUNT_VERSION=latest
ARG TFGET_VERSION=latest
ARG TFLINT_VERSION=latest
ARG TFSEC_VERSION=latest
COPY dotfiles/. /root/
ENV CURL='curl -fsSL --netrc-optional'
RUN apk add --update --no-cache \
    bash \
    ca-certificates \
    curl \
    jq \
    python3 \
    unzip

# terraform
RUN /bin/bash -c 'if [[ "${TFGET_VERSION}" == "latest" ]]; then TFGET_VERSION=$(${CURL} "https://api.github.com/repos/hansohn/tfget/releases/latest" | jq -r .tag_name  | sed -e "s:^v::"); fi \
      && ${CURL} https://github.com/hansohn/tfget/releases/download/${TFGET_VERSION}/tfget-${TFGET_VERSION}.tar.gz -o tfget-${TFGET_VERSION}.tar.gz \
      && tar -xzf tfget-${TFGET_VERSION}.tar.gz \
      && mv tfget /usr/local/bin/ \
      && chmod +x /usr/local/bin/tfget \
      && tfget ${TERRAFORM_VERSION} \
      && terraform --version'

# terragrunt
RUN /bin/bash -c 'if [[ "${TERRAGRUNT_VERSION}" == "latest" ]]; then TERRAGRUNT_VERSION=$(${CURL} "https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest" | jq -r .tag_name); fi \
      && ${CURL} https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 -o /usr/local/bin/terragrunt \
      && chmod +x /usr/local/bin/terragrunt \
      && terragrunt --version'

# terraform-docs
RUN /bin/bash -c 'if [[ "${TERRAFORM_DOCS_VERSION}" == "latest" ]]; then TERRAFORM_DOCS_VERSION=$(${CURL} "https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest" | jq -r .tag_name); fi \
      && ${CURL} https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz -o terraform-docs.tar.gz \
      && tar -xzf terraform-docs.tar.gz \
      && mv terraform-docs /usr/local/bin/ \
      && chown root:root /usr/local/bin/terraform-docs \
      && chmod +x /usr/local/bin/terraform-docs \
      && terraform-docs --version'

# tflint
RUN /bin/bash -c 'if [[ "${TFLINT_VERSION}" == "latest" ]]; then TFLINT_VERSION=$(${CURL} "https://api.github.com/repos/terraform-linters/tflint/releases/latest" | jq -r .tag_name); fi \
      && ${CURL} https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip -o tflint.zip \
      && unzip tflint.zip \
      && mv tflint /usr/local/bin/ \
      && chmod +x /usr/local/bin/tflint \
      && TFLINT_GOOGLE_VERSION=$(${CURL} "https://api.github.com/repos/terraform-linters/tflint-ruleset-google/releases/latest" | jq -r .tag_name | sed -e "s:^v::") \
      && sed -ie "s:TFLINT_GOOGLE_VERSION:$TFLINT_GOOGLE_VERSION:" /root/.tflint.hcl \
      && GITHUB_TOKEN=${GITHUB_TOKEN:-$(awk "'"c&&!--c;/github.com/{c=2}"'" /root/.netrc | awk "'"{print $2;exit}"'")} \
      && tflint --version \
      && tflint --init'

# tfsec
RUN /bin/bash -c 'if [[ "${TFSEC_VERSION}" == "latest" ]]; then TFSEC_VERSION=$(${CURL} "https://api.github.com/repos/aquasecurity/tfsec/releases/latest" | jq -r .tag_name); fi \
      && ${CURL} https://github.com/aquasecurity/tfsec/releases/download/${TFSEC_VERSION}/tfsec-linux-amd64 -o /usr/local/bin/tfsec \
      && chmod +x /usr/local/bin/tfsec \
      && tfsec --version'

# gcloud cli
RUN /bin/bash -c 'if [[ "${GCLOUD_CLI_VERSION}" == "latest" ]]; then GCLOUD_CLI_VERSION=$(${CURL} "https://raw.githubusercontent.com/google-github-actions/setup-cloud-sdk/main/data/versions.json" | jq -r "last"); fi \
      && ${CURL} https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-x86_64.tar.gz -o google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-x86_64.tar.gz \
      && mkdir /usr/local/google-cloud-sdk \
      && tar -xzf google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-x86_64.tar.gz -C /usr/local/google-cloud-sdk --strip-components 1 \
      && /usr/local/google-cloud-sdk/install.sh --usage-reporting false --rc-path false --bash-completion false --quiet \
      && source /usr/local/google-cloud-sdk/path.bash.inc \
      && gcloud --version'

# main
FROM alpine:${ALPINE_VERSION} as main
RUN apk add --update --no-cache \
    bash \
    ca-certificates \
    curl \
    jq \
    python3 \
    unzip \
    vim
COPY --from=builder /root/.terraform.d/. /root/.terraform.d/
COPY --from=builder /root/.tflint.d/. /root/.tflint.d/
COPY --from=builder /root/.tflint.hcl /root/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/google-cloud-sdk/ /usr/local/google-cloud-sdk/
RUN /bin/bash -c 'terraform --version'
RUN echo $'\n\
if [ -f "/usr/local/google-cloud-sdk/path.bash.inc" ]; then . "/usr/local/google-cloud-sdk/path.bash.inc"; fi\n\
if [ -f "/usr/local/google-cloud-sdk/completion.bash.inc" ]; then . "/usr/local/google-cloud-sdk/completion.bash.inc"; fi' >> /root/.bashrc

ENTRYPOINT []

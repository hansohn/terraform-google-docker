# renovate: datasource=docker depName=hansohn/terraform
ARG TERRAFORM_VERSION=1.15.7


# builder
FROM hansohn/terraform:${TERRAFORM_VERSION} AS builder
ARG DEBIAN_FRONTEND=noninteractive
# renovate: datasource=github-releases depName=terraform-linters/tflint-ruleset-google extractVersion=^v(?<version>.+)$
ARG TFLINT_GOOGLE_VERSION=0.39.0
# renovate: datasource=docker depName=gcr.io/google.com/cloudsdktool/google-cloud-cli
ARG GCLOUD_CLI_VERSION=580.0.0
ENV CURL='curl -fsSL'
ENV CACHE_DIR='/var/cache/github-api'
# The gcloud installer is a Python program and the arm64 bundle ships without a
# bundled interpreter, so pin both stages to the system python3.
ENV CLOUDSDK_PYTHON='/usr/bin/python3'
COPY scripts/resolve-version.sh /opt/build/resolve-version
COPY config/.tflint.hcl /root/.tflint.hcl
RUN apt-get update && apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      jq \
      openssl \
      python3 \
      unzip \
  && mkdir -p ${CACHE_DIR} \
  && rm -rf /var/lib/apt/lists/*

# tflint-ruleset-google
# Installed directly as a manually-managed plugin (no `tflint --init`), so the
# build never reaches out to the GitHub API at lint time and the version is
# pinned and checksum-verified here.
RUN --mount=type=cache,target=/var/cache/github-api \
    --mount=type=cache,target=/var/cache/downloads \
    /bin/bash -c 'set -e; \
  TFLINT_GOOGLE_VERSION=$(/opt/build/resolve-version tflint-ruleset-google "${TFLINT_GOOGLE_VERSION}"); \
  case "$(uname -m)" in \
    x86_64) ARCH=amd64 ;; \
    aarch64) ARCH=arm64 ;; \
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
  esac; \
  ARCHIVE="tflint-ruleset-google_linux_${ARCH}.zip"; \
  if [[ ! -f "/var/cache/downloads/tflint-ruleset-google-${TFLINT_GOOGLE_VERSION}-${ARCH}.zip" ]]; then \
  ${CURL} https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v${TFLINT_GOOGLE_VERSION}/${ARCHIVE} -o /var/cache/downloads/tflint-ruleset-google-${TFLINT_GOOGLE_VERSION}-${ARCH}.zip; \
  fi; \
  if [[ ! -f "/var/cache/downloads/tflint-ruleset-google-${TFLINT_GOOGLE_VERSION}_checksums.txt" ]]; then \
  ${CURL} https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v${TFLINT_GOOGLE_VERSION}/checksums.txt -o /var/cache/downloads/tflint-ruleset-google-${TFLINT_GOOGLE_VERSION}_checksums.txt; \
  fi; \
  EXPECTED_SHA=$(grep " ${ARCHIVE}\$" /var/cache/downloads/tflint-ruleset-google-${TFLINT_GOOGLE_VERSION}_checksums.txt | cut -d" " -f1); \
  ACTUAL_SHA=$(sha256sum /var/cache/downloads/tflint-ruleset-google-${TFLINT_GOOGLE_VERSION}-${ARCH}.zip | cut -d" " -f1); \
  if [[ -z "${EXPECTED_SHA}" ]] || [[ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then \
  echo "Checksum verification failed for ${ARCHIVE}" >&2; exit 1; \
  fi; \
  mkdir -p /root/.tflint.d/plugins; \
  unzip -o /var/cache/downloads/tflint-ruleset-google-${TFLINT_GOOGLE_VERSION}-${ARCH}.zip -d /root/.tflint.d/plugins \
  && chmod +x /root/.tflint.d/plugins/tflint-ruleset-google \
  && tflint --version'

# gcloud cli
# Google publishes no detached signature for the CLI bundle, so integrity is
# checked against the MD5 recorded for the release object in the Cloud Storage
# bucket that backs dl.google.com.
RUN --mount=type=cache,target=/var/cache/github-api \
    --mount=type=cache,target=/var/cache/downloads \
    /bin/bash -c 'set -e; \
  GCLOUD_CLI_VERSION=$(/opt/build/resolve-version gcloud-cli "${GCLOUD_CLI_VERSION}"); \
  case "$(uname -m)" in \
    x86_64) ARCH=x86_64 ;; \
    aarch64) ARCH=arm ;; \
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
  esac; \
  ARCHIVE="google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-${ARCH}.tar.gz"; \
  TARBALL="/var/cache/downloads/${ARCHIVE}"; \
  if [[ ! -f "${TARBALL}" ]]; then \
  ${CURL} https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${ARCHIVE} -o "${TARBALL}"; \
  fi; \
  EXPECTED_MD5=$(${CURL} "https://storage.googleapis.com/storage/v1/b/cloud-sdk-release/o/${ARCHIVE}" | jq -r .md5Hash); \
  ACTUAL_MD5=$(openssl md5 -binary "${TARBALL}" | openssl base64); \
  if [[ -z "${EXPECTED_MD5}" ]] || [[ "${EXPECTED_MD5}" == "null" ]] || [[ "${EXPECTED_MD5}" != "${ACTUAL_MD5}" ]]; then \
  echo "Checksum verification failed for ${ARCHIVE}" >&2; exit 1; \
  fi; \
  mkdir -p /usr/local/google-cloud-sdk; \
  tar -xzf "${TARBALL}" -C /usr/local/google-cloud-sdk --strip-components 1; \
  /usr/local/google-cloud-sdk/install.sh \
    --usage-reporting false \
    --path-update false \
    --command-completion false \
    --quiet; \
  rm -rf /usr/local/google-cloud-sdk/.install/.backup \
  && /usr/local/google-cloud-sdk/bin/gcloud --version'


# main
FROM hansohn/terraform:${TERRAFORM_VERSION} AS main
ARG DEBIAN_FRONTEND=noninteractive
# The gcloud CLI is a Python application and the base image ships without an
# interpreter, so provide one here (see CLOUDSDK_PYTHON below).
RUN apt-get update && apt-get install --no-install-recommends -y \
      python3 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/google-cloud-sdk/ /usr/local/google-cloud-sdk/
COPY --from=builder /root/.tflint.d/ /root/.tflint.d/
COPY --from=builder /root/.tflint.hcl /root/.tflint.hcl
ENV CLOUDSDK_PYTHON='/usr/bin/python3'
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"
# ENV PATH covers `docker run <image> gcloud ...` and interactive shells, but a
# login shell rebuilds PATH from /etc/profile, so the SDK is re-added there too.
RUN printf '. "/usr/local/google-cloud-sdk/path.bash.inc"\n' > /etc/profile.d/google-cloud-sdk.sh \
  && printf '\nif [ -f "/usr/local/google-cloud-sdk/completion.bash.inc" ]; then . "/usr/local/google-cloud-sdk/completion.bash.inc"; fi\n' >> /root/.bashrc \
  && gcloud --version \
  && terraform --version

ENTRYPOINT []

FROM python:3.10.5-alpine as builder

ARG AWS_CLI_VERSION=2.9.21
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR aws-cli
RUN python -m venv venv
RUN . venv/bin/activate
RUN scripts/installers/make-exe
RUN unzip -q dist/awscli-exe.zip
RUN aws/install --bin-dir /aws-cli-bin
RUN /aws-cli-bin/aws --version

# reduce image size: remove autocomplete and examples
RUN rm -rf \
    /usr/local/aws-cli/v2/current/dist/aws_completer \
    /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
    /usr/local/aws-cli/v2/current/dist/awscli/examples
RUN find /usr/local/aws-cli/v2/current/dist/awscli/data -name completions-1*.json -delete
RUN find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

FROM alpine:latest

LABEL maintainer="Catalyst Squad <community@catalystsquad.com>"

WORKDIR /workspace
RUN mkdir -p /workspace && cd /workspace
ARG TARGETPLATFORM=amd64

# Get all the tools in and up to date
ENV DEBIAN_FRONTEND=noninteractive
RUN apk update \
    && apk add \
    bash \
    curl \
    python3 \
    yq \
    ;

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/bin/ \
    ;

#RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
#    && unzip awscliv2.zip \
#    && ./aws/install \
#    && rm -rf awscliv2.zip aws \
#    ;

COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/

ARG UID=2000
ARG GID=2000
RUN addgroup -g ${GID} coolgroup
RUN adduser -D -H -h /workspace -u ${UID} -G coolgroup cooluser
RUN chown -R cooluser:coolgroup /workspace
USER cooluser

#ENTRYPOINT ["/bin/bash"]
CMD ["bash"]

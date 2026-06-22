ARG BASE_IMAGE
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest AS hooks-builder

ARG RUNNER_CONTAINER_HOOKS_VERSION=0.8.1

ENV HOOKS_URL="https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip"

RUN microdnf -y install unzip

RUN curl -fL "$HOOKS_URL" -o /tmp/runner-container-hooks.zip && \
    unzip /tmp/runner-container-hooks.zip -d /tmp/k8s


FROM ${BASE_IMAGE}

COPY --from=hooks-builder /tmp/k8s/ /home/runner/k8s/

ENV RUNNER_MANUALLY_TRAP_SIG=1 \
    ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

CMD ["/home/runner/run.sh"]

ARG grafana_version=7.1.2
FROM grafana/grafana:$grafana_version

COPY grafana.ini /etc/grafana/
USER root
ENV CHAMBER_VERSION=2.7.5
ENV CHAMBER_SHA256SUM=c85bf50f0bbb7db4fe00a1467337b07973f3680c40e808f124b08f437d493eea
RUN apk add curl
RUN curl -Ls https://github.com/segmentio/chamber/releases/download/v${CHAMBER_VERSION}/chamber-v${CHAMBER_VERSION}-linux-amd64 > chamber-linux-amd64 && \
    chmod +x chamber-linux-amd64 && \
    mv chamber-linux-amd64 /usr/local/bin/chamber

USER grafana

ENTRYPOINT chamber exec $CHAMBER_NAMESPACE -- /run.sh

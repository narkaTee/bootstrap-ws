FROM debian:trixie@sha256:2c91e484d93f0830a7e05a2b9d92a7b102be7cab562198b984a84fdbc7806d91

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ansible \
        python3 \
        sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/ansible
COPY ansible.cfg .
COPY requirements.yaml .
COPY roles/ roles/
COPY sandbox/sandbox.yaml .
COPY sandbox/inventory ./inventory

RUN ansible-galaxy collection install -r requirements.yaml

RUN ansible-playbook sandbox.yaml

RUN rm -rf /tmp/ansible && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY sandbox/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chown dev:dev /entrypoint.sh

USER dev
ENV USER dev

COPY sandbox/pre-warm-tools.sh /home/dev/pre-warm-tools.sh
RUN /home/dev/pre-warm-tools.sh && rm /home/dev/pre-warm-tools.sh

WORKDIR /home/dev/workspace

EXPOSE 2222
ENTRYPOINT ["/entrypoint.sh"]

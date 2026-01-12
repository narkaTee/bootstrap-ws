FROM debian:trixie@sha256:0d01188e8dd0ac63bf155900fad49279131a876a1ea7fac917c62e87ccb2732d

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

FROM debian:trixie@sha256:3615a749858a1cba49b408fb49c37093db813321355a9ab7c1f9f4836341e9db

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

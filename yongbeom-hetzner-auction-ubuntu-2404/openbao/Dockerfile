FROM openbao/openbao

RUN mkdir -p /openbao/raft && \
    chown -R openbao:openbao /openbao/raft && \
    chmod 700 /openbao/raft

COPY ./config.hcl /openbao/config/

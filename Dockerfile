# Illumio Dockerized PCE

ARG BASE_REGISTRY=registry.access.redhat.com
ARG BASE_IMAGE=ubi8/ubi
ARG BASE_TAG=8.4
FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

RUN useradd ilo-pce

RUN yum install -y procps openssl hostname bzip2 langpacks-en glibc-langpack-en; \
    yum clean all;

# Copy software controls to container image
COPY scripts/illumio.sh /usr/bin/ 
COPY config/limits.conf config/sysctl.conf /etc/
COPY LICENSE config/runtime_env.yml.template /tmp/
COPY config/pcealiases /home/ilo-pce
COPY --chown=ilo-pce:ilo-pce software/foo *.gpg software/*.xz software/*.tgz software/*.bz2 /home/ilo-pce/

# set up environment for the PCE
RUN install -d -o ilo-pce -g ilo-pce /opt/illumio-pce && \
    install -d -o ilo-pce -g ilo-pce -m 775 /var/lib/illumio-pce && \
    install -d -o ilo-pce -g ilo-pce -m 775 /var/lib/illumio-pce/data && \
    install -d -o ilo-pce -g ilo-pce -m 775 /var/lib/illumio-pce/runtime && \
    install -d -o ilo-pce -g ilo-pce -m 775 /var/lib/illumio-pce/cert && \
    install -d -o ilo-pce -g ilo-pce -m 775 /var/lib/illumio-pce/keys && \
    install -d -o ilo-pce -g ilo-pce -m 775 /var/lib/illumio-pce/tmp && \
    install -d -o ilo-pce -g ilo-pce -m 775 /var/log/illumio-pce && \
    mkdir /etc/illumio-pce && \
    echo LANG="en_US.UTF-8" > /etc/locale.conf && \
    touch /etc/illumio-pce/runtime_env.yml && \
    chown root:ilo-pce /etc/illumio-pce/runtime_env.yml && \
    chmod 660 /etc/illumio-pce/runtime_env.yml && \
    chown root:ilo-pce /usr/bin/illumio.sh && \
    chmod 770 /usr/bin/illumio.sh

USER ilo-pce

ENTRYPOINT /usr/bin/illumio.sh

# Persistent volumes for Illumio
VOLUME /var/lib/illumio-pce
VOLUME /var/log/illumio-pce

# Expose our standard ports
EXPOSE 8443
EXPOSE 8444

HEALTHCHECK --interval=5m --timeout=30s CMD /opt/illumio-pce/illumio-pce-ctl status -x || exit 1
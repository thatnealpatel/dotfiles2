# Throwaway Debian 13 host for testing bootstrap end to end.
# A non-root user with passwordless sudo mirrors a real VM. The three
# directories created here are mounted as named volumes by run.sh so slow
# clones and builds carry over between runs.
FROM debian:13
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo git ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -s /bin/bash neal \
 && echo 'neal ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/neal \
 && mkdir -p /home/neal/.cache /home/neal/w /home/neal/go \
 && chown neal:neal /home/neal/.cache /home/neal/w /home/neal/go
USER neal
WORKDIR /home/neal

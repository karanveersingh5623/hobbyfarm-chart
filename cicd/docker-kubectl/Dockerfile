FROM boxboat/kubectl:1.17.0

USER root:root

# install fixuid
RUN curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.4/fixuid-0.4-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - \
    && chown root:root /usr/local/bin/fixuid \
    && chmod 4755 /usr/local/bin/fixuid

USER alpine:alpine

# make .kube dir
RUN mkdir /home/alpine/.kube

# copy staged files
COPY stage/ /

ENTRYPOINT ["fixuid"]
CMD ["sh", "-c", "trap : TERM INT; (while true; do sleep 1000; done) & wait"]

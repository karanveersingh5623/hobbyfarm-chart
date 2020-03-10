FROM kindest/node:v1.17.0

# copy staged / files
COPY stage/ /

ENTRYPOINT ["/usr/local/bin/volume.sh", "/usr/local/bin/entrypoint", "/sbin/init"]

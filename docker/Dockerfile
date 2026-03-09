FROM nixos/nix:2.33.3

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "extra-platforms = aarch64-linux" >> /etc/nix/nix.conf

COPY docker/entrypoint.sh /entrypoint.sh
COPY . /src
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
WORKDIR /src

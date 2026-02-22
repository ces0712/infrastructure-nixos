FROM nixos/nix:2.33.3

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "extra-platforms = aarch64-linux" >> /etc/nix/nix.conf && \
    nix profile add \
        nixpkgs#ssh-to-age \
        nixpkgs#sops \
        nixpkgs#gnumake \
        nixpkgs#parted \
        nixpkgs#util-linux \
        nixpkgs#pv \
        nixpkgs#nixos-install

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
WORKDIR /src

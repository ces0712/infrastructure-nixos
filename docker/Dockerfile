FROM nixos/nix:2.33.3

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "extra-platforms = aarch64-linux" >> /etc/nix/nix.conf && \
    nix profile install \
        nixpkgs#openssh \
        nixpkgs#ssh-to-age \
        nixpkgs#sops \
        nixpkgs#gnumake \
        nixpkgs#parted \
        nixpkgs#util-linux \
        nixpkgs#pv \
        nixpkgs#nixos-install \
        nixpkgs#git

WORKDIR /src

{
  description = "Cross-platform CLI packages for kissy24's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/6e8b58cddc8438dbb68f8e292aa556e828685072";

    rust-overlay = {
      url = "github:oxalica/rust-overlay/1785b85aeccca381caf8777133410f577b8f2f59";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:ogulcancelik/herdr/9c9490d764d306b6cc093b5b3de1ccd4e6467c94";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      herdr,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          commonPackages = with pkgs; [
            bun
            fzf
            gh
            git
            go
            lazygit
            neovim
            ripgrep
            sheldon
            starship
            uv
            zoxide
            herdr.packages.${system}.default
          ];
          linuxPackages = nixpkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (
            with pkgs;
            [
              curl
              file
              gcc
              gnumake
              procps
              zsh
            ]
          );
          dotfiles = pkgs.buildEnv {
            name = "dotfiles-packages";
            paths = commonPackages ++ linuxPackages;
            pathsToLink = [ "/bin" ];
          };
        in
        {
          inherit dotfiles;
          default = dotfiles;
        }
      );

      checks = forAllSystems (system: {
        dotfiles = self.packages.${system}.dotfiles;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    self.submodules = true;
  };

  outputs = {
    self,
    nixpkgs,
    pre-commit-hooks,
  }: let
    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: function nixpkgs.legacyPackages.${system});
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        inherit (self.checks.${pkgs.system}.pre-commit-check) shellHook;

        hardeningDisable = ["fortify"];

        packages = with pkgs;
          [
            docker
            docker-compose

            python312
            (python3.withPackages (
              ps:
                with ps; let
                  reqRaw = builtins.readFile ./api/requirements.txt;
                  req =
                    lib.strings.filter (s: s != "")
                    (lib.strings.splitString "\n" reqRaw);
                in
                  map (p: ps.${p}) req
            ))
          ]
          ++ (with self.packages.${pkgs.system}; [
            ]);
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);

    checks = forAllSystems (pkgs: let
      inherit (pkgs) lib;

      hooks = {
        alejandra.enable = true;
        trim-trailing-whitespace.enable = true;
        commit-name = {
          enable = true;
          name = "commit name";
          stages = ["commit-msg"];
          entry = ''
            ${pkgs.python310.interpreter} ${./scripts/check_commit_message.py}
          '';
        };
      };
    in {
      pre-commit-check = pre-commit-hooks.lib.${pkgs.system}.run {
        inherit hooks;
        src = ./.;
      };
    });

    packages = forAllSystems (pkgs: let
      python-script = name: path:
        pkgs.writers.writePython3Bin name {} (builtins.readFile path);
    in {
    });
  };
}

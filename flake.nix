{
  description = "NostraDavid's Nix configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-vex = {
      url = "github:datosh/nixos-vex/6c6bbba6d30cf474dcf102d555ed8f8957b14c39";
      flake = false;
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    karabiner-rules = {
      url = "github:pqrs-org/KE-complex_modifications";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    asd-ste100-skill = {
      url = "github:danyuchn/asd-ste100-skill";
      flake = false;
    };
    awesome-copilot-skills = {
      url = "github:github/awesome-copilot";
      flake = false;
    };
    databricks-agent-skills = {
      url = "github:databricks/databricks-agent-skills";
      flake = false;
    };
    matt-pocock-skills = {
      url = "github:mattpocock/skills/v1.3.1";
      flake = false;
    };
    polars-skills = {
      url = "github:polars-inc/skills/v0.3.1";
      flake = false;
    };
    ponytail-skills = {
      url = "github:DietrichGebert/ponytail/v5.3.2";
      flake = false;
    };
    pstack-skills = {
      url = "github:cursor/plugins";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    den.url = "github:denful/den/436350eea1cde7d059877ed04bbd5d35852e3097";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [./nix];
    };
}

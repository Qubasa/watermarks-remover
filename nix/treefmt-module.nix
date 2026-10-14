{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.watermarks-remover;
in
{
  options.programs.watermarks-remover = {
    enable = lib.mkEnableOption "stripping invisible-Unicode AI marks from text files";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalMD "watermarks-remover built against the treefmt `pkgs`";
      description = "watermarks-remover package that provides `wm-treefmt_clean`.";
    };

    includes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "*.md"
        "*.txt"
        "*.rst"
      ];
      description = ''
        Files to clean. Every match is cleaned as text, so only list prose
        files. Test fixtures that contain invisible characters on purpose
        belong in `excludes`.
      '';
    };

    excludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Files to leave untouched even when `includes` matches them.";
    };
  };

  config = lib.mkIf cfg.enable {
    settings.formatter.watermarks-remover = {
      command = lib.getExe' cfg.package "wm-treefmt_clean";
      inherit (cfg) includes excludes;
    };
  };
}

# Konsole 隐藏工具栏（tsln 原版 overlays/tweaks/konsole.nix）
# Konsole 未把 toolbar 可见性暴露成配置项（konsolerc/konsoleui.rc 均无对应键），上游改用启动参数：
# wrapProgram 加 --hide-toolbars（QCommandLineOption，见 konsole v26.04.3 src/Application.cpp）
# 仅 linux 生效：konsole 无 darwin 构建，darwin 机器不必过这一层 eval
_: final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  kdePackages = prev.kdePackages.overrideScope (
    _: kdePrev: {
      konsole = final.symlinkJoin {
        inherit (kdePrev.konsole) name meta;
        paths = [ kdePrev.konsole ];
        nativeBuildInputs = [ final.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/konsole" --add-flags --hide-toolbars
        '';
      };
    }
  );
}

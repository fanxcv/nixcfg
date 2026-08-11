# alacritty 终端配置（应用本体由 homebrew cask 安装）
# 字体与系统 Monaspace Nerd Font 对齐（hosts/_darwin_/i18n/fonts.nix）
{
  programs.alacritty = {
    enable = true;
    package = null;
    settings = {
      font = {
        normal = {
          family = "MonaspiceNe Nerd Font Mono";
        };
        size = 13;
      };
      window = {
        padding = {
          x = 8;
          y = 12;
        };
        dimensions = {
          columns = 100;
          lines = 30;
        };
        dynamic_title = true;
        option_as_alt = "Both";
        decorations_theme_variant = "Dark";
      };

      selection = {
        save_to_clipboard = true;
      };
      cursor = {
        style = {
          shape = "Beam";
          blinking = "Always";
        };
        unfocused_hollow = true;
      };
      mouse = {
        hide_when_typing = true;
      };
      keyboard = {
        bindings = [
          # Cmd+T 转发（避免 alacritty 吞掉新标签页快捷键）
          {
            mods = "Command";
            key = "T";
            action = "None";
          }
          # Cmd+←/→ 行首/行尾
          {
            mods = "Command";
            key = "Left";
            chars = "\\u001bOH";
          }
          {
            mods = "Command";
            key = "Right";
            chars = "\\u001bOF";
          }
          # Option+←/→ 按词移动
          {
            mods = "Option";
            key = "Left";
            chars = "\\u001bb";
          }
          {
            mods = "Option";
            key = "Right";
            chars = "\\u001bf";
          }
        ];
      };
    };
  };
}

# Remmina：禁止开机自启（包本体见 ../apps.nix）
# 机制：Remmina 开着托盘图标时会自建 ~/.config/autostart/remmina-applet.desktop（Hidden=false），
#   Exec=remmina -i 即开机驻留托盘。故按 XDG 规范声明同一路径置 Hidden=true。
# 不会被它覆盖：remmina_icon_create_autostart_file() 开头 g_file_test 见文件已存在即 return
#   （FreeRDP/Remmina src/remmina_icon.c）。托盘图标本身照常，只是开机不自动拉起。
# 想恢复自启：删本文件，或在 Remmina「首选项 → Applet」勾回"启动时驻留托盘"。
{
  xdg.configFile."autostart/remmina-applet.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Name=Remmina Applet
    Comment=Connect to remote desktops through the applet menu
    Icon=org.remmina.Remmina
    Exec=remmina -i
    Terminal=false
    Type=Application
    Hidden=true
    X-GNOME-Autostart-enabled=false
  '';
}

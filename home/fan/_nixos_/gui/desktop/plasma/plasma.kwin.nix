# KWin 窗口管理：4 虚拟桌面（2x2）+ 贴边吸附 + sidebar 任务切换器 + 空会话启动（tsln 同款）
{
  programs.plasma.configFile = {
    kwinrc = {
      Desktops = {
        Number = 4;
        Rows = 2;
      };
      TabBox = {
        LayoutName = "sidebar";
      };
      Windows = {
        RollOverDesktops = true;
        BorderSnapZone = 10;
        WindowSnapZone = 10;
      };
      Script-desktopchangeosd = {
        PopupHideDelay = 500;
      };
    };
    ksmserverrc = {
      General = {
        loginMode = "emptySession";
      };
    };
  };
}

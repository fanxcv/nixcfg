# macOS 登录窗口声明（system.defaults.loginwindow）
{
  system.defaults.loginwindow = {
    # 不允许访客账户登录
    GuestEnabled = false;
    # 禁止在用户名处输入 >console 进入控制台登录
    DisableConsoleAccess = true;

    # 登录窗口显示"重新启动/关机"按钮（含已登录时）
    RestartDisabled = false;
    RestartDisabledWhileLoggedIn = false;
    ShutDownDisabled = false;
    ShutDownDisabledWhileLoggedIn = false;
  };
}

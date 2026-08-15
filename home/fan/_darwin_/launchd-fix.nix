# HM 内置 setupLaunchAgents 修正（mkForce 覆盖官方实现，仅替换 readlink -m 为 GNU 绝对路径）
# 来源：home-manager modules/launchd/default.nix（2025-08 flake.lock 锁版）；升级 HM 后如再报
#   readlink illegal option，diff 官方源码核对同步（官方源码：nix store 的 *-source/modules/launchd/default.nix）
# 为什么修：官方代码裸调用 readlink -m（GNU 选项），darwin 激活环境解析到 BSD readlink 报错三连
#   （illegal option / usage / find 空参数——同源，readlink 失败 → newDir 空 → find -L "" 报错）。
#   HM 自身在 home-environment.nix 也用 ${pkgs.coreutils}/bin/readlink -m 绝对路径——这里同法修正，
#   不依赖 PATH 解析，100% 稳定。
# 功能完整性：bootout/install/bootstrap/清理逻辑与官方一致；launchd.agents 声明照常生效
#   （launchd.enable 保持默认 true，agent 文件生成由官方 extraBuilderCommands 负责，不受影响）。

{ pkgs, lib, config, ... }:
let
  # GNU readlink -m（等价 readlink -m：对不存在的路径也返回规范化结果）
  readlinkM = "${pkgs.coreutils}/bin/readlink -m";
  dstDir = lib.escapeShellArg "${config.home.homeDirectory}/Library/LaunchAgents";
in
{
  home.activation.setupLaunchAgents = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Disable errexit to ensure we process all agents even if some fail
    set +e

    # Stop an agent if it's running
    bootoutAgent() {
      local domain="$1"
      local agentName="$2"

      verboseEcho "Stopping agent '$domain/$agentName'..."
      local bootout_output
      bootout_output=$(run /bin/launchctl bootout --wait "$domain/$agentName" 2>&1) || {
        # Only show warning if it's not the common "No such process" error
        if [[ "$bootout_output" != *"No such process"* ]]; then
          warnEcho "Failed to stop agent '$domain/$agentName': $bootout_output"
        else
          verboseEcho "Agent '$domain/$agentName' was not running"
        fi
      }
    }

    installAndBootstrapAgent() {
      local srcPath="$1"
      local dstPath="$2"
      local domain="$3"
      local agentName="$4"

      verboseEcho "Installing agent file to $dstPath"
      # GNU install 绝对路径：激活环境 PATH 解析异常（GNU 工具解析到 BSD 版，同 readlink 谜）
      if ! run ${pkgs.coreutils}/bin/install -Dm444 -T "$srcPath" "$dstPath"; then
        errorEcho "Failed to install agent file for '$agentName'"
        return 1
      fi

      verboseEcho "Starting agent '$domain/$agentName'"
      local bootstrap_output
      bootstrap_output=$(run /bin/launchctl bootstrap "$domain" "$dstPath" 2>&1) || {
        local error_code=$?

        if [[ "$bootstrap_output" == *"Bootstrap failed: 5: Input/output error"* ]]; then
          errorEcho "Failed to start agent '$domain/$agentName' with I/O error (code 5)"
          errorEcho "This typically happens when the agent wasn't unloaded before attempting to bootstrap the new agent."
        else
          errorEcho "Failed to start agent '$domain/$agentName' with error: $bootstrap_output"
        fi

        return 1
      }

      verboseEcho "Successfully started agent '$domain/$agentName'"
      return 0
    }

    processAgent() {
      local srcPath="$1"
      local dstDir="$2"
      local domain="$3"

      local agentFile="''${srcPath##*/}"
      local agentName="''${agentFile%.plist}"
      local dstPath="$dstDir/$agentFile"

      # Skip if unchanged
      if cmp -s "$srcPath" "$dstPath"; then
        verboseEcho "Agent '$agentName' is already up-to-date"
        return 0
      fi

      verboseEcho "Processing agent '$agentName'"

      # Stop/Unload agent if it's already running
      if [[ -f "$dstPath" ]]; then
        bootoutAgent "$domain" "$agentName"
      fi

      installAndBootstrapAgent "$srcPath" "$dstPath" "$domain" "$agentName"
      # Note: We continue processing even if this agent fails
      return 0
    }

    removeAgent() {
      local srcPath="$1"
      local dstDir="$2"
      local newDir="$3"
      local domain="$4"

      local agentFile="''${srcPath##*/}"
      local agentName="''${agentFile%.plist}"
      local dstPath="$dstDir/$agentFile"

      if [[ -e "$newDir/$agentFile" ]]; then
        verboseEcho "Agent '$agentName' still exists in new generation, skipping cleanup"
        return 0
      fi

      if [[ ! -e "$dstPath" ]]; then
        verboseEcho "Agent file '$dstPath' already removed"
        return 0
      fi

      if ! cmp -s "$srcPath" "$dstPath"; then
        warnEcho "Skipping deletion of '$dstPath', since its contents have diverged"
        return 0
      fi

      # Stop and remove the agent
      bootoutAgent "$domain" "$agentName"

      verboseEcho "Removing agent file '$dstPath'"
      if run rm -f $VERBOSE_ARG "$dstPath"; then
        verboseEcho "Successfully removed agent file for '$agentName'"
      else
        warnEcho "Failed to remove agent file '$dstPath'"
      fi

      return 0
    }

    setupLaunchAgents() {
      local oldDir newDir dstDir domain

      newDir="$(${readlinkM} "$newGenPath/LaunchAgents")"
      dstDir=${dstDir}
      domain="gui/$UID"

      if [[ -n "''${oldGenPath:-}" ]]; then
        oldDir="$(${readlinkM} "$oldGenPath/LaunchAgents")"
        if [[ ! -d "$oldDir" ]]; then
          verboseEcho "No previous LaunchAgents directory found"
          oldDir=""
        fi
      else
        oldDir=""
      fi

      verboseEcho "Setting up LaunchAgents in $dstDir"
      [[ -d "$dstDir" ]] || run mkdir -p "$dstDir"

      verboseEcho "Processing new/updated LaunchAgents..."
      find -L "$newDir" -maxdepth 1 -name '*.plist' -type f | while read -r srcPath; do
        processAgent "$srcPath" "$dstDir" "$domain"
      done

      # Skip cleanup if there's no previous generation
      if [[ -z "$oldDir" || ! -d "$oldDir" ]]; then
        verboseEcho "LaunchAgents setup complete"
        return
      fi

      verboseEcho "Cleaning up removed LaunchAgents..."
      find -L "$oldDir" -maxdepth 1 -name '*.plist' -type f | while read -r srcPath; do
        removeAgent "$srcPath" "$dstDir" "$newDir" "$domain"
      done
    }

    setupLaunchAgents

    # Restore errexit
    set -e
  '');
}

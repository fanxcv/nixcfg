# Edge 扩展清单（唯一事实源）——home 层 edge.nix（数据备份）与系统层 edge-policy.nix（策略安装）共用
# store: edge=Edge 商店 / chrome=Chrome 商店（crxid API 实测归属）
{
  extensions = {
    aapbdbdomjkkjkaonfhkkikfgjllcleb = "chrome";  # Google 翻译
    bhghoamapcdpbohphigoooaddinpkbai = "chrome";  # 身份验证器（数据备份）
    dbheplacgeefjnhdacijldhfliehnhka = "chrome";  # 琉神转
    dlknjglebgomjjfaijjnebecgjbfjihk = "chrome";  # 超级拖拽
    eeagobfjdenkkddmbclomhiblgggliao = "edge";    # 暴力猴
    hihblcmlaaademjlakdpicchbjnnnkbo = "chrome";  # Proxy SwitchyOmega V3（数据备份）
    jbkfoedolllekgbhcbcoahefnbanhhlh = "edge";    # Bitwarden
    mpkodccbngfoacfalldjimigbofkhgjn = "chrome";  # Aria2 Explorer
    nmddeihindhodaigflchmkmechmjjjbc = "edge";    # QR码生成与识别
    odfafepnkmbhccpbejgmiehpchacaeak = "edge";    # uBlock Origin
  };
  # 数据备份扩展（Local Extension Settings/<id> → ~/.secrets/edge-ext/<id>.tar.age）
  backups = [ "bhghoamapcdpbohphigoooaddinpkbai" "hihblcmlaaademjlakdpicchbjnnnkbo" ];
}
# Test configuration consumed by module-eval-test.nix.
{
  services.synctube = {
    enable = true;
    openFirewall = true;
    enableYtDlp = true;
    port = 4300;
    settings = {
      channelName = "-=TestChannel=-";
      totalVideoLimit = 10;
    };
  };
}

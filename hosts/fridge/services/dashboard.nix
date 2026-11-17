{
  config,
  pkgs,
  root,
  ...
}:

let
  port = 8150;
  python = pkgs.python3.withPackages (ps: [ ps.polars ]);
  # the app, with style.css: the tailwind classes in index.html and libraries/web/theme.css
  app = pkgs.runCommand "dashboard" { nativeBuildInputs = [ pkgs.tailwindcss_4 ]; } ''
    cp ${root + "/apps/dashboard"}/{dashboard.py,index.html} .
    cp ${root + "/libraries/web/theme.css"} theme.css
    echo '@import "tailwindcss"; @import "./theme.css";' > input.css
    tailwindcss --input input.css --output style.css --minify
    install -Dm644 -t $out dashboard.py index.html style.css
  '';
in
{
  fridge.expose.dashboard = port;

  systemd.services.dashboard = {
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    path = [
      config.systemd.package
      config.hardware.nvidia.package.bin # nvidia-smi
    ];
    environment.PORT = toString port;
    serviceConfig = {
      ExecStart = "${python.interpreter} ${app}/dashboard.py";
      DynamicUser = true;
      SupplementaryGroups = [ "docker" ]; # container names from the docker socket
      StateDirectory = "dashboard"; # /var/lib/dashboard
      Restart = "always";
    };
  };
}

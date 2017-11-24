#!/usr/bin/env bats

@test "invoking install.sh without arguments." {
  run "./install.sh"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": require either --install or --remove" ]]
  [[ ${lines[1]} =~ "Try »" && "-h« or »" && "--help« to get further information." ]]
}

@test "invoking install.sh with '-h' and '--help'" {
  run "./install.sh" "-h"
  [ $status -eq 0 ]
  run "./install.sh" "--help"
  [ $status -eq 0 ]
  [[ ${lines[0]} =~ "Usage:" && "[-i|-r] {options}" ]]
  [[ ${lines[5]} =~ "OPTIONS:" ]]
  [[ ${lines[12]} == "Please report bugs to https://github.com/sedrubal/adaway-linux/issues" ]]
}

@test "invoking install.sh with '-v' and '--version'" {
  run "./install.sh" "-v"
  [ $status -eq 0 ]
  run "./install.sh" "--version"
  [ $status -eq 0 ]
  [[ ${lines[0]} =~ "Version:" ]]
}

@test "invoking install.sh with special '--yes' and 'y' parameter." {
  run "./install.sh" "--yes"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: --yes" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
    run "./install.sh" "-y"
    [ $status -eq 1 ]
    [[ ${lines[0]} =~ ": selected options: -y" ]]
    [[ ${lines[1]} =~ ": require either --install or --remove" ]]
}

@test "invoking install.sh with special '--no' and '-n' parameter." {
  run "./install.sh" "--no"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: --no" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
  run "./install.sh" "-n"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: -n" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
}

@test "invoking install.sh with special '--cronjob' and '-C' parameter." {
  run "./install.sh" "--cronjob"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: --cronjob" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
  run "./install.sh" "-C"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: -C" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
}

@test "invoking install.sh with special '--systemd' and '-S' parameter." {
  run "./install.sh" "--systemd"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: --systemd" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
  run "./install.sh" "-S"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: -S" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
}

@test "invoking install.sh with special '--no-scheduler' parameter." {
  run "./install.sh" "--no-scheduler"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: --no-scheduler" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
}

@test "invoking install.sh with special '--force' and '-f' parameter." {
  run "./install.sh" "--force"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: --force" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
  run "./install.sh" "-f"
  [ $status -eq 1 ]
  [[ ${lines[0]} =~ ": selected options: -f" ]]
  [[ ${lines[1]} =~ ": require either --install or --remove" ]]
}

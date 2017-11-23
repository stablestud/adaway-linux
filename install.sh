#!/bin/bash
###########################################################
# adaway-linux                                            #
# Remove ads system-wide in Linux                         #
###########################################################
# authors:      sedrubal, diy-electronics                 #
# version:      v4.0                                      #
# licence:      CC BY-SA 4.0                              #
# github:       https://github.com/sedrubal/adaway-linux  #
###########################################################

# settings
HOSTS_ORIG="/etc/.hosts.original"
VERSION="4.0"
SYSTEMD_DIR="/etc/systemd/system"
#

# Gets the location of the script
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
SRCLST="${SCRIPT_DIR}/hostssources.lst"

#set -x
set -o pipefail
set -o errtrace
trap 'error ${LINENO} $?' ERR EXIT  # Trap errors and runs error function.


function error() {
  ## To catch unpredicted errors and exits.
  echo ""
  echo "[!] Upps, something went wrong." 1>&2
  echo "${0}: line ${1}: exit ${2}"
  echo "${0} ${parameters}: failed"
  echo "[@] Please report bugs to:" 1>&2
  echo "[@] https://github.com/sedrubal/adaway-linux/issues" 1>&2
  trap '' EXIT
  exit 1
}


function root() {
  ## Checks for root.
  if [ "${UID}" != "0" ] ; then
    echo "[!] This script must be run as root." 1>&2
    trap '' EXIT # Unhook exit - exit 1 will now instantly terminates the script.
    exit 1
  fi
  return 0
}


function helpme() {
  ## Show help
  echo "Usage: ${0} [-i|-r] {options}"
  echo ""
  echo "  -i,  --install    install all things needed by adaway-linux (requires root)"
  echo "  -r,  --remove     remove all changes made by adaway-linux (requires root)"
  echo "  -v,  --version    show current version of this script"
  echo "  -h,  --help       show this help"
  echo ""
  echo "OPTIONS: (not required) (mostly used for unit test)"
  echo "    -y, --yes      answer all prompts with 'yes'"
  echo "    -n, --no       answer all prompts with 'no'"
  echo "    -S, --systemd  answer the scheduler prompt with 'systemd'             (use with '-i')"
  echo "    -C, --cronjob  answer the scheduler prompt with 'cronjob'             (use with '-i')"
  echo "    -f, --force    force the installation (bypasses backup of hosts file) (use with '-i')"
  echo ""
  echo "After the installation you may want to run the script 'adaway-linux.sh'"
  echo "Please report bugs to https://github.com/sedrubal/adaway-linux/issues"
  trap '' EXIT
  exit 0
}


function version() {
  ## Show version
  echo "Version: ${VERSION}"
  trap '' EXIT
  exit 0
}


function install() {
  echo "Welcome to the install-script for adaway-linux."
  echo "[!] Please run this only ONCE! Cancel, if you already modified /etc/hosts by adaway-linux.sh."
  if [ ! -n "${answer}" ] ; then
    read -r -p "[?] Proceed? [Y/n] " REPLY
  else
    REPLY="${answer}"
  fi
  case "${REPLY}" in
    [Yy][Ee][Ss] | [Yy] | "" ) # YES, Y, NULL
      # Check if script wasn't started with the -f option
      if [ "${force}" != "true" ] ; then
        # Backup /etc/hosts
        echo "[i] First I will backup the original /etc/hosts to ${HOSTS_ORIG}."
        # Check if /etc/.hosts.original already exist
        if [ -e "${HOSTS_ORIG}" ] ; then
          echo "[!] Backup of /etc/hosts already exist. To remove run: »${0} -u«" 1>&2
          trap '' EXIT
          exit 1
        fi
        cp /etc/hosts "${HOSTS_ORIG}"
        # Check if backup was succesfully
        if [ ! -e "${HOSTS_ORIG}" ] ; then
          echo "[!] Backup of /etc/hosts failed. Please backup this file manually and bypass this check by using the -f parameter." 1>&2
          exit 1
        fi
      else
        rm -f "${HOSTS_ORIG}" 1>/dev/null 2>&1 || :
      fi
      # Create default hostsources.lst
      echo "[i] Now I will create the default hostsources-file: ${SRCLST}."
      echo "[i] You can add urls by editing this file manually."
      printf "" > "${SRCLST}"
      echo "https://adaway.org/hosts.txt" >> "${SRCLST}"
      echo "https://hosts-file.net/ad_servers.txt" >> "${SRCLST}"
      echo "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" >> "${SRCLST}"
      echo "https://www.malwaredomainlist.com/hostslist/hosts.txt" >> "${SRCLST}"
      echo "[i] File created."

      # Add scheduler
      if [ ! -n "${scheduler}" ] ; then
        read -r -p "[?] Create a cronjob/systemd-service which updates /etc/hosts with new adservers once a week? [systemd/cronjob/N] " REPLY
      else
        REPLY=${scheduler}
      fi
      case "${REPLY}" in
        [Cc][Rr][Oo][Nn][Jj][Oo][Bb] | [Cr][Rr][Oo][Nn][Tt][Aa][Bb] | [Cc][Rr][Oo][Nn] | [Cc] ) # CRONJOB, CRONTAB, CRON, C
          cronjob "install"
          ;;
        [Ss][Yy][Ss][Tt][Ee][Mm][Dd] | [Ss][Yy][Ss] | [Ss] ) # SYSTEMD, SYS, S
          systemd "install"
          ;;
        * )
          echo "[i] No schedule created." 1>&2
          ;;
      esac
      echo "[i] Finished. To remove, please run »${0} -u«"
      trap '' EXIT
      exit 0
      ;;
    * )
      echo "[i] Installation cancelled." 1>&2
      trap '' EXIT
      exit 1
      ;;
  esac

}


function remove() {
  if [ ! -n "${answer}" ] ; then
    read -r -p "[?] Do you really want to uninstall adaway-linux and restore the original /etc/hosts? [Y/n] " REPLY
  else
    REPLY="${answer}"
  fi
  case "${REPLY}" in
    [Yy][Ee][Ss] | [Yy] | "" ) # YES, Y, NULL
      cronjob "remove"
      systemd "remove"
      # Checks if /etc/.hosts.orginal exist
      if [ ! -e "${HOSTS_ORIG}" ] ; then
        echo "[!] Backup of /etc/hosts does not exist. To install run: »${0} -i« or restore it manually." 1>&2
        trap '' EXIT
        exit 1
      else
        echo "[i] Restoring /etc/hosts"
        mv "${HOSTS_ORIG}" /etc/hosts || exit 1
      fi
      ;;
    * )
      echo "[i] Uninstallation cancelled." 1>&2
      trap '' EXIT
      exit 1
      ;;
  esac
  return 0
}


function cronjob() {
  case "${1}" in
    install )
      echo "[i] Creating cronjob..."
      line="1 12 */5 * * ${SCRIPT_DIR}/adaway-linux.sh"
      (crontab -u root -l; echo "${line}" ) | crontab -u root - || exit 1
      ;;
    remove )
      # Check if cronjob was installed
      if [[ $(sudo crontab -u root -l | grep 'adaway-linux.sh') ]] ; then
        echo "[i] Removing cronjob..."
        # Get cronjob but ignore the line with adaway-linux.sh and then reapplie cronjob
        crontab -u root -l | grep -v 'adaway-linux.sh' | crontab -u root - || :
      else
        echo "[i] No cronjob installed. Skipping..."
      fi
      ;;
    * )
      exit 1
      ;;
  esac
  return 0
}


function systemd() {

  case "${1}" in
    install )
      echo "[i] Creating systemd service..."

      # Create .service file:
      #
      # [Unit]
      # Description=Service to run adaway-linux weekly
      # Documentation=https://github.com/sedrubal/adaway-linux/
      # After=network.target
      #
      # [Service]
      # ExecStart=${SCRIPT_DIR}/adaway-linux.sh
      #
      printf "" > "${SYSTEMD_DIR}/adaway-linux.service" || exit 1
      echo "[Unit]" >> "${SYSTEMD_DIR}/adaway-linux.service"
      echo "Description=Service to run adaway-linux weekly" >> "${SYSTEMD_DIR}/adaway-linux.service"
      echo "Documentation=https://github.com/sedrubal/adaway-linux/" >> "${SYSTEMD_DIR}/adaway-linux.service"
      echo "After=network.target" >> "${SYSTEMD_DIR}/adaway-linux.service"
      echo "" >> "${SYSTEMD_DIR}/adaway-linux.service"
      echo "[Service]" >> "${SYSTEMD_DIR}/adaway-linux.service"
      echo "ExecStart=${SCRIPT_DIR}/adaway-linux.sh" >> "${SYSTEMD_DIR}/adaway-linux.service"

      # Create .timer file:
      #
      # [Unit]
      # Description=Timer that runs adaway-linux.service weekly
      # Documentation=https://github.com/sedrubal/adaway-linux/
      # After=network.target
      #
      # [Timer]
      # OnCalendar=weekly
      # Persistent=true
      # Unit=adaway-linux.service
      #
      # [Install]
      # WantedBy=timers.target
      #
      printf "" > "${SYSTEMD_DIR}/adaway-linux.timer" || exit 1
      echo "[Unit]" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "Description=Timer that runs adaway-linux.service weekly" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "Documentation=https://github.com/sedrubal/adaway-linux/" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "After=network.target" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "[Timer]" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "OnCalendar=weekly" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "Persistent=true" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "Unit=adaway-linux.service" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "[Install]" >> "${SYSTEMD_DIR}/adaway-linux.timer"
      echo "WantedBy=timers.target" >> "${SYSTEMD_DIR}/adaway-linux.timer"

      chmod u=rw,g=r,o=r "${SYSTEMD_DIR}/adaway-linux."*

      # Enable the schedule
      systemctl enable adaway-linux.timer && systemctl start adaway-linux.timer && echo "[i] Systemd service succesfully initialized." || return 1
      return 0
      ;;
    remove )
      # Check if systemd services are installed
      if [ -e "${SYSTEMD_DIR}/adaway-linux.timer" ] || [ -e "${SYSTEMD_DIR}/adaway-linux.service" ] ; then
        echo "[!] Removing systemd service..."
        # Unhooking the systemd service
        systemctl stop adaway-linux.timer && systemctl disable adaway-linux.timer || echo "[!] adaway-linux.timer is missing. Have you removed it?" 1>&2
        systemctl stop adaway-linux.service && systemctl disable adaway-linux.service || echo "[!] adaway-linux.service is missing. Have you removed it?" 1>&2
        rm "${SYSTEMD_DIR}/adaway-linux."*
      else
        echo "[i] No systemd service installed. Skipping..."
      fi
      ;;
    * )
      exit 1
  esac
  return 0
}

parameters="$@"
for I in "$@"; do
  case ${I} in
    -h | --help )
      helpme
      break
      ;;
    -v | --version )
      version
      break
      ;;
    -i | --install )
      action="install"
      ;;
    -r | --remove | -u | --uninstall )
      action="remove"
      ;;
    -f | --force )
      force='true'
      ;;
    -[Yy] | --[Yy][Ee][Ss] )
      answer="yes"
      ;;
    -[Nn] | [Nn][Oo] )
      answer="no"
      ;;
    -S | --systemd )
      scheduler="systemd"
      ;;
    -C | --cronjob )
      scheduler="cronjob"
      ;;
    --no-scheduler )
      scheduler="no-scheduler"
      ;;
    * )
      echo "${0}: unknown option ${I}" 1>&2
      echo "Run »${0} -h« or »${0} --help« to get further information."
      trap '' EXIT
      exit 1
      ;;
  esac
done

case ${action} in
  install )
    root
    install
    ;;
  remove )
    root
    remove
    ;;
  * )
    echo "${0}: require either --install or --remove"
    echo "Try »${0} -h« or »${0} --help« to get further information."
    trap '' EXIT
    exit 1
    ;;
esac

echo "[i] Finished."
trap '' EXIT
exit 0

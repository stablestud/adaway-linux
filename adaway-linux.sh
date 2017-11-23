#!/bin/bash
#############################################################
# adaway-linux                                              #
# Remove ads system-wide in Linux                           #
#############################################################
# authors:  sedrubal, diy-electronics                       #
# version:  v4.0                                            #
# licence:  CC BY-SA 4.0                                    #
# github:   https://github.com/sedrubal/adaway-linux        #
#############################################################

# Settings
HOSTSORIG="/etc/.hosts.original"
TMPDIR="/tmp/adaway-linux"
#

# Get the location of the script.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

#set -x
set -o pipefail
set -o errtrace
trap 'error ${LINENO} $?' ERR EXIT  # Trap errors and runs error function.


function error() {
  ## To catch unpredicted errors and exits.
  echo "${0}: line ${1}: exit ${2}"
  echo "[!] Upps, something went wrong." 1>&2
  echo "[@] Please report bugs to:" 1>&2
  echo "[@] https://github.com/sedrubal/adaway-linux/issues" 1>&2
  cleanup # Execute the cleanup function.
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


function cleanup() {
  ## Clean leftovers which are not required anymore.
  echo "[i] Cleaning up..."
  rm -rf "${TMPDIR}" 1>/dev/null 2>&1  # Remove the temporary folder.
  return 0
}


function helpme() {
  ## Show help
  echo "Welcome to adaway-linux, a small script to add domains hosting ads to the hosts file to block them."
  echo ""
  echo "[!] Please run ./install.sh before using this! It will backup your original /etc/hosts"
  echo ""
  echo "Usage:"
  echo "You have only to run this script to add the ad-domains to your hosts file or to update them."
  echo "Parameters:"
  echo "    -h    --help      show help"
  echo "    -s    --simulate  simulate, but don't replace /etc/hosts"
  echo ""
  trap '' EXIT
  exit 0
}


function simulate() {
  echo "[i] Skipping replacing /etc/hosts. You can see the hosts file here: ${TMPDIR}/hosts"
  return 0
}


function prepare() {
  ## Prepare folders etc.
  # Delete previous tmp folder.
  if [ -d "${TMPDIR}" ]; then
    cleanup
  fi
  # Create new tmp folder.
  echo "[i] Creating temporary directory ${TMPDIR}"
  mkdir -p "${TMPDIR}" || exit 1
  return 0
}


function fetch() {
  ## Download and save the hosts.
  # Add domains from hosts-server listed in hostssources.lst
  count=0; tcount=0; # Used to print out how many hosts beeen downloaded/total [3/4]
  while read -r src; do
    ((tcount+=1))
    if [[ "${src}" != "#"* ]] ; then
      echo "[i] Downloading and cleaning up ${src}"
      if type curl 2>/dev/null 1>&2; then # Checks whether curl is installed, if not switch to wget.
        DOWNLOAD_CMD=$(curl --progress-bar -L --connect-timeout 30 --fail --retry 1 "${src}" ) || echo "[!] curl failed @ ${src}" 1>&2
      else
        DOWNLOAD_CMD=$(wget "${src}" -nv --show-progress --read-timeout=30 --timeout=30 -t 1 -L -O - ) || echo "[!] wget failed @ ${src}" 1>&2
      fi
      echo "${DOWNLOAD_CMD}" \
        | sed 's/\r/\n/' \
        | sed 's/^\s\+//' \
        | sed 's/^127\.0\.0\.1/0.0.0.0/' \
        | grep '^0\.0\.0\.0' \
        | grep -v '\slocalhost\s*' \
        | sed 's/\s*\#.*//g' \
        | sed 's/\s\+/\t/g' \
        >> "${TMPDIR}/hosts.downloaded" && ((count+=1)) || :
        # Download and cleanup:
        # - replace \r\n to unix \n
        # - remove leading whitespaces.
        # - replace 127.0.0.1 with 0.0.0.0 (shorter, unspecified).
        # - use only host entries redirecting to 0.0.0.0 (no empty line, no comment lines, no dangerous redirects to other sites.
        # - remove additional localhost entries possibly picked up from sources.
        # - remove remaining comments.
        # - split all entries with one tab.
    else
      echo "[i] Skipping ${src}"
    fi
  done < "${SCRIPT_DIR}/hostssources.lst"

  # Checks if any hosts were downloaded.
  if [ ! -e "${TMPDIR}/hosts.downloaded" ] || [ ! -s "${TMPDIR}/hosts.downloaded" ]; then
    echo "[!] No data obtained [${count}/${tcount}]. Exiting..." 1>&2
    trap '' EXIT
    exit 1
  else
    echo "[i] Downloaded hosts [${count}/${tcount}]."
  fi
  return 0
}


function build() {
  ## Construct the hosts file.
  # Sort the hosts according to the alphabet. [a-z]
  uniq <(sort "${TMPDIR}/hosts.downloaded") > "${TMPDIR}/hosts.adservers" || exit 1

  # fist lines of /etc/hosts
  echo "[i] Adding original hosts file from ${HOSTSORIG}"

  # Write header information to tmp folder.
  (cat >> "${TMPDIR}/hosts.header" <<EOF
# [!] This file will be updated by the ad-block-script called adaway-linux.
# [!] If you want to edit /etc/hosts, please edit the original file in ${HOSTSORIG}.
# [!] Content from there will be added to the top of this file.

EOF
) || exit 1
  # Add content of original hosts file.
  cat "${HOSTSORIG}" >> "${TMPDIR}/hosts.header" || exit 1

  # Append heading to hosts file.
  (cat >> "${TMPDIR}/hosts.header" <<EOF

# Ad Servers: added with ${SCRIPT_DIR}/adaway-linux.sh

EOF
) || exit 1
  # Build the hosts file from header and downloaded hosts.
  cat "${TMPDIR}/hosts.header" "${TMPDIR}/hosts.adservers" > "${TMPDIR}/hosts" || exit 1
  return 0
}


function apply() {
  ## Apply the hosts file to the system.
  echo "[i] Moving new hosts file to /etc/hosts"
  mv "${TMPDIR}/hosts" /etc/hosts || exit 1
  return 0
}


case "${1}" in

  -h | --help )
    helpme
    ;;

  -s | --simulate | --dry-run )
    root
    prepare
    fetch
    build
    simulate
    ;;

  "" )
    root
    prepare
    fetch
    build
    apply
    cleanup
    ;;
  * )
    echo "${0}: unknown option ${1}" 1>&2
    echo "Run »${0} -h« or »${0} --help« to get further information."
    trap '' EXIT
    exit 1
    ;;
esac

echo "[i] Finished"
trap '' EXIT
exit 0

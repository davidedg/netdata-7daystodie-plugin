# shellcheck shell=bash
# no need for shebang - this file is loaded from charts.d.plugin
# SPDX-License-Identifier: GPL-3.0-or-later

# netdata
# real-time performance and health monitoring, done right!
# (C) 2016 Costa Tsaousis <costa@tsaousis.gr>
#

# if this chart is called X.chart.sh, then all functions and global variables
# must start with X_

# _update_every is a special variable - it holds the number of seconds
# between the calls of the _update() function
sdtd_update_every=120

# the priority is used to sort the charts on the dashboard
# 1 = the first chart
sdtd_priority=1

# global variables to store our collected data
# remember: they need to start with the module name sdtd_

declare -A sdtd_servers=(
  ["localhost"]="127.0.0.1:26900"
)

sdtd_getgamedigjson() {
  run -t 1 gamedig --type protocol-valve "$1"
}

# _check is called once, to find out if this chart should be enabled or not
sdtd_check() {
  require_cmd gamedig || return 1
  require_cmd jq || return 1

  local host json maxplayers working=0 failed=0
  for host in "${!sdtd_servers[@]}"; do
    json=$(sdtd_getgamedigjson "${sdtd_servers[${host}]}")
    maxplayers=$(echo "${json}" | jq -re '.maxplayers')
    if [[ $? -ne 0 ]]; then
      error "Error getting data for ${host}"
      failed=$((failed + 1))
    elif [[ "${maxplayers}" == "null" ]]; then
      error "7DTD server ${host} seems offline"
      failed=$((failed + 1))
    else
      working=$((working + 1))
    fi
  done

  if [ ${working} -eq 0 ]; then
    error "No 7DTD servers available"
    return 1
  fi

  return 0
}


# _create is called once, to create the charts
sdtd_create() {
  local host src
  for host in "${!sdtd_servers[@]}"; do
    src=${sdtd_servers[${host}]}
    cat << EOF
CHART sdtd_${host}.players '' "7 Days To Die Players for ${host} on ${src}" "Players" Players sdtd.players line $((sdtd_priority + 1)) $sdtd_update_every
DIMENSION currplayers CurrPlayers absolute
DIMENSION maxplayers MaxPlayers absolute
EOF
  done
  return 0
}


# _update is called continuously, to collect the values
sdtd_update() {
  # the first argument to this function is the microseconds since last update
  # pass this parameter to the BEGIN statement (see bellow).

  local host json currplayers maxplayers working=0 failed=0
  for host in "${!sdtd_servers[@]}"; do
    json=$(sdtd_getgamedigjson "${sdtd_servers[${host}]}")
    maxplayers=$(echo "${json}" | jq -re '.maxplayers')
    if [[ $? -ne 0 ]]; then
      error "Error getting data for ${host}"
      failed=$((failed + 1))
    elif [[ "${maxplayers}" == "null" ]]; then
      error "7DTD server ${host} seems offline"
      failed=$((failed + 1))
    else
      currplayers=$(echo "${json}" | jq -re '.players | length')
      if [[ "${curplayers}" == "[]" ]] || [[ "${curplayers}" == "-1" ]]; then
        currplayers=0
      fi
      if [[ "${maxplayers}" == "[]" ]]; then
        maxplayers=0
      fi
      working=$((working + 1))
    fi

  cat << VALUESEOF
BEGIN sdtd_${host}.players $1
SET currplayers = ${currplayers}
SET maxplayers = ${maxplayers}
END
VALUESEOF

  done

  [[ $working -eq 0 ]] && error "Failed to get stats from all 7DTD servers" && return 1

  return 0
}
  

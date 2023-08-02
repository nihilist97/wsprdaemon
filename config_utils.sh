#!/bin/bash

### Config file exists, now validate it.    

### Validation requires that we have a list of valid BANDs

### These are the band frequencies taken from wsprnet.org
# ----------Band----------Dial Frequency----------TX Frequency center(+range)--------------
#          2190m--------------0.136000---------------0.137500 (+- 100Hz)
#           630m--------------0.474200---------------0.475700 (+- 100Hz)
#           160m--------------1.836600---------------1.838100 (+- 100Hz)
#            80m--------------3.568600---------------3.570100 (+- 100Hz) (this is the default frequency in WSJT-X v1.8.0 to be within the Japanese allocation.)
#            80m--------------3.592600---------------3.594100 (+- 100Hz) (No TX allowed for Japan; http://www.jarl.org/English/6_Band_Plan/JapaneseAmateurBandplans20150105...)
#            60m--------------5.287200---------------5.288700 (+- 100Hz) (please check local band plan if you're allowed to operate on this frequency!)
#            60m--------------5.364700---------------5.366200 (+- 100Hz) (valid for 60m band in Germany or other EU countries, check local band plan prior TX!)
#            40m--------------7.038600---------------7.040100 (+- 100Hz)
#            30m-------------10.138700--------------10.140200 (+- 100Hz)
#            22m-------------13.553900--------------13.554500 (+- 100Hz)
#            20m-------------14.095600--------------14.097100 (+- 100Hz)
#            17m-------------18.104600--------------18.106100 (+- 100Hz)
#            15m-------------21.094600--------------21.096100 (+- 100Hz)
#            12m-------------24.924600--------------24.926100 (+- 100Hz)
#            10m-------------28.124600--------------28.126100 (+- 100Hz)
#             6m-------------50.293000--------------50.294500 (+- 100Hz)
#             4m-------------70.091000--------------70.092500 (+- 100Hz)
#             2m------------144.489000-------------144.490500 (+- 100Hz)
#           70cm------------432.300000-------------432.301500 (+- 100Hz)
#           23cm-----------1296.500000------------1296.501500 (+- 100Hz)

### These are the 'dial frequency' in kHz.  The actual wspr tx frequencies are these values + 1400 to 1600 Hz
### The format of each entry is "BAND  TUNING_FREQUENCY DEFAULT_DECODE_MODES" where DEFAULT_DECODE_MODES is a colon-separated list of mode W (legacy WSPR) or F (FST4W) + packet length in minutes. 
###       e.g. "W2" == classic WSPR decode by the wsprd of a 2 minute long wav file

declare VALID_MODE_LIST=( W0 W2 F2 F5 F15 F30 )

declare WSPR_BAND_LIST=(
"2200     136.0   W2"
"630      474.2   W2"
"160     1836.6   W2"
"80      3568.6   W2"
"80eu    3592.6   W2"
"60      5287.2   W2"
"60eu    5364.7   W2"
"40      7038.6   W2"
"30     10138.7   W2"
"22     13553.9   W2"
"20     14095.6   W2"
"17     18104.6   W2"
"15     21094.6   W2"
"12     24924.6   W2"
"10     28124.6   W2"
"8      40680.0   W2"
"6      50293.0   W2"
"4      70091.0   W2"
"2     144489.0   W2"
"1     432300.0   W2"
"0    1296500.0   W2"
"WWVB      58.5   W0"
"WWV_2_5 2498.5   W0"
"WWV_5   4998.5   W0"
"WWV_10  9998.5   W0"
"WWV_15 14998.5   W0"
"WWV_20 19998.5   W0"
"WWV_25 24998.5   W0"
"CHU_3   3328.5   W0"
"CHU_7   7848.5   W0"
"CHU_14 14668.5   W0"
)

### Get the current value of a variable stored in the wsprdaemon.conf file without perturbing any currently defined .conf file variables in the calling function
function get_config_file_variable()
{
    local __return_varaiable=$1
    local _variable_name=$2

    local conf_file_value=$( shopt -u -o nounset; source ~/wsprdaemon/wsprdaemon.conf; eval echo \${${_variable_name}} )

    echo "${_variable_name} = ${conf_file_value}"
    eval ${__return_varaiable}=\${conf_file_value}
}


function is_valid_mode_list() {
    local test_mode_entry=$1
    local test_mode_entry_list=( ${test_mode_entry//:/ } )

    wd_logger 2 "Starting validation of '${test_mode_entry}'"
    if [[ ${#test_mode_entry_list[@]} -gt 1 && " ${test_mode_entry_list[@]} " =~ " W0 " ]] ; then
        wd_logger 1 "ERROR: mode 'W0' cannot be mixed with other modes"
        return 1
    fi
    for mode_entry in ${test_mode_entry_list[@]} ; do
        if ! [[ " ${VALID_MODE_LIST[@]} " =~ " ${mode_entry} " ]]; then
            wd_logger 1 "Error: ${mode_entry} is not a member of '${VALID_MODE_LIST[*]}'"
            return 1
        fi
    done
    wd_logger 2 "All modes in '${test_mode_entry}' are valid"
    return 0
 }

function get_default_modes_for_band() {
    local return_var_name=$1
    local search_for_band=$2
    
    wd_logger 2 "Got args ${return_var_name} ${search_for_band}"

    local band_entry
    for band_entry in "${WSPR_BAND_LIST[@]}"; do
        local band_entry_list=( ${band_entry} )
        local entry_band=${band_entry_list[0]}

        wd_logger 2 "Checking for band ${search_for_band} in '${band_entry_list[*]}'"
        if [[ ${band_entry_list} == ${search_for_band} ]]; then
            local local_default_modes=${band_entry_list[2]}

            wd_logger 2 "Returning default modes for band ${search_for_band} => ${local_default_modes}"
            eval ${return_var_name}=${local_default_modes}
            return 0
        fi
    done
    wd_logger 1 "Failed to find entry for band ${search_for_band}"
    return 1
}

function get_wspr_band_name_from_freq_hz() {
    local band_freq_hz=$1
    local band_freq_khz=$(bc <<< "scale = 1; ${band_freq_hz} / 1000")

    local i
    for i in $( seq 0 $(( ${#WSPR_BAND_LIST[*]} - 1)) ) ; do
        local band_info=(${WSPR_BAND_LIST[i]})
        local this_band=${band_info[0]}
        local this_freq_khz=${band_info[1]}
        if [[ ${band_freq_khz} == ${this_freq_khz} ]]; then
            echo ${this_band}
            return
        fi
    done
    [[ ${verbosity} -ge 1 ]] && echo "$(date): get_wspr_band_name_from_freq_hz() ERROR, can't find band for band_freq_hz = '${band_freq_hz}'" 1>&2
    echo ${band_freq_hz}
}


function get_wspr_band_freq(){
    local target_band=$1

    local i
    for i in $( seq 0 $(( ${#WSPR_BAND_LIST[*]} - 1)) ) ; do
        local band_info=(${WSPR_BAND_LIST[i]})
        local this_band=${band_info[0]}
        local this_freq_khz=${band_info[1]}
        if [[ ${target_band} == ${this_band} ]]; then
            echo ${this_freq_khz} 
            return
        fi
    done
}

### Validation requires that we have a list of valid RECEIVERs
###
function get_receiver_list_index_from_name() {
    local new_receiver_name=$1
    local i
    for i in $(seq 0 $(( ${#RECEIVER_LIST[*]} - 1 )) ) ; do
        local receiver_info=(${RECEIVER_LIST[i]})
        local receiver_name=${receiver_info[0]}
        local receiver_ip_address=${receiver_info[1]}

        if [[ ${receiver_name} == ${new_receiver_name} ]]; then
            echo ${i}
            return 0
        fi
    done
}

function get_receiver_ip_from_name() {
    local receiver_name=$1
    local receiver_info=( ${RECEIVER_LIST[$(get_receiver_list_index_from_name ${receiver_name})]} )
    echo ${receiver_info[1]}
}

function get_receiver_call_from_name() {
    local receiver_name=$1
    local receiver_info=( ${RECEIVER_LIST[$(get_receiver_list_index_from_name ${receiver_name})]} )
    echo ${receiver_info[2]}
}

function get_receiver_grid_from_name() {
    local receiver_name=$1
    local receiver_info=( ${RECEIVER_LIST[$(get_receiver_list_index_from_name ${receiver_name})]} )
    echo ${receiver_info[3]}
}

function get_receiver_password_from_name() {
    local receiver_name=$1
    local receiver_info=( ${RECEIVER_LIST[$(get_receiver_list_index_from_name ${receiver_name})]} )
    echo ${receiver_info[4]}
}

function get_receiver_af_list_from_name() {
    local receiver_name=$1
    local receiver_info=( ${RECEIVER_LIST[$(get_receiver_list_index_from_name ${receiver_name})]} )
    echo ${receiver_info[5]-}
}

function get_receiver_khz_offset_list_from_name() {
    local receiver_name=$1
    local receiver_info=( ${RECEIVER_LIST[$(get_receiver_list_index_from_name ${receiver_name})]} )
    local khz_offset=0
    local khz_info=${receiver_info[6]-}
    if [[ -n "${khz_info}" ]]; then
        khz_offset=${khz_info##*:}
    fi
    echo ${khz_offset}
}

### Validation requires we check the time specified for each job
####  Input is HH:MM or {sunrise,sunset}{+,-}HH:MM
declare -r SUNTIMES_FILE=${WSPRDAEMON_ROOT_DIR}/suntimes  ### cache sunrise HH:MM and sunset HH:MM for Receiver's Maidenhead grid
declare -r MAX_SUNTIMES_FILE_AGE_SECS=86400               ### refresh that cache file once a day

###   Adds or subtracts two: HH:MM  +/- HH:MM
function time_math() {
    local -i index_hr=$((10#${1%:*}))        ### Force all HH MM to be decimal number with no leading zeros
    local -i index_min=$((10#${1#*:}))
    local    math_operation=$2               ### I expect only '+' or '-'
    local -i offset_hr=$((10#${3%:*}))
    local -i offset_min=$((10#${3#*:}))

    local -i result_hr=$(($index_hr $2 $offset_hr))
    local -i result_min=$((index_min $2 $offset_min))

    if [[ $result_min -ge 60 ]]; then
        (( result_min -= 60 ))
        (( result_hr++ ))
    fi
    if [[ $result_min -lt 0 ]]; then
        (( result_min += 60 ))
        (( result_hr-- ))
    fi
    if [[ $result_hr -ge 24 ]]; then
        (( result_hr -= 24 ))
    fi
    if [[ $result_hr -lt 0 ]]; then
        (( result_hr += 24 ))
    fi
    printf "%02.0f:%02.0f\n"  ${result_hr} $result_min
}

######### This block of code supports scheduling changes based upon local sunrise and/or sunset ############
declare A_IN_ASCII=65              ### Decimal value of 'A'
declare ZERO_IN_ASCII=48           ### Decimal value of '0'

function alpha_to_integer() { 
    echo $(( $( printf "%d" "'$1" ) - $A_IN_ASCII )) 
}

function digit_to_integer() { 
    echo $(( $( printf "%d" "'$1" ) - $ZERO_IN_ASCII )) 
}

### This returns the approximate lat/long of a Maidenhead 4 or 6 character locator
### Primarily useful in getting sunrise and sunset time
function maidenhead_to_long_lat() {
    printf "%s %s\n" \
        $((  $(( $(alpha_to_integer ${1:0:1}) * 20 )) + $(( $(digit_to_integer ${1:2:1}) * 2)) - 180))\
        $((  $(( $(alpha_to_integer ${1:1:1}) * 10 )) + $(digit_to_integer ${1:3:1}) - 90))
}

declare ASTRAL2_2_SUN_TIMES_SCRIPT=${WSPRDAEMON_ROOT_DIR}/suntimes_astral2-2.py
function get_astral_sun_times() 
{
    local _return_times_var=$1
    local lat=$2
    local lon=$3
    local zone=$4

    if ! python3 -c "import astral" 2> /dev/null ; then
        if ! sudo pip3 install astral; then
            wd_logger 1 "ERROR: failed 'sudo pip3 install astral' needed for suntimes calculations"
            exit 1
        fi
    fi
    python3 -c "from astral import LocationInfo" 2> /dev/null 
    local rc=$?
    if [[ ${rc} -ne 0 ]]; then
        wd_logger 1 "python3 -c 'from astral import LocationInfo' => ${rc}.  So try to upgrade to astral2.2"
        pip3 install --upgrade astral > /dev/null
        rc=$?
        if [[ ${rc} -ne 0 ]]; then
            wd_logger 1 "ERROR: 'pip3 install --upgrade astral' => ${rc}"
            exit 1
        fi
        python3 -c "from astral import LocationInfo" 2> /dev/null
        rc=$?
        if [[ ${rc} -ne 0 ]]; then
            wd_logger 1 "ERROR: even after pip3 upgrade, 'python3 -c 'from astral import LocationInfo' => ${rc}"
            exit 1
        fi
        wd_logger 1 "Successfully installed and tested 'astral' library"
    fi

    python3 ${ASTRAL2_2_SUN_TIMES_SCRIPT} ${lat} ${lon} ${zone} > suntimes.txt 2> /dev/null
    rc=$?
    if [[ ${rc} -ne 0 ]]; then
        wd_logger 1 "ERROR: 'python3 ${ASTRAL2_2_SUN_TIMES_SCRIPT} ${lat} ${lon} ${zone}' => ${rc}"
        exit 1
    fi
    local _astral_sun_times=$(< suntimes.txt)
    eval ${_return_times_var}=\"\${_astral_sun_times}\"
    wd_logger 1 "Got suntimes='${_astral_sun_times}' and assigned it to _return_times_var=${_return_times_var}"
    return 0
}

function get_sunrise_sunset() 
{
    local _return_sunrise_hm=$1
    local maiden
    if [[ -n "${FORCE_MAIDENHEAD-}" ]]; then
        maiden="${FORCE_MAIDENHEAD}"
    else
        maiden=$2
    fi
    local long_lat=( $(maidenhead_to_long_lat $maiden) )

    wd_logger 1 "Get sunrise/sunset for Maidenhead ${maiden} at long/lat  ${long_lat[*]}"

    local long=${long_lat[0]}
    local lat=${long_lat[1]}
    local zone=$(timedatectl | awk '/Time/{print $3}')
    if [[ "${zone}" == "n/a" ]]; then
        wd_logger 1 "Couldn't determine the time zone from 'timedatectl', so do sunrise/sunet calculations assuming this server is configured for zone 'UTC'"
        zone="UTC"
    fi
    local astral_times=""
    get_astral_sun_times astral_times  ${lat} ${long} ${zone}
    local rc=$?
    if [[ ${rc} -ne 0 ]]; then
        wd_logger 1 "ERROR: 'get_astral_sun_times astral_times  ${lat} ${long} ${zone}' => ${rc}"
        exit 1
    fi
    eval ${_return_sunrise_hm}=\"\${astral_times}\"
    wd_logger 1 "'get_astral_sun_times astral_times  ${lat} ${long} ${zone}' => 0.  astral_times=${astral_times}"
    return 0
}

### Once per day, cache the sunrise/sunset times for the grids of all receivers
function update_suntimes_file() 
{
    if [[ -f ${SUNTIMES_FILE} ]] \
        && [[ $( $GET_FILE_MOD_TIME_CMD ${SUNTIMES_FILE} ) -gt $( $GET_FILE_MOD_TIME_CMD ${WSPRDAEMON_CONFIG_FILE} ) ]] \
        && [[ $(( $(date +"%s") - $( $GET_FILE_MOD_TIME_CMD ${SUNTIMES_FILE} ))) -lt ${MAX_SUNTIMES_FILE_AGE_SECS} ]] ; then
        ## Only update once a day
        wd_logger 2 "Skipping update"
        return 0
    fi
    rm -f ${SUNTIMES_FILE}
    source ${WSPRDAEMON_CONFIG_FILE}
    local maidenhead_list=$( ( IFS=$'\n' ; echo "${RECEIVER_LIST[*]}") | awk '{print $4}' | sort | uniq)
    for grid in ${maidenhead_list} ; do
        local suntimes=""
        get_sunrise_sunset  suntimes ${grid}
        local rc=$?
        if [[ ${rc} -ne 0 ]]; then
            wd_logger 1 "ERROR: 'get_sunrise_sunset  suntimes ${grid}' => ${rc}"
            return ${rc}
        fi
        echo "${grid} ${suntimes}" >> ${SUNTIMES_FILE}
        wd_logger 1 "Added line '${grid} ${suntimes}' to '${SUNTIMES_FILE}'"
    done
    wd_logger 1 "Refreshed '${SUNTIMES_FILE}'"
    return 0
}

function get_index_time() 
{
    local _return_hh_mm=$1
    local time_field=$2
    local receiver_grid=$3

    local hour
    local minute
    local hh_mm

    if [[ ${time_field} =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        ### This is a properly formatted HH:MM time spec
        hour=${time_field%:*}
        minute=${time_field#*:}
        hh_mm="${hour}:${minute}"
        eval ${_return_hh_mm}=\"\${hh_mm}\"
        wd_logger 2 "time_field=${time_field} contains valid HH:MM value ${hh_mm} and returned it to  _return_hh_mm=${_return_hh_mm}"
        return 0
    fi
    if [[ ! ${time_field} =~ sunrise|sunset ]]; then
        wd_logger 1 "ERROR: time specification '${time_field}' is not valid"
        return 1
    fi

    update_suntimes_file
    ## Sunrise or sunset has been specified. Uses Receiver's name to find it's Maidenhead and from there lat/long leads to sunrise and sunset
   if [[ ${time_field} =~ sunrise ]] ; then
        index_time=$(awk "/${receiver_grid}/{print \$2}" ${SUNTIMES_FILE} )
    else  ## == sunset
        index_time=$(awk "/${receiver_grid}/{print \$3}" ${SUNTIMES_FILE} )
    fi
    local offset="00:00"
    local sign="+"
    if [[ ${time_field} =~ \+ ]] ; then
        offset=${time_field#*+}
    elif [[ ${time_field} =~ \- ]] ; then
        offset=${time_field#*-}
        sign="-"
    fi
    local offset_time=$(time_math $index_time $sign $offset)
    if [[ ! ${offset_time} =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        wd_logger 1 "ERROR: failed to translate the sunrise/sunset+offset value ${time_field} to a valid offset_time ${offset_time}"
        return 3
    fi
    eval ${_return_hh_mm}=\"\${offset_time}\"
    wd_logger 2 "Translated a valid sunrise/sunset+offset value ${time_field} to ${offset_time} and returned it to  _return_hh_mm=${_return_hh_mm}"
    return 0
}


### Validate the schedule
###
declare POSTING_DIR_MAX_SPACE=1000
declare RECORDING_DIR_WAV_FILE_SPACE_PER_MINUTE=1500

function validate_configured_schedule()
{
    local found_error="no"
    local sched_line

    if [[ -z "${WSPR_SCHEDULE[@]-}" ]]; then
        wd_logger 1  "ERROR: WSPR_SCHEDULE[] is not defined in the conf file"
        exit 1
    fi
    if [[ ${#WSPR_SCHEDULE[@]} -lt 1 ]]; then
        wd_logger 1  "ERROR: WSPR_SCHEDULE[] is defined in the conf file but has no schedule entries"
        exit 2
    fi
    wd_logger 2 "Starting"
    local max_tmp_file_space=0
    for sched_line in "${WSPR_SCHEDULE[@]}" ; do
        wd_logger 2 "Checking line ${sched_line}"
        local sched_tmp_file_space=0

        local sched_line_list=( ${sched_line} )
        if [[ ${#sched_line_list[@]} -lt 2 ]]; then
            wd_logger 1  "ERROR: WSPR_SCHEDULE[@] line '${sched_line}' does not have the required minimum 2 fields. Remember that each schedule entry must have the form \"HH:MM RECEIVER,BAND[,MODES]... \""
            exit 1
        fi
        local job_time=${sched_line_list[0]}
        wd_logger 2 "Job for time '${job_time}' has at least one RX:BAND specifications"
        ### NOTE: all of the receivers must be in the same time zone.
        local job
        for job in ${sched_line_list[@]:1}; do
            wd_logger 2 "Testing job $job"

            local -a job_elements=(${job//,/ })
            local    job_elements_count=${#job_elements[@]}
            if [[ $job_elements_count -lt 2 ]]; then
                wd_logger 1  "ERROR: in WSPR_SCHEDULE line '${sched_line[@]}', job '${job}' doesn't have the form 'RECEIVER,BAND'"
                exit 1
            fi
            local job_rx=${job_elements[0]}
            local rx_index
            rx_index=$(get_receiver_list_index_from_name ${job_rx})
            if [[ -z "${rx_index}" ]]; then
                wd_logger 1  "ERROR: in WSPR_SCHEDULE line '${sched_line[*]}', job '${job}' specifies receiver '${job_rx}' not found in RECEIVER_LIST"
               found_error="yes"
            fi
            local job_band=${job_elements[1]}
            band_freq=$(get_wspr_band_freq ${job_band})
            if [[ -z "${band_freq}" ]]; then
                wd_logger 1  "ERROR: in WSPR_SCHEDULE line '${sched_line[*]}', job '${job}' specifies band '${job_band}' not found in WSPR_BAND_LIST"
               found_error="yes"
            fi
            local job_modes=${job_elements[2]-W2}
            is_valid_mode_list ${job_modes}
            local rc=$?
            if [[ ${rc} -ne 0 ]]; then
                wd_logger 1  "ERROR: in WSPR_SCHEDULE line '${sched_line[*]}', job '${job}' specifies invalid mode(s)"
                found_error="yes"
            fi
            local job_grid="$(get_receiver_grid_from_name ${job_rx})"
            local job_time_resolved=""
            get_index_time job_time_resolved ${job_time} ${job_grid}
            local ret_code=$?
            if [[ ${ret_code} -ne 0 ]]; then
                wd_logger 1  "ERROR: in WSPR_SCHEDULE line '${sched_line[*]}', time specification '${job_time}' is not valid"
                exit 1
            fi
            wd_logger 2 "Found valid job '${job}' == job_time_resolved=${job_time_resolved}"

            ### Calculate the maximum /tmp/wsprdaemon disk space in KBytes which could be used by this job

            ### For each job in this schedule there will be only one posting directory which occupies at most about 1000 KBytes
            ### There will be one recording dir for each simple job, but N recording jobs for MERGed receivers and each of those will occupy at most ((MAX_MODE_MINUTES * 1500 Kbytes) * 2) + 1500
            local job_field_list=( ${job//,/ } )
            if [[ ${#job_field_list[@]} -eq 2 ]]; then
                job_field_list[2]="W2"
            fi
            local job_mode_list=( ${job_field_list[2]//:/ } )
            local job_max_mode_minutes=$( IFS=$'\n'; echo "${job_mode_list[*]/?/}" | sort -nu | tail -n 1 )

            wd_logger 2 "Found job '${job}' with a max time length mode of ${job_max_mode_minutes} minutes"

            local job_rx_name=${job_field_list[0]}
            local job_rx_name_list=()
            if [[ ${job_rx_name} =~ ^MERG ]] ; then
                local merged_receiver_address=$(get_receiver_ip_from_name ${job_rx_name})   ### In a MERGed rx, the real rxs feeding it are in a comma-separated list in the IP column
                job_rx_name_list=( ${merged_receiver_address//,/ } )
            else
                job_rx_name_list[0]=${job_rx_name}
            fi
            local posting_dir_max_space=${POSTING_DIR_MAX_SPACE}
            local recording_dir_one_minute_wav_file_max_space=$(( ${RECORDING_DIR_WAV_FILE_SPACE_PER_MINUTE} * ${job_max_mode_minutes} ))
            local recording_dir_longest_minute_wav_copy_file_max_space=${recording_dir_one_minute_wav_file_max_space}
            local recording_dir_log_files_file_max_space=1000
            local recording_dir_total_max_space=$(( ${recording_dir_one_minute_wav_file_max_space} + ${recording_dir_longest_minute_wav_copy_file_max_space} + ${recording_dir_log_files_file_max_space} ))
            local all_recording_dirs_total_max_space=$(( ${#job_rx_name_list[@]} * ${recording_dir_total_max_space} ))
            local job_max_disk_space=$(( ${posting_dir_max_space} + ${all_recording_dirs_total_max_space} ))
            sched_tmp_file_space=$(( ${sched_tmp_file_space} + ${job_max_disk_space} ))
            wd_logger 2 "$(printf "'${job}' requires there be 1 posting daemon directory and ${#job_rx_name_list[@]} recording directories.  Alltogether they will consume at most %'d KB, so sched_tmp_file_space=%'d KB\n" ${job_max_disk_space} ${sched_tmp_file_space})"
        done
        if [[ ${sched_tmp_file_space} -gt ${max_tmp_file_space} ]]; then
            max_tmp_file_space=${sched_tmp_file_space}
        fi
    done

    local tmp_filesystem_size=$(df ${WSPRDAEMON_TMP_DIR} | awk '/tmpfs/{print $2}')
    if [[ ${max_tmp_file_space} -ge ${tmp_filesystem_size} ]]; then
        wd_logger 1 "$( printf "ERROR: the schedule in the conf file will require a /tmp/wsprdaemon file system with %'d KBytes of space, but /tmp/wsprdaemon is configured in /etc/fstab for only %'d KBytes of space. Either increase its size in /etc/fstab or change the schedule" \
            ${max_tmp_file_space} ${tmp_filesystem_size} ) "
        read -p "Increase the size of '/tmp/wsprdaemon' in '/etc/fstab' before trying to run this confguration.  Press <ENTER> to continue with WD installation and validation => "
    else
        wd_logger 2 "$( printf "The schedule in the conf file will require a /tmp/wsprdaemon file system with %'d KBytes of space and /tmp/wsprdaemon is configured in /etc/fstab for %'d KBytes which is enough space" \
            ${max_tmp_file_space} ${tmp_filesystem_size} ) "
    fi
    if [[ ${found_error} == "yes" ]]; then
        return 1
    fi
    return 0
}

###
function validate_configuration_file()
{
    if [[ ! -f ${WSPRDAEMON_CONFIG_FILE} ]]; then
        echo "ERROR: configuration file '${WSPRDAEMON_CONFIG_FILE}' does not exist"
        exit 1
    fi
    source ${WSPRDAEMON_CONFIG_FILE}

    if [[ -n "${SPOT_FREQ_ADJ_HZ-}" ]]; then
        local absolute_value_freq_adj=${SPOT_FREQ_ADJ_HZ#-}       ### Strip off a leading '-'
        absolute_value_freq_adj=${absolute_value_freq_adj#+}      ### Strip off a leading '+"
        if [[ "${absolute_value_freq_adj:0:1}" == "." ]]; then
            ### The regex in the test below needs that there be a digit before a '.' in the number
            absolute_value_freq_adj="0${absolute_value_freq_adj}"
            wd_logger 2 "Prepend a missing '0' to the SPOT_FREQ_ADJ_HZ value ${SPOT_FREQ_ADJ_HZ} to create the test value ${absolute_value_freq_adj}"
        fi

        if ! [[ ${absolute_value_freq_adj} =~ ^[+-]?[0-9]+([.][0-9]+)?$  ]] ; then
            wd_logger 1 "ERROR: the value '${SPOT_FREQ_ADJ_HZ}' of SPOT_FREQ_ADJ_HZ which has been defined in the conf file is not a valid integer or float"
            exit 1
        fi
        local spot_freq_adj_max_hz=${SPOT_FREQ_ADJ_MAX_HZ-20}    ### By default, limit spot frequency adjustments to +/- 20 Hz
        if [[ ${absolute_value_freq_adj%.*} -gt ${spot_freq_adj_max_hz} ]]; then
            wd_logger 1 "ERROR: the value '${SPOT_FREQ_ADJ_HZ}' of SPOT_FREQ_ADJ_HZ defined in the conf file is greater than the max supported value of +/-${spot_freq_adj_max_hz}"
            exit 1
        fi
    fi

    if [[ -z "${RECEIVER_LIST[@]-}" ]]; then
        echo "ERROR: configuration file '${WSPRDAEMON_CONFIG_FILE}' does not contain a definition of the RECEIVER_LIST[*] array or that array is empty"
        exit 1
    fi
    local max_index=$(( ${#RECEIVER_LIST[@]} - 1 ))
    if [[ ${max_index} -lt 0 ]]; then
        echo "ERROR: configuration file '${WSPRDAEMON_CONFIG_FILE}' defines RECEIVER_LIST[*] but it contains no receiver definitions"
        exit 1
    fi
    ### Create a list of receivers and validate all are specifired to be in the same grid.  More validation could be added later
    local rx_name=""
    local rx_grid=""
    local first_rx_grid=""
    local rx_line
    local -a rx_line_info_fields=()
    local -a rx_name_list=("")
    local index
    for index in $(seq 0 ${max_index}); do
        rx_line_info_fields=(${RECEIVER_LIST[${index}]})
        if [[ ${#rx_line_info_fields[@]} -lt 5 ]]; then
            echo "ERROR: configuration file '${WSPRDAEMON_CONFIG_FILE}' contains 'RECEIVER_LIST[] configuration line '${rx_line_info_fields[@]}' which has fewer than the required 5 fields"
            exit 1
        fi
        rx_name=${rx_line_info_fields[0]}
        rx_grid=${rx_line_info_fields[3]} 
        if [[ -z "${first_rx_grid}" ]]; then
            first_rx_grid=${rx_grid}
        fi
        if [[ $verbosity -gt 1 ]] && [[ "${rx_grid}" != "${first_rx_grid}" ]]; then
            echo "INFO: configuration file '${WSPRDAEMON_CONFIG_FILE}' contains 'RECEIVER_LIST[] configuration line '${rx_line_info_fields[@]}'"
            echo "       that specifies grid '${rx_grid}' which differs from the grid '${first_rx_grid}' of the first receiver"
        fi
        ### Validate file name, i.i don't allow ',' characters in the name
        if [[ ${rx_name} =~ , ]]; then
            echo "ERROR: the receiver '${rx_name}' defined in wsprdaemon.conf contains the invalid character ','"
            exit 1
        fi
        rx_name_list+=( ${rx_name} )
        ### More testing of validity of the fields on this line could be done
    done

    if [[ -z "${WSPR_SCHEDULE[@]-}" ]]; then
        echo "ERROR: configuration file '${WSPRDAEMON_CONFIG_FILE}' exists, but does not contain a definition of the WSPR_SCHEDULE[*] array, or that array is empty"
        exit 1
    fi
    local max_index=$(( ${#WSPR_SCHEDULE[@]} - 1 ))
    if [[ ${max_index} -lt 0 ]]; then
        echo "ERROR: configuration file '${WSPRDAEMON_CONFIG_FILE}' declares WSPR_SCHEDULE[@], but it contains no schedule definitions"
        exit 1
    fi
    validate_configured_schedule

    if [[ "${WSPR_SCHEDULE[@]}" =~ KA9Q ]]; then
        wd_logger 2 "One or more WSPR_SCHEDULE jobs specify a KA9Q_* receive channel. So check that KA9Q-radio is installed an running"
        if ! ka9q_setup ; then
            wd_logger 1 "ERROR: couldn't setup the KA9Q-radio service required by an entry in the WD.conf WSPR_SCHEDULE"
            exit 1
        fi
        wd_logger 2 "The KA9Q-radio service required by an entry in the WD.conf WSPR_SCHEDULE is running"
    fi
    return 0
}

declare KA9Q_GIT_URL="https://github.com/ka9q/ka9q-radio.git"
declare KA9Q_RADIOD_SERVICE_BASE='radiod@*'                ### used in calling systemctl
declare WD_CONF_BASE_NAME="rx888-wsprdaemon"

declare KA9Q_WSPRDAEMON_CONF_FILE="radiod@${WD_CONF_BASE_NAME}.conf"
declare KA9Q_WSPRDAEMON_CONF_TEMPLATE_FILE="radiod@${WD_CONF_BASE_NAME}-template.conf"


declare WD_KA9Q_CONF_FILE="${WSPRDAEMON_ROOT_DIR}/${KA9Q_WSPRDAEMON_CONF_FILE}"                      ### Can be cutomized by the user
declare WD_KA9Q_CONF_TEMPLATE_FILE="${WSPRDAEMON_ROOT_DIR}/${KA9Q_WSPRDAEMON_CONF_TEMPLATE_FILE}"    ### A template with defautls for KA9Q RX-888 installatons

declare KA9Q_RADIOD_CONF_DIR="/etc/radio"
declare KA9Q_RADIOD_WD_CONF_FILE=${KA9Q_RADIOD_CONF_DIR}/${KA9Q_WSPRDAEMON_CONF_FILE}                ### radiod looks in /etc/radio/... for conf files


### These are the libraries needed by KA9Q, but it is too hard to extract them from the Makefile, so I just copied them here
declare KA9Q_PACKAGE_DEPENDANCIES="build-essential libusb-1.0-0-dev libusb-dev libncurses5-dev libfftw3-dev libbsd-dev libhackrf-dev \
             libopus-dev libairspy-dev libairspyhf-dev librtlsdr-dev libiniparser-dev libavahi-client-dev portaudio19-dev libopus-dev"

declare KA9Q_RADIO_ROOT_DIR="${WSPRDAEMON_ROOT_DIR}/ka9q-radio"
declare KA9Q_RADIO_NWSIDOM="${KA9Q_RADIO_ROOT_DIR}/nwisdom"     ### This is created by running fft_wisdom during the KA9Q installation
declare FFTW_DIR="/etc/fftw"                                    ### This is the directory where radiod looks for a wisdomf
declare FFTW_WISDOMF="${FFTW_DIR}/wisdomf"                      ### This the wisdom file it looks for


function ka9q_setup()
{
    local rc

    sudo systemctl is-active "${KA9Q_RADIOD_SERVICE_BASE}" > /dev/null
    rc=$?
    if [[ ${rc} -eq 0 ]]; then
        wd_logger 2 "A KA9Q receiver service is active, so nothing more to do to setup KA9Q-radio"
        return 0
    fi
    if [[ "${KA9Q_RUNS_AS_PEER-no}" == "yes" ]]; then
        wd_logger 1 "ERROR: in wsprdaemon.conf KA9Q_RUNS_AS_PEER=yes is defined in wsprdaemon.conf, but no ${KA9Q_RADIOD_SERVICE_BASE}' is running"
        exit 1
    fi
    wd_logger 1 "KA9Q receiver service is not active"
    if ! lsusb | grep -q "Cypress Semiconductor Corp" ; then
        wd_logger 1 "Can't find a RX888 MkII attached to a USB port"
        exit
    fi
    wd_logger 1 "Found a RX888 MkII attached to a USB port"
 
    if [[ ! -d "${KA9Q_RADIO_ROOT_DIR}" ]]; then
        ### Download, compile and install the KA9Q_radio  service
        cd ${WSPRDAEMON_ROOT_DIR}
        git clone "${KA9Q_GIT_URL}"
        rc=$?
        if [[ ${rc} -ne 0 ]]; then
            wd_logger 1 "ERROR: failed to 'git clone ${KA9Q_GIT_URL}"
            return 1
        fi
        sudo apt install -y ${KA9Q_PACKAGE_DEPENDANCIES}
        cd ${KA9Q_RADIO_ROOT_DIR}
        if [[ ! -f Makefile ]]; then
            ln -s Makefile.linux Makefile
            wd_logger 1 "Found no Makefile, so 'ln -s Makefile.linux Makefile'"
        fi
        make
        rc=$?
        if [[ ${rc} -ne 0 ]]; then
            cd - > /dev/null
            wd_logger 1 "ERROR: failed to 'make'"
            return 2
        fi
        sudo make install
        rc=$?
        if [[ ${rc} -ne 0 ]]; then
            cd - > /dev/null
            wd_logger 1 "ERROR: failed to 'sudo make install'"
            return 2
        fi
    fi
    wd_logger 1 "KA9Q SW is installed"

    if [[ -f  ${KA9Q_RADIO_NWSIDOM} ]]; then
        wd_logger 1 "Found ${KA9Q_RADIO_NWSIDOM}, so no need to create it"
    else
        wd_logger 1 "Didn't find ${KA9Q_RADIO_NWSIDOM}, so need to create it.  This may take minutes or even hours..."
        cd ${KA9Q_RADIO_ROOT_DIR}
        time fftwf-wisdom -v -T 1 -o nwisdom rof500000 cof36480 cob1920 cob1200 cob960 cob800 cob600 cob480 cob320 cob300 cob200 cob160
        rc=$?
        cd - > /dev/null
        if [[ ${rc} -ne 0 ]]; then
            wd_logger 1 "ERROR: failed to 'time fftwf-wisdom -v -T 1 -o nwisdom rof500000...'"
            return 3
        fi
        if [[ ! -f ${KA9Q_RADIO_NWSIDOM} ]]; then
            wd_logger 1 "ERROR: can't find expected '${KA9Q_RADIO_NWSIDOM}'"
            return 3
        fi
    fi
    wd_logger 1 "${KA9Q_RADIO_NWSIDOM} exists"

    if [[ ! -f ${FFTW_WISDOMF} || ${KA9Q_RADIO_NWSIDOM} -nt ${FFTW_WISDOMF} ]]; then
        if [[ -f ${FFTW_WISDOMF} ]]; then
            wd_logger 1 "Backing up the exisitng ${FFTW_WISDOMF} to ${FFTW_WISDOMF}.save before installing a new ${KA9Q_RADIO_NWSIDOM}"
            sudo cp -p ${FFTW_WISDOMF} ${FFTW_WISDOMF}.save
        fi
        wd_logger 1 "Copying ${KA9Q_RADIO_NWSIDOM} to ${FFTW_WISDOMF}"
        sudo cp -p ${KA9Q_RADIO_NWSIDOM} ${FFTW_WISDOMF}
        local dir_user_group=$(stat --printf "%U:%G" ${FFTW_DIR})
        sudo chown ${dir_user_group} ${FFTW_WISDOMF}
        wd_logger 1 "Changed ownership of ${FFTW_WISDOMF} to ${dir_user_group}"
    fi
     wd_logger 1 "${FFTW_WISDOMF} is current"

    if [[ ! -f ${WD_KA9Q_CONF_FILE}  ]]; then
        wd_logger 1 "'${WD_KA9Q_CONF_FILE}' is missing, so create it from the WD KA9Q template file '${WD_KA9Q_CONF_TEMPLATE_FILE}'"
        cp -p ${WD_KA9Q_CONF_TEMPLATE_FILE} ${WD_KA9Q_CONF_FILE}
    fi
    wd_logger 1 "Found WD's local radio conf file: '${WD_KA9Q_CONF_FILE}'"

    if [[ ! -f ${KA9Q_RADIOD_WD_CONF_FILE} || ${KA9Q_RADIOD_WD_CONF_FILE} -ot ${WD_KA9Q_CONF_FILE} ]]; then
        if [[ ! -f ${KA9Q_RADIOD_WD_CONF_FILE} ]]; then
            wd_logger 1 "'${KA9Q_RADIOD_WD_CONF_FILE}' is missing, so create it from '${WD_KA9Q_CONF_FILE}'"
        else
            wd_logger 1 "${KA9Q_RADIOD_WD_CONF_FILE}' is older than '${WD_KA9Q_CONF_FILE}', so update it"
        fi
        sudo cp -p ${WD_KA9Q_CONF_FILE} ${KA9Q_RADIOD_WD_CONF_FILE}
    fi
    wd_logger 1 "WD will be giving radiod the conf file '${KA9Q_RADIOD_WD_CONF_FILE}'"

    wd_logger 1 "Starting KA9Q 'radiod' service by executing: 'sudo systemctl start radiod@${WD_CONF_BASE_NAME}'"
    sudo systemctl start radiod@${WD_CONF_BASE_NAME}
    rc=$?
    if [[ ${rc} -ne 0 ]]; then
        wd_logger 1 "ERROR: 'sudo systemctl start radiod@${WD_CONF_BASE_NAME}' => ${rc}"
        return ${rc}
    fi
    
    wd_logger 1 "A KA9Q receiver is specified in the WD .conf file and now it should be installed and active"
    return 0
}


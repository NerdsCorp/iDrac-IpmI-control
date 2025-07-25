#!/bin/bash
#
# Enhanced Dell iDRAC Fan Control Script for Docker Container
# Provides fine-grained temperature-based fan control for Dell PowerEdge servers
# Optimized for keeping servers cool while minimizing fan noise
#
# Environment Variables (set these in your Docker container):
# IDRAC_HOST - iDRAC IP address
# IDRAC_USER - iDRAC username  
# IDRAC_PASS - iDRAC password
# LOG_LEVEL - debug, info, warn, error (default: info)
# CHECK_INTERVAL - seconds between checks (default: 30)
# TEMP_SENSOR - temperature sensor to monitor (default: 04h for Inlet)
# MAX_TEMP_THRESHOLD - emergency threshold for dynamic control (default: 40)
# HYSTERESIS - temperature hysteresis to prevent oscillation (default: 2)

# Configuration with defaults
IDRAC_HOST=${IDRAC_HOST:-""}
IDRAC_USER=${IDRAC_USER:-""}
IDRAC_PASS=${IDRAC_PASS:-""}
LOG_LEVEL=${LOG_LEVEL:-"info"}
CHECK_INTERVAL=${CHECK_INTERVAL:-30}
TEMP_SENSOR=${TEMP_SENSOR:-"04h"}  # Inlet Temp
MAX_TEMP_THRESHOLD=${MAX_TEMP_THRESHOLD:-40}
HYSTERESIS=${HYSTERESIS:-2}

# Fan speed mappings (hex values for ipmitool)
declare -A FAN_SPEEDS=(
    [0]="0x00"   # 0%
    [5]="0x05"   # 5%
    [10]="0x0a"  # 10%
    [15]="0x0f"  # 15%
    [18]="0x12"  # 18%
    [20]="0x14"  # 20%
    [22]="0x16"  # 22%
    [25]="0x19"  # 25%
    [28]="0x1c"  # 28%
    [30]="0x1e"  # 30%
    [35]="0x23"  # 35%
    [40]="0x28"  # 40%
    [45]="0x2d"  # 45%
    [50]="0x32"  # 50%
    [60]="0x3c"  # 60%
    [70]="0x46"  # 70%
    [80]="0x50"  # 80%
    [90]="0x5a"  # 90%
    [100]="0x64" # 100%
)

# Temperature thresholds and corresponding fan speeds
declare -A TEMP_FAN_MAP=(
    [0]=5      # 0-12°C -> 5% (very cool)
    [13]=10    # 13-15°C -> 10%
    [16]=15    # 16-18°C -> 15%
    [19]=18    # 19-20°C -> 18%
    [21]=20    # 21-22°C -> 20%
    [23]=22    # 23-24°C -> 22%
    [25]=25    # 25-26°C -> 25%
    [27]=28    # 27-28°C -> 28%
    [29]=30    # 29-30°C -> 30%
    [31]=35    # 31-32°C -> 35%
    [33]=40    # 33-34°C -> 40%
    [35]=45    # 35-36°C -> 45%
    [37]=50    # 37-38°C -> 50%
    [39]=60    # 39°C -> 60%
)

# Global variables
CURRENT_FAN_SPEED=""
MANUAL_MODE=false
LAST_TEMP=0

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $LOG_LEVEL in
        "debug") levels="debug info warn error" ;;
        "info")  levels="info warn error" ;;
        "warn")  levels="warn error" ;;
        "error") levels="error" ;;
    esac
    
    if [[ $levels == *"$level"* ]]; then
        echo "[$timestamp] [$level] $message"
    fi
}

# Check if required environment variables are set
check_config() {
    if [[ -z "$IDRAC_HOST" || -z "$IDRAC_USER" || -z "$IDRAC_PASS" ]]; then
        log error "Missing required environment variables: IDRAC_HOST, IDRAC_USER, IDRAC_PASS"
        exit 1
    fi
    
    # Test ipmitool connectivity
    if ! command -v ipmitool &> /dev/null; then
        log error "ipmitool command not found. Please install ipmitool package."
        exit 1
    fi
    
    log info "Configuration validated successfully"
    log debug "iDRAC Host: $IDRAC_HOST"
    log debug "Check interval: ${CHECK_INTERVAL}s"
    log debug "Temperature sensor: $TEMP_SENSOR"
    log debug "Max temperature threshold: ${MAX_TEMP_THRESHOLD}°C"
}

# Execute ipmitool command with error handling
execute_ipmi() {
    local cmd="$*"
    local result
    
    log debug "Executing: ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P *** $cmd"
    
    result=$(ipmitool -I lanplus -H "$IDRAC_HOST" -U "$IDRAC_USER" -P "$IDRAC_PASS" $cmd 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log error "ipmitool command failed: $result"
        return $exit_code
    fi
    
    echo "$result"
    return 0
}

# Get current temperature from iDRAC
get_temperature() {
    local temp_output
    local temp_value
    
    temp_output=$(execute_ipmi sdr type temperature | grep "$TEMP_SENSOR")
    if [[ $? -ne 0 ]]; then
        log error "Failed to get temperature reading"
        return 1
    fi
    
    temp_value=$(echo "$temp_output" | cut -d"|" -f5 | cut -d" " -f2)
    
    # Validate temperature is numeric
    if ! [[ "$temp_value" =~ ^[0-9]+$ ]]; then
        log error "Invalid temperature reading: $temp_value"
        return 1
    fi
    
    echo "$temp_value"
    return 0
}

# Enable/disable manual fan control
set_fan_control_mode() {
    local mode=$1  # "manual" or "dynamic"
    
    if [[ "$mode" == "manual" ]]; then
        if [[ "$MANUAL_MODE" == false ]]; then
            log info "Enabling manual fan control"
            execute_ipmi raw 0x30 0x30 0x01 0x00
            MANUAL_MODE=true
        fi
    else
        if [[ "$MANUAL_MODE" == true ]]; then
            log info "Enabling dynamic fan control"
            execute_ipmi raw 0x30 0x30 0x01 0x01
            MANUAL_MODE=false
        fi
    fi
}

# Set fan speed percentage
set_fan_speed() {
    local speed_percent=$1
    local hex_speed=${FAN_SPEEDS[$speed_percent]}
    
    if [[ -z "$hex_speed" ]]; then
        log error "Invalid fan speed: $speed_percent%"
        return 1
    fi
    
    if [[ "$CURRENT_FAN_SPEED" != "$speed_percent" ]]; then
        log info "Setting fan speed to $speed_percent% ($hex_speed)"
        execute_ipmi raw 0x30 0x30 0x02 0xff "$hex_speed"
        CURRENT_FAN_SPEED=$speed_percent
    else
        log debug "Fan speed already set to $speed_percent%"
    fi
}

# Determine optimal fan speed based on temperature
calculate_fan_speed() {
    local temp=$1
    local target_speed=5   # Default minimum speed (5%)
    
    # Find the appropriate fan speed based on temperature ranges
    for temp_threshold in $(printf '%s\n' "${!TEMP_FAN_MAP[@]}" | sort -n); do
        if [[ $temp -ge $temp_threshold ]]; then
            target_speed=${TEMP_FAN_MAP[$temp_threshold]}
        fi
    done
    
    # Apply hysteresis to prevent oscillation
    if [[ -n "$CURRENT_FAN_SPEED" && $temp -lt $((LAST_TEMP - HYSTERESIS)) ]]; then
        # Temperature dropped significantly, allow speed reduction
        log debug "Temperature dropped by more than ${HYSTERESIS}°C, allowing speed reduction"
    elif [[ -n "$CURRENT_FAN_SPEED" && $temp -le $((LAST_TEMP + HYSTERESIS)) && $target_speed -lt $CURRENT_FAN_SPEED ]]; then
        # Temperature is stable/slightly higher but target speed is lower, keep current speed
        target_speed=$CURRENT_FAN_SPEED
        log debug "Applying hysteresis: keeping current speed $CURRENT_FAN_SPEED%"
    fi
    
    echo "$target_speed"
}

# Get fan RPM readings for monitoring
get_fan_status() {
    local fan_status
    fan_status=$(execute_ipmi sensor reading "FAN 1 RPM" "FAN 2 RPM" "FAN 3 RPM" "FAN 4 RPM" 2>/dev/null | grep -E "FAN [0-9]+ RPM")
    
    if [[ -n "$fan_status" ]]; then
        log debug "Fan status: $fan_status"
        echo "$fan_status"
    fi
}

# Main monitoring loop
monitor_and_control() {
    log info "Starting fan control monitoring (interval: ${CHECK_INTERVAL}s)"
    
    while true; do
        # Get current temperature
        local current_temp
        current_temp=$(get_temperature)
        
        if [[ $? -ne 0 || -z "$current_temp" ]]; then
            log warn "Failed to read temperature, retrying in ${CHECK_INTERVAL}s"
            sleep "$CHECK_INTERVAL"
            continue
        fi
        
        log info "Current temperature: ${current_temp}°C"
        
        # Emergency check: if temperature is too high, enable dynamic control
        if [[ $current_temp -gt $MAX_TEMP_THRESHOLD ]]; then
            log warn "Temperature ${current_temp}°C exceeds threshold ${MAX_TEMP_THRESHOLD}°C"
            log warn "Enabling dynamic fan control for safety"
            set_fan_control_mode "dynamic"
            LAST_TEMP=$current_temp
            sleep "$CHECK_INTERVAL"
            continue
        fi
        
        # Normal operation: manual control
        set_fan_control_mode "manual"
        
        # Calculate and set optimal fan speed
        local target_speed
        target_speed=$(calculate_fan_speed "$current_temp")
        set_fan_speed "$target_speed"
        
        # Log fan status if in debug mode
        if [[ "$LOG_LEVEL" == "debug" ]]; then
            get_fan_status
        fi
        
        LAST_TEMP=$current_temp
        sleep "$CHECK_INTERVAL"
    done
}

# Signal handlers for graceful shutdown
cleanup() {
    log info "Received shutdown signal, restoring dynamic fan control"
    set_fan_control_mode "dynamic"
    log info "Fan control script terminated"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main execution
main() {
    log info "Dell iDRAC Fan Control Script Starting"
    log info "Log level: $LOG_LEVEL"
    
    check_config
    monitor_and_control
}

# Run main function
main "$@"

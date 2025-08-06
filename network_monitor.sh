#!/bin/bash

# Network Service Monitor and Management Script
# Monitors network services by resource usage and provides stopping capabilities
# Author: Auto-generated script
# Date: $(date)

echo "🌐 Network Service Monitor & Management"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get process details by PID
get_process_details() {
    local pid=$1
    local cmd=$(ps -p $pid -o comm= 2>/dev/null)
    local full_cmd=$(ps -p $pid -o args= 2>/dev/null)
    echo "$cmd|$full_cmd"
}

# Function to format bytes to human readable
bytes_to_human() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Function to check network connections and associated processes
check_network_services() {
    echo -e "${BLUE}🔍 Analyzing network services and their resource usage...${NC}"
    echo ""
    
    # Create temporary files for data processing
    local temp_netstat="/tmp/netstat_output.txt"
    local temp_processes="/tmp/process_usage.txt"
    
    # Get network connections with process information
    if command_exists ss; then
        echo -e "${YELLOW}📊 Active network connections (using ss):${NC}"
        ss -tulpn > "$temp_netstat"
    elif command_exists netstat; then
        echo -e "${YELLOW}📊 Active network connections (using netstat):${NC}"
        netstat -tulpn > "$temp_netstat"
    else
        echo -e "${RED}❌ Neither ss nor netstat found. Installing net-tools...${NC}"
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y net-tools
        elif command_exists yum; then
            sudo yum install -y net-tools
        else
            echo -e "${RED}❌ Could not install net-tools. Please install manually.${NC}"
            return 1
        fi
        netstat -tulpn > "$temp_netstat"
    fi
    
    # Extract PIDs from network connections and get their resource usage
    echo -e "${YELLOW}💾 Memory usage by network services:${NC}"
    printf "%-8s %-15s %-10s %-10s %-20s %s\n" "PID" "CPU%" "MEM%" "RSS(MB)" "COMMAND" "FULL_COMMAND"
    echo "$(printf '%.0s-' {1..100})"
    
    # Get unique PIDs from network connections
    local pids=$(grep -oE '[0-9]+/' "$temp_netstat" | cut -d'/' -f1 | sort -u | head -20)
    
    # Get resource usage for each PID and sort by memory usage
    > "$temp_processes"
    for pid in $pids; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            # Get process stats
            local ps_output=$(ps -p "$pid" -o pid,pcpu,pmem,rss,comm,args --no-headers 2>/dev/null)
            if [ -n "$ps_output" ]; then
                echo "$ps_output" >> "$temp_processes"
            fi
        fi
    done
    
    # Sort by RSS (memory) usage and display top consumers
    if [ -s "$temp_processes" ]; then
        sort -k4 -nr "$temp_processes" | head -15 | while read line; do
            local pid=$(echo "$line" | awk '{print $1}')
            local cpu=$(echo "$line" | awk '{print $2}')
            local mem=$(echo "$line" | awk '{print $3}')
            local rss=$(echo "$line" | awk '{print $4}')
            local comm=$(echo "$line" | awk '{print $5}')
            local full_cmd=$(echo "$line" | cut -d' ' -f6-)
            
            # Convert RSS from KB to MB
            local rss_mb=$(echo "scale=2; $rss/1024" | bc 2>/dev/null || echo "$rss")
            
            printf "%-8s %-15s %-10s %-10s %-20s %s\n" "$pid" "$cpu%" "$mem%" "${rss_mb}" "$comm" "$(echo "$full_cmd" | cut -c1-50)"
        done
    else
        echo "No network service processes found."
    fi
    
    # Clean up temp files
    rm -f "$temp_netstat" "$temp_processes"
}

# Function to show listening ports and services
show_listening_services() {
    echo ""
    echo -e "${BLUE}🎯 Services listening on ports:${NC}"
    echo ""
    
    if command_exists ss; then
        ss -tlnp | grep LISTEN | head -20
    else
        netstat -tlnp | grep LISTEN | head -20
    fi
}

# Function to show top memory consuming processes
show_top_memory_processes() {
    echo ""
    echo -e "${BLUE}🏆 Top 10 memory consuming processes (all processes):${NC}"
    echo ""
    ps aux --sort=-%mem | head -11
}

# Function to stop a service by PID
stop_service_by_pid() {
    local pid=$1
    if [ -z "$pid" ]; then
        echo -e "${RED}❌ No PID provided${NC}"
        return 1
    fi
    
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}❌ Process with PID $pid not found${NC}"
        return 1
    fi
    
    local process_info=$(ps -p "$pid" -o comm,args --no-headers 2>/dev/null)
    echo -e "${YELLOW}⚠️  About to stop process:${NC}"
    echo "PID: $pid"
    echo "Process: $process_info"
    echo ""
    
    read -p "Are you sure you want to stop this process? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🛑 Attempting graceful shutdown (SIGTERM)...${NC}"
        if kill "$pid" 2>/dev/null; then
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${YELLOW}🔨 Process still running, forcing shutdown (SIGKILL)...${NC}"
                kill -9 "$pid" 2>/dev/null
            fi
            echo -e "${GREEN}✅ Process stopped successfully${NC}"
        else
            echo -e "${RED}❌ Failed to stop process${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  Operation cancelled${NC}"
    fi
}

# Function to stop service by name pattern
stop_service_by_name() {
    local pattern=$1
    if [ -z "$pattern" ]; then
        echo -e "${RED}❌ No service name pattern provided${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔍 Searching for processes matching: $pattern${NC}"
    local pids=$(pgrep -f "$pattern")
    
    if [ -z "$pids" ]; then
        echo -e "${RED}❌ No processes found matching: $pattern${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📋 Found matching processes:${NC}"
    for pid in $pids; do
        local process_info=$(ps -p "$pid" -o pid,comm,args --no-headers 2>/dev/null)
        echo "$process_info"
    done
    
    echo ""
    read -p "Stop all matching processes? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for pid in $pids; do
            echo -e "${YELLOW}🛑 Stopping PID: $pid${NC}"
            kill "$pid" 2>/dev/null
        done
        sleep 2
        # Force kill any remaining
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${YELLOW}🔨 Force killing PID: $pid${NC}"
                kill -9 "$pid" 2>/dev/null
            fi
        done
        echo -e "${GREEN}✅ All matching processes stopped${NC}"
    else
        echo -e "${BLUE}ℹ️  Operation cancelled${NC}"
    fi
}

# Function to check Docker containers resource usage
check_docker_resources() {
    if ! command_exists docker; then
        echo -e "${YELLOW}ℹ️  Docker not found, skipping Docker analysis${NC}"
        return
    fi
    
    if ! docker info > /dev/null 2>&1; then
        echo -e "${YELLOW}ℹ️  Docker not running, skipping Docker analysis${NC}"
        return
    fi
    
    echo ""
    echo -e "${BLUE}🐳 Docker containers resource usage:${NC}"
    echo ""
    
    # Check if any containers are running
    local running_containers=$(docker ps -q)
    if [ -z "$running_containers" ]; then
        echo -e "${YELLOW}ℹ️  No running Docker containers${NC}"
        return
    fi
    
    # Show container stats
    echo "Container resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
}

# Main menu function
show_menu() {
    echo ""
    echo -e "${GREEN}📋 Available Actions:${NC}"
    echo "1. 🔍 Analyze network services resource usage"
    echo "2. 🎯 Show listening services"
    echo "3. 🏆 Show top memory consuming processes"
    echo "4. 🐳 Check Docker containers (if available)"
    echo "5. 🛑 Stop service by PID"
    echo "6. 🔍 Stop service by name pattern"
    echo "7. 🧹 Run full system cleanup"
    echo "8. 🔄 Refresh analysis"
    echo "9. ❌ Exit"
    echo ""
}

# Function for full system cleanup
full_system_cleanup() {
    echo -e "${YELLOW}🧹 Starting full system cleanup...${NC}"
    
    # Clean package cache
    if command_exists apt-get; then
        echo "Cleaning APT cache..."
        sudo apt-get clean
        sudo apt-get autoremove -y
    elif command_exists yum; then
        echo "Cleaning YUM cache..."
        sudo yum clean all
    fi
    
    # Clean temporary files
    echo "Cleaning temporary files..."
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # Docker cleanup if available
    if command_exists docker && docker info > /dev/null 2>&1; then
        echo "Cleaning Docker resources..."
        docker system prune -f
    fi
    
    echo -e "${GREEN}✅ System cleanup completed${NC}"
}

# Main script execution
main() {
    # Check if running as root for some operations
    if [ "$EUID" -ne 0 ] && [ "$1" != "--no-root-check" ]; then
        echo -e "${YELLOW}⚠️  Some operations may require sudo privileges${NC}"
        echo ""
    fi
    
    # Install bc if not available (for calculations)
    if ! command_exists bc; then
        echo -e "${YELLOW}📦 Installing bc for calculations...${NC}"
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y bc
        elif command_exists yum; then
            sudo yum install -y bc
        fi
    fi
    
    while true; do
        show_menu
        read -p "Enter your choice [1-9]: " choice
        
        case $choice in
            1)
                check_network_services
                ;;
            2)
                show_listening_services
                ;;
            3)
                show_top_memory_processes
                ;;
            4)
                check_docker_resources
                ;;
            5)
                echo ""
                read -p "Enter PID to stop: " pid
                stop_service_by_pid "$pid"
                ;;
            6)
                echo ""
                read -p "Enter service name pattern: " pattern
                stop_service_by_name "$pattern"
                ;;
            7)
                full_system_cleanup
                ;;
            8)
                echo -e "${BLUE}🔄 Refreshing analysis...${NC}"
                check_network_services
                ;;
            9)
                echo -e "${GREEN}👋 Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1-9.${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..." -r
    done
}

# Run the main function
main "$@"

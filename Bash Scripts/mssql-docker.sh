#!/bin/bash
# SQL Server Docker Management Script
# Usage: ./mssql-docker.sh [start|stop|status|restart|backup|restore]

# Configuration - Change these as needed
CONTAINER_NAME="mssql-server"
SA_PASSWORD=""  # Will be set via parameter or config file
PORT=1433
BASE_DIR="$HOME/sqlserver"  # Base directory for SQL Server files, can be overridden with --dir parameter

# Volume configuration
DATA_VOLUME="mssql-data"         # Docker volume for data files
LOG_VOLUME="mssql-logs"          # Docker volume for log files
BACKUP_VOLUME="mssql-backups"    # Docker volume for backup files

# Host directory mounts (will be set based on BASE_DIR)
HOST_DATA_DIR=""      # Will be set based on BASE_DIR
HOST_LOG_DIR=""       # Will be set based on BASE_DIR
HOST_BACKUP_DIR=""    # Will be set based on BASE_DIR

# Use volume mounts instead of Docker volumes?
USE_VOLUME_MOUNTS=true

# Container directories (don't change these)
CONTAINER_DATA_DIR="/var/opt/mssql/data"
CONTAINER_LOG_DIR="/var/opt/mssql/log"
CONTAINER_BACKUP_DIR="/var/opt/mssql/backup"

CONFIG_FILE="$HOME/.mssql-docker.conf"  # Config file for storing password

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if Docker is running
check_docker() {
    if ! systemctl is-active --quiet docker; then
        echo -e "${RED}Docker is not running. Starting Docker...${NC}"
        sudo systemctl start docker
        sleep 2
    fi
}

# Function to check if container exists
container_exists() {
    sudo docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
    return $?
}

# Function to check if container is running
container_running() {
    sudo docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
    return $?
}

# Function to get password
get_password() {
    # First check if password was provided as parameter
    if [ -n "$SA_PASSWORD" ]; then
        return 0
    fi
    
    # Then check if password is stored in config file
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        if [ -n "$SA_PASSWORD" ]; then
            return 0
        fi
    fi
    
    # If not found, prompt user for password
    read -sp "Enter SA password: " SA_PASSWORD
    echo ""
    
    if [ -z "$SA_PASSWORD" ]; then
        echo -e "${RED}Error: Password cannot be empty${NC}"
        exit 1
    fi
    
    # Ask if user wants to save password
    read -p "Save password to config file? (y/n): " SAVE_PASSWORD
    if [[ "$SAVE_PASSWORD" =~ ^[Yy] ]]; then
        echo "SA_PASSWORD=\"$SA_PASSWORD\"" > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo -e "${GREEN}Password saved to $CONFIG_FILE${NC}"
    fi
}

# Set up directory paths based on BASE_DIR
setup_directories() {
    # Create full paths based on BASE_DIR
    HOST_DATA_DIR="$BASE_DIR/data"
    HOST_LOG_DIR="$BASE_DIR/logs"
    HOST_BACKUP_DIR="$BASE_DIR/backups"
    
    echo -e "${BLUE}Using directories:${NC}"
    echo -e "  Data: $HOST_DATA_DIR"
    echo -e "  Logs: $HOST_LOG_DIR"
    echo -e "  Backups: $HOST_BACKUP_DIR"
}

# Function to create container if it doesn't exist
create_container() {
    echo -e "${BLUE}Creating SQL Server container...${NC}"
    
    # Make sure we have a password
    get_password
    
    # Set up directory paths
    setup_directories
    
    # Prepare volume mounts or Docker volumes based on configuration
    if [ "$USE_VOLUME_MOUNTS" = true ]; then
        echo -e "${BLUE}Using host directory mounts for SQL Server files${NC}"
        
        # Create host directories if they don't exist
        sudo mkdir -p $HOST_DATA_DIR
        sudo mkdir -p $HOST_LOG_DIR
        sudo mkdir -p $HOST_BACKUP_DIR
        
        # Set proper permissions
        sudo chmod -R 755 $HOST_DATA_DIR $HOST_LOG_DIR $HOST_BACKUP_DIR
        
        # Define volume mappings
        VOLUME_ARGS="-v $HOST_DATA_DIR:$CONTAINER_DATA_DIR \
                     -v $HOST_LOG_DIR:$CONTAINER_LOG_DIR \
                     -v $HOST_BACKUP_DIR:$CONTAINER_BACKUP_DIR"
    else
        echo -e "${BLUE}Using Docker volumes for SQL Server files${NC}"
        
        # Create Docker volumes if they don't exist
        sudo docker volume inspect $DATA_VOLUME >/dev/null 2>&1 || sudo docker volume create $DATA_VOLUME
        sudo docker volume inspect $LOG_VOLUME >/dev/null 2>&1 || sudo docker volume create $LOG_VOLUME
        sudo docker volume inspect $BACKUP_VOLUME >/dev/null 2>&1 || sudo docker volume create $BACKUP_VOLUME
        
        # Define volume mappings
        VOLUME_ARGS="-v $DATA_VOLUME:$CONTAINER_DATA_DIR \
                     -v $LOG_VOLUME:$CONTAINER_LOG_DIR \
                     -v $BACKUP_VOLUME:$CONTAINER_BACKUP_DIR"
    fi
    
    # Run the container with appropriate resource limits and volume configuration
    echo -e "${BLUE}Starting SQL Server container with 16GB memory and 4 CPUs${NC}"
    sudo docker run -e "ACCEPT_EULA=Y" \
        -e "MSSQL_SA_PASSWORD=$SA_PASSWORD" \
        -e "MSSQL_PID=Developer" \
        -p $PORT:1433 \
        $VOLUME_ARGS \
        --name $CONTAINER_NAME \
        --memory=16g \
        --cpus=4 \
        -d mcr.microsoft.com/mssql/server:2022-latest
    
    # Configure default directories using mssql-conf after container is running
    echo -e "${BLUE}Configuring default directories...${NC}"
    sleep 5  # Allow container to initialize
    sudo docker exec -it $CONTAINER_NAME /opt/mssql/bin/mssql-conf set filelocation.defaultdatadir $CONTAINER_DATA_DIR
    sudo docker exec -it $CONTAINER_NAME /opt/mssql/bin/mssql-conf set filelocation.defaultlogdir $CONTAINER_LOG_DIR
    sudo docker exec -it $CONTAINER_NAME /opt/mssql/bin/mssql-conf set filelocation.defaultbackupdir $CONTAINER_BACKUP_DIR
    
    # Restart SQL Server inside container to apply settings
    sudo docker exec -it $CONTAINER_NAME systemctl restart mssql-server
    
    echo -e "${GREEN}SQL Server container created and started.${NC}"
    echo -e "${YELLOW}Wait a moment for SQL Server to initialize...${NC}"
    sleep 10
}

# Start SQL Server
start_sqlserver() {
    check_docker
    
    if container_exists; then
        if container_running; then
            echo -e "${YELLOW}SQL Server is already running.${NC}"
        else
            echo -e "${BLUE}Starting SQL Server container...${NC}"
            sudo docker start $CONTAINER_NAME
            echo -e "${GREEN}SQL Server started successfully.${NC}"
        fi
    else
        create_container
    fi
    
    # Display connection info
    echo ""
    echo -e "${GREEN}SQL Server is running on localhost:$PORT${NC}"
    echo -e "${GREEN}Connect with: sqlcmd -S localhost,$PORT -U SA -P '$SA_PASSWORD'${NC}"
    echo -e "${GREEN}Or use SQL Server Management Studio/Azure Data Studio${NC}"
}

# Stop SQL Server
stop_sqlserver() {
    if container_running; then
        echo -e "${BLUE}Stopping SQL Server container...${NC}"
        sudo docker stop $CONTAINER_NAME
        echo -e "${GREEN}SQL Server stopped.${NC}"
    else
        echo -e "${YELLOW}SQL Server is not running.${NC}"
    fi
}

# Restart SQL Server
restart_sqlserver() {
    stop_sqlserver
    start_sqlserver
}

# Check SQL Server status
status_sqlserver() {
    check_docker
    
    if container_exists; then
        if container_running; then
            echo -e "${GREEN}SQL Server is running.${NC}"
            
            # Show connection info
            IP_ADDRESS=$(hostname -I | awk '{print $1}')
            echo -e "Connection details:"
            echo -e "  Host: localhost or $IP_ADDRESS"
            echo -e "  Port: $PORT"
            echo -e "  User: SA"
            
            # Show container details
            echo ""
            echo -e "${BLUE}Container details:${NC}"
            sudo docker ps --filter "name=$CONTAINER_NAME" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
            
            # Show basic database info
            echo ""
            echo -e "${BLUE}Running database check...${NC}"
            get_password
            sudo docker exec -it $CONTAINER_NAME /opt/mssql-tools/bin/sqlcmd -S localhost \
                -U SA -P "$SA_PASSWORD" -Q "SELECT name, state_desc FROM sys.databases" -h -1
        else
            echo -e "${YELLOW}SQL Server container exists but is not running.${NC}"
            echo -e "Run '$(basename $0) start' to start it."
        fi
    else
        echo -e "${RED}SQL Server container does not exist.${NC}"
        echo -e "Run '$(basename $0) start' to create and start it."
    fi
}

# Backup all user databases
backup_databases() {
    if ! container_running; then
        echo -e "${RED}SQL Server is not running. Please start it first.${NC}"
        exit 1
    fi
    
    # Make sure we have the password
    get_password
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_SCRIPT="/tmp/backup_script_$TIMESTAMP.sql"
    
    echo -e "${BLUE}Creating backup script...${NC}"
    
    # Create a SQL script to backup all user databases
    cat > $BACKUP_SCRIPT << EOF
DECLARE @name NVARCHAR(128)
DECLARE @path NVARCHAR(256)
DECLARE @fileName NVARCHAR(256)
DECLARE @fileDate NVARCHAR(20)

SET @path = '$CONTAINER_BACKUP_DIR/'
SET @fileDate = '$TIMESTAMP'

DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases
WHERE name NOT IN ('master','model','msdb','tempdb')
AND state_desc = 'ONLINE'

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @name

WHILE @@FETCH_STATUS = 0
BEGIN
   SET @fileName = @path + @name + '_' + @fileDate + '.bak'
   BACKUP DATABASE @name TO DISK = @fileName WITH COMPRESSION, INIT
   PRINT 'Backed up database: ' + @name + ' to ' + @fileName
   FETCH NEXT FROM db_cursor INTO @name
END

CLOSE db_cursor
DEALLOCATE db_cursor
GO
EOF
    
    echo -e "${BLUE}Executing database backups...${NC}"
    sudo docker cp $BACKUP_SCRIPT $CONTAINER_NAME:/tmp/
    sudo docker exec -it $CONTAINER_NAME /opt/mssql-tools/bin/sqlcmd -S localhost \
        -U SA -P "$SA_PASSWORD" -i /tmp/backup_script_$TIMESTAMP.sql
    
    # Copy backups to host if needed
    echo -e "${BLUE}Copying backup files to host at $HOST_BACKUP_DIR...${NC}"
    mkdir -p $HOST_BACKUP_DIR/$TIMESTAMP
    sudo docker exec -it $CONTAINER_NAME find $BACKUP_DIR -name "*_$TIMESTAMP.bak" -exec ls -la {} \;
    
    for BAK_FILE in $(sudo docker exec -it $CONTAINER_NAME find $BACKUP_DIR -name "*_$TIMESTAMP.bak" | tr -d '\r'); do
        FILENAME=$(basename $BAK_FILE)
        sudo docker cp $CONTAINER_NAME:$BAK_FILE $HOST_BACKUP_DIR/$TIMESTAMP/
        echo -e "${GREEN}Copied: $FILENAME${NC}"
    done
    
    rm -f $BACKUP_SCRIPT
    echo -e "${GREEN}Backup completed. Files saved to $HOST_BACKUP_DIR/$TIMESTAMP${NC}"
}

# Display help
show_help() {
    echo "SQL Server Docker Management Script"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start    - Start SQL Server container"
    echo "  stop     - Stop SQL Server container"
    echo "  restart  - Restart SQL Server container"
    echo "  status   - Check SQL Server status"
    echo "  backup   - Backup all user databases"
    echo "  help     - Show this help message"
    echo ""
    echo "Options:"
    echo "  -p, --password PASSWORD  - Specify SA password"
    echo "  -d, --dir DIRECTORY      - Specify base directory for SQL Server files"
    echo "                             (default: $HOME/sqlserver)"
    echo "  -h, --help               - Show this help message"
    echo ""
    echo "Notes:"
    echo "  - If no password is provided, the script will check for a saved password"
    echo "    in ~/.mssql-docker.conf or prompt for one"
    echo "  - The password is only needed for initial container creation and for"
    echo "    certain operations like status checks and backups"
    echo "  - The base directory will contain subdirectories for data, logs, and backups"
    echo ""
}

# Process command line arguments
COMMAND=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        start|stop|restart|status|backup)
            COMMAND="$1"
            shift
            ;;
        -p|--password)
            SA_PASSWORD="$2"
            shift 2
            ;;
        -d|--dir)
            BASE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# If no command was specified, show help
if [ -z "$COMMAND" ]; then
    show_help
    exit 1
fi

# Main script execution
case "$COMMAND" in
    start)
        start_sqlserver
        ;;
    stop)
        stop_sqlserver
        ;;
    restart)
        restart_sqlserver
        ;;
    status)
        status_sqlserver
        ;;
    backup)
        backup_databases
        ;;
esac

exit 0
#!/usr/bin/env bash
# Minecraft Server Installation Script - James A. Chambers - https://jamesachambers.com
#
# Instructions: https://jamesachambers.com/minecraft-bedrock-edition-ubuntu-dedicated-server-guide/
# Resource Pack Guide: https://jamesachambers.com/minecraft-bedrock-server-resource-pack-guide/
#
# To run the setup script use:
# curl https://raw.githubusercontent.com/TheRemote/MinecraftBedrockServer/master/SetupMinecraft.sh | bash
#
# GitHub Repository: https://github.com/TheRemote/MinecraftBedrockServer

# Function to write a horizontal bar
Draw_Line() {
  echo "================================================================================="
}

Draw_Line
echo "Minecraft Bedrock Server installation script by James Chambers"
echo "Latest version always at https://github.com/TheRemote/MinecraftBedrockServer"
echo "Don't forget to set up port forwarding on your router!  The default port is 19132"

# Declarations
tmpfile="/tmp/minecraftbedrockserver.zip"
tmppath="/tmp/minecraftbedrockserver"

# Randomizer for user agent
RandNum=$(echo $((1 + $RANDOM % 5000)))

# Function to read input from user with a prompt
read_with_prompt() {
  variable_name="$1"
  prompt="$2"
  default="${3-}"
  unset $variable_name
  while [[ ! -n ${!variable_name} ]]; do
    read -p "$prompt: " $variable_name < /dev/tty
    if [ ! -n "`which xargs`" ]; then
      declare -g $variable_name=$(echo "${!variable_name}" | xargs)
    fi
    declare -g $variable_name=$(echo "${!variable_name}" | head -n1 | awk '{print $1;}')
    if [[ -z ${!variable_name} ]] && [[ -n "$default" ]] ; then
      declare -g $variable_name=$default
    fi
    echo -n "$prompt: ${!variable_name} -- accept (Y/n)?"
    read answer < /dev/tty
    if [ "$answer" == "${answer#[Yy]}" ] && [ "$answer" != "" ]; then
      unset $variable_name
    else
      echo "$prompt: ${!variable_name}"
    fi
  done
}

Update_Script() {
  filenew="$1"
  filelocal="$2"
  
  if [ -e "$filelocal" ]; then
    cmp -s $filenew $filelocal
    if [[ $? -ne 0 ]]; then
      echo "Local copy of $filelocal is outdated.  Updating file."
      rm $filelocal
      cp $filenew $filelocal
      chmod +x $filelocal
      return 1
    else
      echo "Local copy of $filelocal is already current."
      return 0
    fi
  else
    cp $filenew $filelocal
    chmod +x $filelocal
    return 0
  fi
}

Update_Scripts() {
  Draw_Line
  Update_Script "$tmppath/MinecraftBedrockServer-master/start.sh" "start.sh"
  Update_Script "$tmppath/MinecraftBedrockServer-master/stop.sh" "stop.sh"
  Update_Script "$tmppath/MinecraftBedrockServer-master/restart.sh" "restart.sh"
  Update_Script "$tmppath/MinecraftBedrockServer-master/fixpermissions.sh" "fixpermissions.sh"
  Update_Script "$tmppath/MinecraftBedrockServer-master/update.sh" "update.sh"
  Draw_Line
}

Update_Service() {
  # Update minecraft server service
  echo "Configuring Minecraft $ServerName service..."
  sudo curl -H "Accept-Encoding: identity" -L -o /etc/systemd/system/$ServerName.service https://raw.githubusercontent.com/TheRemote/MinecraftBedrockServer/master/minecraftbe.service
  sudo chmod +x /etc/systemd/system/$ServerName.service
  sudo sed -i "s:userxname:$UserName:g" /etc/systemd/system/$ServerName.service
  sudo sed -i "s:dirname:$DirName:g" /etc/systemd/system/$ServerName.service
  sudo sed -i "s:servername:$ServerName:g" /etc/systemd/system/$ServerName.service
  sed -i "/server-port=/c\server-port=$PortIPV4" server.properties
  sed -i "/server-portv6=/c\server-portv6=$PortIPV6" server.properties
  sudo systemctl daemon-reload
  
  echo -n "Start Minecraft server at startup automatically (y/n)?"
  read answer < /dev/tty
  if [[ "$answer" != "${answer#[Yy]}" ]]; then
    sudo systemctl enable $ServerName.service
    # Automatic reboot at 4am configuration
    TimeZone=$(cat /etc/timezone)
    CurrentTime=$(date)
    echo "Your time zone is currently set to $TimeZone.  Current system time: $CurrentTime"
    echo "You can adjust/remove the selected reboot time later by typing crontab -e or running SetupMinecraft.sh again."
    echo -n "Automatically restart and backup server at 4am daily (y/n)?"
    read answer < /dev/tty
    if [[ "$answer" != "${answer#[Yy]}" ]]; then
      croncmd="$DirName/minecraftbe/$ServerName/restart.sh 2>&1"
      cronjob="0 4 * * * $croncmd"
      ( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -
      echo "Daily restart scheduled.  To change time or remove automatic restart type crontab -e"
    fi
  fi
}

Fix_Permissions() {
  echo "Setting server file permissions..."
  sudo ./fixpermissions.sh -a > /dev/null
}

Check_Dependencies() {
  # Install dependencies required to run Minecraft server in the background
  if command -v apt-get &> /dev/null; then
    Draw_Line
    echo "Updating apt.."
    sudo apt-get update

    if ! dpkg-query --show libcurl4 &> /dev/null; then
      if apt-cache show libcurl4 &> /dev/null; then
        sudo apt-get install libcurl4 -y
      else
        # Install libcurl3 for backwards compatibility in case libcurl4 isn't available
        sudo apt-get install libcurl3 -y
      fi
    fi

    echo "Checking and installing dependencies.."
    if ! command -v curl &> /dev/null; then sudo apt-get install curl -y; fi
    if ! command -v unzip &> /dev/null; then sudo apt-get install unzip -y; fi
    if ! command -v screen &> /dev/null; then sudo apt-get install screen -y; fi
    if ! command -v route &> /dev/null; then sudo apt-get install net-tools -y; fi
    if ! command -v gawk &> /dev/null; then sudo apt-get install gawk -y; fi
    if ! command -v openssl &> /dev/null; then sudo apt-get install openssl -y; fi
    if ! command -v xargs &> /dev/null; then sudo apt-get install xargs -y; fi

    if ! dpkg-query --show libc6 &> /dev/null; then sudo apt-get install libc6 -y; fi
    if ! dpkg-query --show libcrypt1 &> /dev/null; then sudo apt-get install libcrypt1 -y; fi

    echo "Dependency installation completed"
  else
    echo "Warning: apt was not found.  You may need to install curl, screen, unzip, libcurl4, openssl, libc6 and libcrypt1 with your package manager for the server to start properly!"
  fi
  Draw_Line
}

Update_Server() {
  Draw_Line
  # Retrieve latest version of Minecraft Bedrock dedicated server
  echo "Checking for the latest version of Minecraft Bedrock server..."
  curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.33 (KHTML, like Gecko) Chrome/90.0.$RandNum.212 Safari/537.33" -o downloads/version.html https://minecraft.net/en-us/download/server/bedrock/
  DownloadURL=$(grep -o 'https://minecraft.azureedge.net/bin-linux/[^"]*' downloads/version.html)
  DownloadFile=$(echo "$DownloadURL" | sed 's#.*/##')
  echo "$DownloadURL"
  echo "$DownloadFile"

  # Download latest version of Minecraft Bedrock dedicated server
  echo "Downloading the latest version of Minecraft Bedrock server..."
  UserName=$(whoami)
  curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.33 (KHTML, like Gecko) Chrome/90.0.$RandNum.212 Safari/537.33" -o "downloads/$DownloadFile" "$DownloadURL"
  unzip -o "downloads/$DownloadFile"
  Draw_Line
}

Check_Architecture () {
  Draw_Line
  # Check CPU archtecture to see if we need to do anything special for the platform the server is running on
  echo "Getting system CPU architecture..."
  CPUArch=$(uname -m)
  echo "System Architecture: $CPUArch"

  # Check for ARM architecture
  if [[ "$CPUArch" == *"aarch"* || "$CPUArch" == *"arm"* ]]; then
    # ARM architecture detected -- download QEMU and dependency libraries
    echo "ARM platform detected -- installing dependencies..."

    # Check if latest available QEMU version is at least 3.0 or higher
    QEMUVer=$(apt-cache show qemu-user-static | grep Version | awk 'NR==1{ print $2 }' | cut -c3-3)
    if [[ "$QEMUVer" -lt "3" ]]; then
      echo "Available QEMU version is not high enough to emulate x86_64.  Please update your QEMU version."
      exit
    else
      sudo apt-get update && sudo apt-get install qemu-user-static binfmt-support -y
    fi

    if [ -n "`which qemu-x86_64-static`" ]; then
      echo "QEMU-x86_64-static installed successfully"
    else
      echo "QEMU-x86_64-static did not install successfully -- please check the above output to see what went wrong."
      exit 1
    fi

    # Retrieve depends.zip from GitHub repository
    curl -H "Accept-Encoding: identity" -L -o depends.zip https://raw.githubusercontent.com/TheRemote/MinecraftBedrockServer/master/depends.zip
    unzip depends.zip
    sudo mkdir /lib64
    # Create soft link ld-linux-x86-64.so.2 mapped to ld-2.31.so
    sudo rm -rf /lib64/ld-linux-x86-64.so.2
    sudo ln -s $DirName/minecraftbe/$ServerName/ld-2.31.so /lib64/ld-linux-x86-64.so.2
  fi

  # Check for x86 (32 bit) architecture
  if [[ "$CPUArch" == *"i386"* || "$CPUArch" == *"i686"* ]]; then
    # 32 bit attempts have not been successful -- notify user to install 64 bit OS
    echo "You are running a 32 bit operating system (i386 or i686) and the Bedrock Dedicated Server has only been released for 64 bit (x86_64).  If you have a 64 bit processor please install a 64 bit operating system to run the Bedrock dedicated server!"
    exit 1
  fi
  Draw_Line
}

Update_Sudoers() {
  Draw_Line
  if [ -d /etc/sudoers.d ]; then
    sudoline="$UserName ALL=(ALL) NOPASSWD: /bin/bash $DirName/minecraftbe/$ServerName/fixpermissions.sh -a, /bin/systemctl start $ServerName, /bin/bash $DirName/minecraftbe/$ServerName/start.sh"
    if [ -e /etc/sudoers.d/minecraftbe ]; then
      AddLine=$(sudo grep -qxF "$sudoline" /etc/sudoers.d/minecraftbe || echo "$sudoline" | sudo tee -a /etc/sudoers.d/minecraftbe)
    else
      AddLine=$(echo "$sudoline" | sudo tee /etc/sudoers.d/minecraftbe)
    fi
  else
    echo "/etc/sudoers.d was not found on your system.  Please add this line to sudoers using sudo visudo:  $sudoline"
  fi
  Draw_Line
}

Update_Config() {
  printf 'userpath="%s"\ndirname="%s"\nservername="%s"\nuserxname="%s"\n' $PATH $DirName $ServerName $UserName > server.config
}

Fetch_Current() {
  if [ -f $tmpfile ]; then
    rm $tmpfile
  fi
  curl https://codeload.github.com/SvenLudwig202/MinecraftBedrockServer/zip/refs/heads/master -o $tmpfile
  if [ -d $tmppath ]; then
    rm -rf $tmppath
  fi
  mkdir $tmppath
  unzip -d $tmppath -q $tmpfile
  rm $tmpfile
}

Update_Self() {
  if [ -e "SetupMinecraft.sh" ]; then
    Draw_Line
    cmp -s $tmppath/MinecraftBedrockServer-master/SetupMinecraft.sh SetupMinecraft.sh
    if [[ $? -ne 0 ]]; then
      echo "Local copy of SetupMinecraft.sh is outdated.  Exiting and running current version..."
      rm -f "SetupMinecraft.sh"
      cp $tmppath/MinecraftBedrockServer-master/SetupMinecraft.sh SetupMinecraft.sh
      /usr/bin/env bash SetupMinecraft.sh
      exit 1
    else
      echo "You are running the current version of SetupMinecraft.sh."
    fi
    Draw_Line
  fi
}

################################################################################################# End Functions

# Check to make sure we aren't running as root
if [[ $(id -u) = 0 ]]; then
   echo "This script is not meant to be run as root. Please run ./SetupMinecraft.sh as a non-root user, without sudo; the script will call sudo when it is needed. Exiting..."
   exit 1
fi

Check_Dependencies

Fetch_Current

Update_Self

# Get directory path (default ~)
Draw_Line
until [ -d "$DirName" ]
do
  echo "Enter root installation path for Minecraft BE (this is the same for ALL servers and should be ~, the subfolder will be chosen from the server name you provide). Almost nobody should change this unless you're installing to a different disk altogether. (default ~): "
  read_with_prompt DirName "Directory Path" ~
  DirName=$(eval echo "$DirName")
  if [ ! -d "$DirName" ]; then
    echo "Invalid directory.  Please use the default path of ~ or you're going to have errors.  This should be the same for ALL servers as it is your ROOT install directory."
  fi
done

# Check to see if Minecraft server main directory already exists
cd $DirName
if [ ! -d "minecraftbe" ]; then
  mkdir minecraftbe
  cd minecraftbe
else
  cd minecraftbe
  if [ -f "bedrock_server" ]; then
    echo "Migrating old Bedrock server to minecraftbe/old"
    cd $DirName
    mv minecraftbe old
    mkdir minecraftbe
    mv old minecraftbe/old
    cd minecraftbe
    echo "Migration complete to minecraftbe/old"
  fi
fi

# Server name configuration
Draw_Line
echo "Enter a short one word label for a new or existing server (don't use minecraftbe)..."
echo "It will be used in the folder name and service name... (default bedrock)"

until [[ -n "$ServerName" ]]; do
  read_with_prompt ServerName "Server Label" bedrock

  if [[ "$ServerName" == *"minecraftbe"* ]]; then
    echo "Server label of minecraftbe is not allowed.  Please choose a different server label!"
    unset ServerName
  fi
done

Draw_Line
echo "Enter server IPV4 port (default 19132): "
read_with_prompt PortIPV4 "Server IPV4 Port" 19132

Draw_Line
echo "Enter server IPV6 port (default 19133): "
read_with_prompt PortIPV6 "Server IPV6 Port" 19133

if [ -d "$ServerName" ]; then
  Draw_Line
  echo "Directory minecraftbe/$ServerName already exists!  Updating scripts and configuring service ..."

  # Get username
  UserName=$(whoami)
  cd $DirName
  cd minecraftbe
  cd $ServerName
  echo "Server directory is: $DirName/minecraftbe/$ServerName"

  # Update configuration file
  Update_Config

  # Update Minecraft server scripts
  Update_Scripts

  exit  # FIXME

  # Service configuration
  Update_Service

  # Sudoers configuration
  Update_Sudoers

  # Fix server files/folders permissions
  Fix_Permissions

  # Setup completed
  echo "Setup is complete.  Starting Minecraft $ServerName server.  To view the console use the command screen -r or check the logs folder if the server fails to start"
  sudo systemctl daemon-reload
  sudo systemctl start $ServerName.service

  exit 0
fi

exit  # FIXME

# Create server directory
echo "Creating minecraft server directory ($DirName/minecraftbe/$ServerName)..."
cd $DirName
cd minecraftbe
mkdir $ServerName
cd $ServerName
mkdir downloads
mkdir backups
mkdir logs

Check_Architecture

# Update Minecraft server binary
Update_Server

# Update Minecraft server scripts
Update_Scripts

# Update Minecraft server services
Update_Service

# Sudoers configuration
Update_Sudoers

# Fix server files/folders permissions
Fix_Permissions

# Finished!
echo "Setup is complete.  Starting Minecraft server. To view the console use the command screen -r or check the logs folder if the server fails to start."
sudo systemctl daemon-reload
sudo systemctl start $ServerName.service

# Wait up to 20 seconds for server to start
StartChecks=0
while [[ $StartChecks -lt 20 ]]; do
  if screen -list | grep -q "\.$ServerName"; then
    break
  fi
  sleep 1;
  StartChecks=$((StartChecks+1))
done

# Force quit if server is still open
if ! screen -list | grep -q "\.$ServerName"; then
  echo "Minecraft server failed to start after 20 seconds."
else
  echo "Minecraft server has started.  Type screen -r $ServerName to view the running server!"
fi


#!/bin/bash

# Author: robot
# Date: 09/29/2024

#Arg 1 is the supplied VMDK or help entries
if [ -z "$1" ]
then
   echo "X - Please supply an input '*.vmdk' file path to convert from - X"
   exit 0
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
   echo "+++++++++++++++++++++++"
   echo "This script is used to convert VMDK VMs to the qcow2 format that UTM supports for x86 virtualization on ARM macOS"
   echo "After converting the input VMDK to qcow2 you can follow the steps here to import it into UTM as documented by SYSADMIN102"
   echo " -->  https://youtu.be/1suVXymrD0Q"
   echo "OR: Allow the script to create default template VM with the converted drive attached that you can then modify to run"
   echo "+++++++++++++++++++++++"
   echo ""
   echo "Usage: ./UTM_convert /Users/robot/Downloads/MyVM/MyVM.vmdk /Users/robot/VMDrives/MyVM.qcow2"
   exit 0
fi

#Check that a second argument for output has been supplied
if [ -z "$2" ]
then
   echo "X - Please supply an output '*.qcow2' file path to convert to - X"
   exit 0
fi

#Check where brew is installed for the user
BREW_PATH=$(which brew)

if [ ! -z "$BREW_PATH" ]
then
   echo "+ found brew at $BREW_PATH +"
else
   echo "X - brew command could not be resolved - X"
   echo "+ Exiting. Please install Homebrew and re-run +"
   exit 0 
fi

#Check if qemu-img is already installed for converting
QEMU_PATH=$(which qemu-img)

if [ -z "$QEMU_PATH" ]
then
    $BREW_PATH install qemu
    QEMU_PATH=$(which qemu-img)
fi

if [ -z "$QEMU_PATH" ]
then
   echo 'X - brew install of qemu failed, please run "brew install qemu" - X'
   exit 0
fi

#Convert the supplied files
if  qemu-img convert -f vmdk -O qcow2 $1 $2
then
   echo "+ Successfully converted vmdk file to qcow2 +"
else
   echo "X - Image conversion of vmdk failed! - X"
   exit 0
fi

#Get user input on creating a template machine
echo "? - Would you like to create a template UTM machine with the converted disk attached? (Requires  UTM application in /Applications/UTM.app) (y/n) -?"
read -p ">" template_bool

#Convert input to lowercase
lower_bool=$(echo "$template_bool" | awk '{print tolower($0)}')

#Validate either "y" or "n" was supplied
while [[ "$lower_bool" != "y" && "$lower_bool" != "n" ]] 
do
   echo "X - Only 'y' or 'n' response is accepted - X"
   echo ""
   echo "? - Would you like to create a template UTM machine with the converted disk attached? (Requires  UTM application in /Applications/UTM.app) (y/n) -?"
   read -p ">" template_bool
   lower_bool=$(echo "$template_bool" | awk '{print tolower($0)}')
done

if [[ $lower_bool == "n" ]]
then
    echo "+ No virtual machine created +"
    echo "+ Done +"
    exit 0
fi

#Check for UTM.app in Applications
if [ -e "/Applications/UTM.app/Contents/MacOS/utmctl" ]
then
   echo "+ Found utmctl at /Applications/UTM.app/Contents/MacOS/utmctl +"
else
   echo "X - utmctl not found at '/Applications/UTM.app/Contents/MacOS/utmctl', please install UTM in /Applications - X"
   exit 0
fi

echo "+ Creating template machine: UTM_Convert_Out +"

#Create an AppleScript that configures the UTM VM template
echo 'tell application "UTM"' > /tmp/convert.scpt
echo -n '	set qdrive to POSIX file "' >> /tmp/convert.scpt
echo -n $2 >> /tmp/convert.scpt
echo '"' >> /tmp/convert.scpt
echo '	set vm to make new virtual machine with properties {backend:qemu, configuration:{name:"UTM_Convert_Out", architecture:"x86_64", memory:4096, hypervisor:false, drives:{{removable:false, source:qdrive}}, uefi:false}}' >> /tmp/convert.scpt
echo 'end tell' >> /tmp/convert.scpt 
echo ""

#Run the script
osascript -l AppleScript /tmp/convert.scpt

#Clean up the script
rm /tmp/convert.scpt

#Show some helpful tips
echo "+ NEXT STEPS +"
echo "Restrictions in the UTM app prevent creating a perfect instance. Here are some recommended tweaks for your x86_64 VM to run normally."
echo "	1. You will need to add a display in the UTM application VM Settings if the VM requires one (virtio-vga seems to work pretty well)"
echo "	2. Memory was configured to 4GB, update this to your system requirements"
echo '	3. It is recommended to go into the VM "System" settings and enable "Force Multicore" for a better experience. ! - Caution this may lead to instability on some systems, but it is rare - !'
echo "	4. You can remove the created serial interface if not needed"
echo "	5. Rename the VM if you plan to run the UTM_convert script in the future to create another template VM"
echo ""
echo "+ Done +"


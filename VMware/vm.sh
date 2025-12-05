#!/bin/bash

set -euo pipefail


# Run the below script 1st then run the code

# USER="kaylene"

# sudo apt update
# sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager

# sudo usermod -aG libvirt,kvm "$USER"

### CONFIGURATION ###

# Name of the VM
VM_NAME="windows10"

# Path to your Windows ISO
ISO_PATH="/home/kaylene/Downloads/Win10_22H2_English_x64v1.iso"   

# Where to store the VM disk image
DISK_DIR="/home/kaylene/data2tb/vms"              
DISK_SIZE_GB=80                   # virtual disk size in GB

# Resources to assign
RAM_MB=8192                       # 8 GB RAM
VCPUS=4                           # 4 virtual CPUs

# OS variant 
OS_VARIANT="win10"

### END CONFIG ###

# Create disk directory if it doesn't exist
mkdir -p "$DISK_DIR"

DISK_PATH="$DISK_DIR/${VM_NAME}.qcow2"

echo "Creating VM disk at: $DISK_PATH (${DISK_SIZE_GB}G)"
qemu-img create -f qcow2 "$DISK_PATH" "${DISK_SIZE_GB}G"

echo "Starting virt-install for VM: $VM_NAME"

virt-install \
  --name "$VM_NAME" \
  --ram "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --os-type windows \
  --os-variant "$OS_VARIANT" \
  --cdrom "$ISO_PATH" \
  --disk path="$DISK_PATH",format=qcow2,bus=virtio \
  --graphics spice \
  --network network=default,model=virtio \
  --boot useserial=on \
  --noautoconsole

echo
echo "VM '$VM_NAME' is being created."
echo "Open 'Virtual Machine Manager' (virt-manager) to view the console and complete the Windows installation."

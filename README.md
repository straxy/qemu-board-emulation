# Helper scripts
Supporting files for QEMU Board emulation post series at [www.mistrasolutions.com](https://www.mistrasolutions.com/).

Following scripts are present:

- `install-qemu.bash` - downloads toolchain and Ubuntu root filesystem, and compiles QEMU, U-Boot and Linux
- `prepare-qemu.bash` - creates an SD card image based on compiled files and Ubuntu root filesystem
- `enable-networking.bash` - initializes a tap network interface so QEMU instance can have networking
- `mount-sd-card.bash` - mounts rootfs partition of the SD card
- `umount-sd-card.bash` - umounts rootfs partition of the SD card
- `run-qemu.bash` - runs QEMU instance


---
title: "Ansible-collection for Developer Tools Installation"
description: "Automate the setup of essential developer tools for embedded development on Ubuntu using Ansible."
date: 2026-01-24
tags: ["Ansible", "CICD"]
---

## Description
I created an Ansible collection to automate the installation of essential developer tools for bare-metal embedded development on Ubuntu Linux systems. This collection simplifies the setup process by providing predefined roles for installing commonly used tools.

## What the collection includes
The collection contains roles for installing:
- arm-none-eabi-gcc (cross-compiler for ARM)
- SEGGER J-Link (debugger and programmer)
- can-utils and PEAK CAN driver (for working with CAN bus)

Roles can be combined, extended, or used selectively.

## Quick Start
1. Set up the target machine (Ubuntu, OpenSSH, Ansible).
   Install Ansible:
   ```bash
   sudo apt update && sudo apt install ansible
   ```
2. Install the collection via Ansible Galaxy:
   ```sh
   ansible-galaxy collection install paulfirs.baremetal
   ```
3. Create a playbook, for example, `site.yml`, or use a ready-made one from `examples/`:
   ```yaml
   - hosts: all
     become: yes
     roles:
       - paulfirs.baremetal.install_eabi_arm_gcc
       - paulfirs.baremetal.install_jlink
       - paulfirs.baremetal.install_can_tools
   ```
4. Run the playbook:
   ```
   ansible-playbook -i "user@host," site.yml --ask-pass --ask-become-pass
   ```
   - `-i "user@host,"` — inventory as a string (you can use an inventory file)
   - `--ask-pass` — prompt for SSH user password (if not using a key)
   - `--ask-become-pass` — prompt for sudo password (root access)
   You can use an inventory file for mass configuration.

## Implementation details
- PEAK CAN driver is always downloaded from the official website, the latest version.
- All roles use `become: yes` to work with system files and packages.
- All dependencies are installed automatically.
- README contains detailed instructions for installation and running.

## Advantages of the approach
- Fast and repeatable setup of any baremetal environment.
- Minimal manual actions — everything is done with a single command.
- Easy to extend: you can add new roles for other tools or exclude unnecessary ones from `site.yml`.
- Easy to integrate into CI/CD pipelines.

## Conclusion
If you often set up Linux machines for embedded development, try automating this process with Ansible. Save time and avoid errors!

- **Repository:** [GitHub](https://github.com/BareMetalTestLab/ansible-collection-baremetal)
- **Ansible Galaxy:** [paulfirs.baremetal](https://galaxy.ansible.com/ui/repo/published/paulfirs/baremetal/)


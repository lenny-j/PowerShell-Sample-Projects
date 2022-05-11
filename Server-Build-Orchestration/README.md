## Scripts used to support auto provisioning of Virtual Machines

### Summary

Supporting scripts consumed by ServiceNow Orchestration module

Used to interface between ServiceNow and on-Prem Virtual Center platform to provision virtual servers

All scripts require the following dependencies
- VMWare PowerCLI Modules
Expect to transition the calls to alternate API soon
- ServiceNow Orchestration Module
Acts as primary interface for customer request(s), and task coordinator to build machines

### Script Inventory

[1-Clone-VM-iDm__FULLY-MANAGED__QA-v2.ps1](https://github.com/lenny-j/dft-PowerShell-Sample-Projects/blob/main/Server-Build-Orchestration/1-Clone-VM-iDm__FULLY-MANAGED__QA-v2.ps1)

#### Summary

- Creates a new VM based on an existing template housed in vCenter

2-Provision_CPU-MEM-NIC_iDm_BYDEFAULT__QA.ps1

#### Summary

- Once a new VM instance is present in vCenter, start by setting some virtual hardware requirements

3-Collect-cloned-disk-inventory_QA_V1.ps1

#### Summary

- To manage varied "disk" requirements, this step begins by querying for immediate, post clone virtual disk hardware inventory.
- This inventory will be consumed in the next step to add any additional hardware based on customer request.

4-Add-Virtual-Disk-Hardware_QA_v3.ps1

#### Summary

- Add additional virtual disk hardware as needed.
- Number and disk capacity set by each request instance.

5-Get-OS-DiskInventory_2012+_v2.ps1

#### Summary

- Once virtual disk hardware is configured via vCenter, begin to work at the OS level.

6-Initalize-and-Format-OS-Disks_QA-v4.ps1

#### Summary

- Complete OS level disk configuration to create volumes, etc.

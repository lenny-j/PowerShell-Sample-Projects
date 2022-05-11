## Script for some Windows File Share provisioning

### Summary

The goal of this job - is to complete a share provisioning after the share endpoint has been configured.

By using a config file and standard access assignment template, this job can be included in an automation workflow allowing customers to request new file share(s).

### Script Inventory

1-Create_Standard_Share_Folders.ps1

#### Summary

- Create a new, root folder structure within an NTFS share location, based on a source configuration file
- Manages creation and assignment of security groups to provide standard access levels
- Access delegation steps fully leverage Active Directory identities
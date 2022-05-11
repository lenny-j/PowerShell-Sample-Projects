## Scripts used with common Active Directory tasks

### Summary

Used to
- manage objects within AD
- monitor service health (on demand)

### Script Inventory

1-Dynamic-SecurityGroup-Population_BasedOnCMDB.ps1

#### Summary

- Adds computer accounts to security groups - based on their CMDB attributes
- Sources CMDB inventory data from ServiceNow
- Catageorizes machines into groups based on which Application CI they belong to, and which environment they server (Prod, Test, Dev, etc.)

2-LDAP-Service_Connect_and_bind_Monitor.ps1

#### Summary

- Used as an interactive health check tool to scan primary LDAP service endpoints
- Performs connect & BIND, and an object search step
- Saves service status to file

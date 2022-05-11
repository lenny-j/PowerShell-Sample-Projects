# A Framework - for an Active Directory Web Search App

## Intends to use MERN Stack, and source data from a PowerShell export scheduled task

### Summary

Users / Customers like to view AD data about group memberships

Providing a simple web app for this can help reduce support queries / calls

The information on group memberships is easily accessible, and the app is limited to JUST this data

### Folder / Component Inventory

/DomainController-Src

#### Summary

- Short PowerShell script that gets added to a schedule; this can be hourly or daily depending on consumer need(s)
- Fetches user data from the domain controller, and then uses Mongo utility to UPSET / Update DB

/Express-Src

#### Summary

- Hosts API service to serve DB queries

/React-App-Src

#### Summary

- Very simple SPA with a search form - that matches results based on user name, or displayname
- Returns the list of security group memberships for a person 

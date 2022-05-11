## Scripts that enforce GRC control criteria of AD identity objects

### Summary

The compliance group sets lifecycle (and other) account policies.

For example: inactive accounts are automatically set to disabled after a certain time period

These jobs manage user, computer, and group objects - primarily for lifecycle events

### Script Inventory

1-Server-LocalAdmin-Scanning.ps1

#### Summary

- Scans the local admin groups of all servers in inventory
- Saves the results to one report file per application CI
- Compares, and identifies UNEXPECTED memberships based on a know list of allowed admin members
- These reports are delivered to resource owners, periodically, for review/removal/approval

2-ActiveDirectory_User_Lifecycle-US_Domain.ps1

#### Summary

- Disables, and deletes user accounts based on an inactive duration

3-ActiveDirectory_CompAcct_Lifecycle.ps1

#### Summary

- Disables, and deletes computer accounts based on an inactive duration
- Manages simple archive of AD published BitLocker recovery keys, if present (as these are leaf objects)

4-Active-Directory_SimpleDisabledCleanup.ps1

#### Summary

- Removes any remaining security group memberships from disabled user accounts, if possible (some groups have restricted administrative delegation beyond the scope of this job; e.g. Built-in\Administrators, etc.)

5-ActiveDirectory_UserCategorization-Scan.ps1

#### Summary

- Scans user accounts to find any exception acconts that are NOT included in one, or more expected group
- Results from this job are sent to support staff for review / remediation; the script does not take corrective action



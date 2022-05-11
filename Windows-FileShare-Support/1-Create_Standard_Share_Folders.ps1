# Public Cleared
# Feb 2019 Update: Adding in a MASTER Admin Group ACE; in place of the "Owner" step(s)
# --> <DOMIAN>\ads--fs_admins
# ToDos: ()add fs_admin Full ctrl to the PARENT Folder as well, near line 500

Import-Module ActiveDirectory
## Basic Folder Inventory Creation ##

$MasterFLDInv = Get-Content .\FolderInv_BASE.txt
[STRING]$SHARENameValue = Read-Host("Enter ShareNAME")


# Create Master READ Queue & Group
$AllNewGroups = @()
[STRING]$MasterReadACLGroup = "ACL-" + $SHARENameValue + "-ALL"
New-ADGroup -Name $MasterReadACLGroup -Path "<AD GROUP DN PARENT>" -GroupScope DomainLocal -OtherAttributes @{'info'="Created Using FSAutomation"}

foreach ($Line1 in $MasterFLDInv) 
{
New-Item -Path $Line1 -Type Directory


#$LineSecNameO = "ACL-" + $SHARENameValue + "-" + $Line1 + "-O"
$LineSecNameR = "ACL-" + $SHARENameValue + "-" + $Line1 + "-R"
$LineSecNameRW = "ACL-" + $SHARENameValue + "-" + $Line1 + "-RW"

# AD Security Group Creation
#New-ADGroup -Name $LineSecNameO -Path "<AD GROUP DN PARENT>" -GroupScope DomainLocal -OtherAttributes @{'info'="Created Using FSAutomation"}
New-ADGroup -Name $LineSecNameR -Path "<AD GROUP DN PARENT>" -GroupScope DomainLocal -OtherAttributes @{'info'="Created Using FSAutomation"}
New-ADGroup -Name $LineSecNameRW -Path "<AD GROUP DN PARENT>" -GroupScope DomainLocal -OtherAttributes @{'info'="Created Using FSAutomation"}


# Add each of these new groups to a QUEUE for further procesing
#$AllNewGroups += $LineSecNameO
$AllNewGroups += $LineSecNameR
$AllNewGroups += $LineSecNameRW 


}


# Great ... now we need a rest
Write-Host "Yo: I'm pausing to ensure Active Directory replication can finish..." -ForegroundColor Yellow
for ($ti = 0; $ti -lt 61; $ti++) {
$tr = 60 - $ti
Write-Progress -Activity "Waiting for Replication" -SecondsRemaining $tr
 #$ti -ForegroundColor Yellow
sleep 1
}


# Add the ACL Groups to the Master READ Object!
Add-ADGroupMember -Identity $MasterReadACLGroup -Members $AllNewGroups

#############
#############
#
#  NOW !! Deal with the Permissions assignment
#
#############
#############
#############


#regionTemplates

# Master Admin ACE Template
$MAAdminACE = @('<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
  <Obj RefId="0">
    <TN RefId="0">
      <T>System.Security.AccessControl.FileSystemAccessRule</T>
      <T>System.Security.AccessControl.AccessRule</T>
      <T>System.Security.AccessControl.AuthorizationRule</T>
      <T>System.Object</T>
    </TN>
    <ToString>System.Security.AccessControl.FileSystemAccessRule</ToString>
    <Props>
      <Obj N="FileSystemRights" RefId="1">
        <TN RefId="1">
          <T>System.Security.AccessControl.FileSystemRights</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>FullControl</ToString>
        <I32>2032127</I32>
      </Obj>
      <Obj N="AccessControlType" RefId="2">
        <TN RefId="2">
          <T>System.Security.AccessControl.AccessControlType</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>Allow</ToString>
        <I32>0</I32>
      </Obj>
      <Obj N="IdentityReference" RefId="3">
        <TN RefId="3">
          <T>System.Security.Principal.NTAccount</T>
          <T>System.Security.Principal.IdentityReference</T>
          <T>System.Object</T>
        </TN>
        <ToString><DOMAIN>ads--fs_admins</ToString>
        <Props>
          <S N="Value"><DOMAIN>ads--fs_admins</S>
        </Props>
      </Obj>
      <B N="IsInherited">false</B>
      <Obj N="InheritanceFlags" RefId="4">
        <TN RefId="4">
          <T>System.Security.AccessControl.InheritanceFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>ContainerInherit, ObjectInherit</ToString>
        <I32>3</I32>
      </Obj>
      <Obj N="PropagationFlags" RefId="5">
        <TN RefId="5">
          <T>System.Security.AccessControl.PropagationFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>None</ToString>
        <I32>0</I32>
      </Obj>
    </Props>
  </Obj>
</Objs>')
$MAAdminACE | Out-File ".\MAAdminTemp.xml"

# Owner ACE Template
$OwnerTemplate = @('<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
  <Obj RefId="0">
    <TN RefId="0">
      <T>System.Security.AccessControl.FileSystemAccessRule</T>
      <T>System.Security.AccessControl.AccessRule</T>
      <T>System.Security.AccessControl.AuthorizationRule</T>
      <T>System.Object</T>
    </TN>
    <ToString>System.Security.AccessControl.FileSystemAccessRule</ToString>
    <Props>
      <Obj N="FileSystemRights" RefId="1">
        <TN RefId="1">
          <T>System.Security.AccessControl.FileSystemRights</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>DeleteSubdirectoriesAndFiles, Modify, Synchronize</ToString>
        <I32>1245695</I32>
      </Obj>
      <Obj N="AccessControlType" RefId="2">
        <TN RefId="2">
          <T>System.Security.AccessControl.AccessControlType</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>Allow</ToString>
        <I32>0</I32>
      </Obj>
      <Obj N="IdentityReference" RefId="3">
        <TN RefId="3">
          <T>System.Security.Principal.NTAccount</T>
          <T>System.Security.Principal.IdentityReference</T>
          <T>System.Object</T>
        </TN>
        <ToString>CENTRICFOCUS\OWNER</ToString>
        <Props>
          <S N="Value">CENTRICFOCUS\OWNER</S>
        </Props>
      </Obj>
      <B N="IsInherited">false</B>
      <Obj N="InheritanceFlags" RefId="4">
        <TN RefId="4">
          <T>System.Security.AccessControl.InheritanceFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>ContainerInherit, ObjectInherit</ToString>
        <I32>3</I32>
      </Obj>
      <Obj N="PropagationFlags" RefId="5">
        <TN RefId="5">
          <T>System.Security.AccessControl.PropagationFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>None</ToString>
        <I32>0</I32>
      </Obj>
    </Props>
  </Obj>
</Objs>')
$OwnerTemplate | Out-File ".\OwnerTemp.xml"

<# R/W ACE Template
$RWTemplate = @('<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
  <Obj RefId="0">
    <TN RefId="0">
      <T>System.Security.AccessControl.FileSystemAccessRule</T>
      <T>System.Security.AccessControl.AccessRule</T>
      <T>System.Security.AccessControl.AuthorizationRule</T>
      <T>System.Object</T>
    </TN>
    <ToString>System.Security.AccessControl.FileSystemAccessRule</ToString>
    <Props>
      <Obj N="FileSystemRights" RefId="1">
        <TN RefId="1">
          <T>System.Security.AccessControl.FileSystemRights</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>CreateFiles, WriteExtendedAttributes, DeleteSubdirectoriesAndFiles, WriteAttributes, Delete, ReadAndExecute, Synchronize</ToString>
        <I32>1245691</I32>
      </Obj>
      <Obj N="AccessControlType" RefId="2">
        <TN RefId="2">
          <T>System.Security.AccessControl.AccessControlType</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>Allow</ToString>
        <I32>0</I32>
      </Obj>
      <Obj N="IdentityReference" RefId="3">
        <TN RefId="3">
          <T>System.Security.Principal.NTAccount</T>
          <T>System.Security.Principal.IdentityReference</T>
          <T>System.Object</T>
        </TN>
        <ToString>CENTRICFOCUS\READWRITER</ToString>
        <Props>
          <S N="Value">CENTRICFOCUS\READWRITER</S>
        </Props>
      </Obj>
      <B N="IsInherited">false</B>
      <Obj N="InheritanceFlags" RefId="4">
        <TN RefId="4">
          <T>System.Security.AccessControl.InheritanceFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>ContainerInherit, ObjectInherit</ToString>
        <I32>3</I32>
      </Obj>
      <Obj N="PropagationFlags" RefId="5">
        <TN RefId="5">
          <T>System.Security.AccessControl.PropagationFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>None</ToString>
        <I32>0</I32>
      </Obj>
    </Props>
  </Obj>
</Objs>')
$RWTemplate | Out-File ".\RWTemp.xml"
#>

# R/O ACE Template
$ROTemplate = @('<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
  <Obj RefId="0">
    <TN RefId="0">
      <T>System.Security.AccessControl.FileSystemAccessRule</T>
      <T>System.Security.AccessControl.AccessRule</T>
      <T>System.Security.AccessControl.AuthorizationRule</T>
      <T>System.Object</T>
    </TN>
    <ToString>System.Security.AccessControl.FileSystemAccessRule</ToString>
    <Props>
      <Obj N="FileSystemRights" RefId="1">
        <TN RefId="1">
          <T>System.Security.AccessControl.FileSystemRights</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>ReadAndExecute, Synchronize</ToString>
        <I32>1179817</I32>
      </Obj>
      <Obj N="AccessControlType" RefId="2">
        <TN RefId="2">
          <T>System.Security.AccessControl.AccessControlType</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>Allow</ToString>
        <I32>0</I32>
      </Obj>
      <Obj N="IdentityReference" RefId="3">
        <TN RefId="3">
          <T>System.Security.Principal.NTAccount</T>
          <T>System.Security.Principal.IdentityReference</T>
          <T>System.Object</T>
        </TN>
        <ToString>CENTRICFOCUS\READER</ToString>
        <Props>
          <S N="Value">CENTRICFOCUS\READER</S>
        </Props>
      </Obj>
      <B N="IsInherited">false</B>
      <Obj N="InheritanceFlags" RefId="4">
        <TN RefId="4">
          <T>System.Security.AccessControl.InheritanceFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>ContainerInherit, ObjectInherit</ToString>
        <I32>3</I32>
      </Obj>
      <Obj N="PropagationFlags" RefId="5">
        <TN RefId="5">
          <T>System.Security.AccessControl.PropagationFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>None</ToString>
        <I32>0</I32>
      </Obj>
    </Props>
  </Obj>
</Objs>')
$ROTemplate | Out-File ".\ROTemp.xml"

# MASTER-READ ACE Template (Example IdentityReference: <DOMAIN>ACL-GEMINI-SHARE-ALL)
$MasterRTemplate = @('<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
  <Obj RefId="0">
    <TN RefId="0">
      <T>System.Security.AccessControl.FileSystemAccessRule</T>
      <T>System.Security.AccessControl.AccessRule</T>
      <T>System.Security.AccessControl.AuthorizationRule</T>
      <T>System.Object</T>
    </TN>
    <ToString>System.Security.AccessControl.FileSystemAccessRule</ToString>
    <Props>
      <Obj N="FileSystemRights" RefId="1">
        <TN RefId="1">
          <T>System.Security.AccessControl.FileSystemRights</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>ReadData, ReadAttributes, Synchronize</ToString>
        <I32>1048705</I32>
      </Obj>
      <Obj N="AccessControlType" RefId="2">
        <TN RefId="2">
          <T>System.Security.AccessControl.AccessControlType</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>Allow</ToString>
        <I32>0</I32>
      </Obj>
      <Obj N="IdentityReference" RefId="3">
        <TN RefId="3">
          <T>System.Security.Principal.NTAccount</T>
          <T>System.Security.Principal.IdentityReference</T>
          <T>System.Object</T>
        </TN>
        <ToString><DOMAIN>ACL-GEMINI-SHARE-ALL</ToString>
        <Props>
          <S N="Value"><DOMAIN>ACL-GEMINI-SHARE-ALL</S>
        </Props>
      </Obj>
      <B N="IsInherited">false</B>
      <Obj N="InheritanceFlags" RefId="4">
        <TN RefId="4">
          <T>System.Security.AccessControl.InheritanceFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>None</ToString>
        <I32>0</I32>
      </Obj>
      <Obj N="PropagationFlags" RefId="5">
        <TN RefId="5">
          <T>System.Security.AccessControl.PropagationFlags</T>
          <T>System.Enum</T>
          <T>System.ValueType</T>
          <T>System.Object</T>
        </TN>
        <ToString>None</ToString>
        <I32>0</I32>
      </Obj>
    </Props>
  </Obj>
</Objs>')
$MasterRTemplate | Out-File ".\MasterRTemp.xml"

#endregion



foreach ($FldrItem in $MasterFLDInv) 
{

#$ACLGroupO_Name = "<DOMAIN>ACL-" + $SHARENameValue + "-" + $FldrItem + "-o"
$ACLGroupR_Name = "<DOMAIN>ACL-" + $SHARENameValue + "-" + $FldrItem + "-r"
$ACLGroupRW_Name = "<DOMAIN>ACL-" + $SHARENameValue + "-" + $FldrItem + "-rw"



## ACE 0 - Owner
# Fetch Ref. ACE Settings
<# WE DON'T WANT TO USE THE "O" ANYMORE - MOVING RIGHTS TO THE RW GROUP
$ACE0Ref = Import-Clixml .\OwnerTemp.xml
# SET New Identity Reference Value
$ACE1Ref.IdentityReference = $ACLGroupO_Name

# Need to expand/refine this object config. PER -> https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
$ACE0NewPermission = ($ACE0Ref.IdentityReference,$ACE0Ref.FileSystemRights,$ACE0Ref.InheritanceFlags,$ACE0Ref.PropagationFlags,$ACE0Ref.AccessControlType)

# ReCompose as NEW ACE Object
$ACE0Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACE0NewPermission)
#>

## ACE 1 - MASTER ADMIN 
# Fetch Ref. ACE Settings
$ACE1Ref = Import-Clixml .\MAAdminTemp.xml
# Swapping the ID to a STRING!!
$ACE1Ref.IdentityReference = "<DOMAIN>ads--fs_admins"
# Need to expand/refine this object config. PER -> https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
$ACE1NewPermission = ($ACE1Ref.IdentityReference,$ACE1Ref.FileSystemRights,$ACE1Ref.InheritanceFlags,$ACE1Ref.PropagationFlags,$ACE1Ref.AccessControlType)

# ReCompose as NEW ACE Object
$ACE1Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACE1NewPermission)

## ACE 2 - Read
# Fetch Ref. ACE Settings
$ACE2Ref = Import-Clixml .\ROTemp.xml
# SET New Identity Reference Value
$ACE2Ref.IdentityReference = $ACLGroupR_Name

# Need to expand/refine this object config. PER -> https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
$ACE2NewPermission = ($ACE2Ref.IdentityReference,$ACE2Ref.FileSystemRights,$ACE2Ref.InheritanceFlags,$ACE2Ref.PropagationFlags,$ACE2Ref.AccessControlType)

# ReCompose as NEW ACE Object
$ACE2Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACE2NewPermission)

## ACE 3 - Read/Write
# Fetch Ref. ACE Settings
$ACE3Ref = Import-Clixml .\OwnerTemp.xml
# SET New Identity Reference Value
$ACE3Ref.IdentityReference = $ACLGroupRW_Name

# Need to expand/refine this object config. PER -> https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
$ACE3NewPermission = ($ACE3Ref.IdentityReference,$ACE3Ref.FileSystemRights,$ACE3Ref.InheritanceFlags,$ACE3Ref.PropagationFlags,$ACE3Ref.AccessControlType)

# ReCompose as NEW ACE Object
$ACE3Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACE3NewPermission)



## Then ... we Grab the FOLDER ACL -- and ADD the New Rules -- And RETURN the Set to Folder

$TargetACLSet = Get-Acl $FldrItem

# 03.07.19 Updates: Deal with INHERITENCE, if it happens to be present
# TEST ? What happens if inher. IS NOT SET ??

$TargetACLSet.SetAccessRuleProtection($true,$true) # This sets inheritence to DISABLES, and then REMOVEs any propagation
Set-Acl $FldrItem -AclObject $TargetACLSet

# Call 2 - to clean up and set new
$TargetACLSet = Get-Acl $FldrItem
# Loop 
foreach ($TransACE in $TargetACLSet.Access) {
    Write-Host $TransACE.IdentityReference
    if ($TransACE.IdentityReference -eq "BUILTIN\Users") {$TargetACLSet.RemoveAccessRule($TransACE)}
}

# Add News

$TargetACLSet.AddAccessRule($ACE1Rule)
$TargetACLSet.AddAccessRule($ACE2Rule)
$TargetACLSet.AddAccessRule($ACE3Rule)

Set-Acl $FldrItem -AclObject $TargetACLSet

# REPORT Success !!

 
} ########################### END MASTER for EACH Folder Loop


### Now ... add that MASTER READ to the PARENT Folder!!
$PWD = Get-Location
$ACLGroupMASTERR_Name = "<DOMAIN>" + $MasterReadACLGroup

# Fetch Ref. ACE Settings
$ACEMRef0 = Import-Clixml .\MasterRTemp.xml # Read Only for the Users
$ACEMRef1 = Import-Clixml .\MAAdminTemp.xml # Global Admin FULL for Wintel Grp

## 1 - Draft ACE for the Master READ Entry

# SET New Identity Reference Value
$ACEMRef0.IdentityReference = $ACLGroupMASTERR_Name
# Need to expand/refine this object config. PER -> https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
$ACEMNewPermission0 = ($ACEMRef0.IdentityReference,$ACEMRef0.FileSystemRights,$ACEMRef0.InheritanceFlags,$ACEMRef0.PropagationFlags,$ACEMRef0.AccessControlType)
# ReCompose as NEW ACE Object
$ACEMRule0 = New-Object System.Security.AccessControl.FileSystemAccessRule($ACEMNewPermission0)

## 2 - Draft ACE for the Global Admin FULL Ctrl Entry

$ACEMRef1.IdentityReference = "<DOMAIN>ads--fs_admins"
# Need to expand/refine this object config. PER -> https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
$ACEMNewPermission1 = ($ACEMRef1.IdentityReference,$ACEMRef1.FileSystemRights,$ACEMRef1.InheritanceFlags,$ACEMRef1.PropagationFlags,$ACEMRef1.AccessControlType)
# ReCompose as NEW ACE Object
$ACEMRule1 = New-Object System.Security.AccessControl.FileSystemAccessRule($ACEMNewPermission1)



## 3 - Commit the new ACEs to the Parent Root Folder !



# Deal with INHERITENCE - if any
<#
    Here's the steps needed to clean up INHERITENCE and BUILTINs

    Get The ACL
    Disable the Inheritence Flag - If Set
        This Requires a SET ACL to commit
    Then, Get the ACL again - after setting Inheritence to Disabled

    With the 2nd call, you can loop thru and remove the BuiltIns

    Then - add your New ACEs, and Commit
#>

# Call 1 - to ENSURE Inheritence is NOT allowed
$TargetACLSet = Get-Acl $PWD.Path
$TargetACLSet.SetAccessRuleProtection($true,$true)
Set-Acl $PWD.Path -AclObject $TargetACLSet

# Call 2 - to clean up and set new
$TargetACLSet = Get-Acl $PWD.Path
foreach ($TransACE in $TargetACLSet.Access) {
    Write-Host $TransACE.IdentityReference
    if ($TransACE.IdentityReference -eq "BUILTIN\Users") {$TargetACLSet.RemoveAccessRule($TransACE)}
}

$TargetACLSet.AddAccessRule($ACEMRule0)
$TargetACLSet.AddAccessRule($ACEMRule1)
Set-Acl $PWD.Path -AclObject $TargetACLSet




## Somewhere, Clean up the Template XML Files
#Remove-Item .\RWTemp.xml -Force
Remove-Item .\MAAdminTemp.xml -Force
Remove-Item .\OwnerTemp.xml -Force
Remove-Item .\ROTemp.xml -Force
Remove-Item .\MasterRTemp.xml -Force

# Tell Ems!
Write-Host "OK! The thing has been done`n`nScript Will Now Exit" -ForegroundColor Green
Pause
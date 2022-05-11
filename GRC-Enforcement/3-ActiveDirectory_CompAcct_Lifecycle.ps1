# Public Cleared
<# 
Last Update: 02.26.19
This is an INTERACTIVE Script.
#>

#region JobInitiation

####################################################
####    Initalization, Variables, & Log Files   ####
####################################################

Start-Transcript -Path JobRunTranscript.log

Import-Module ActiveDirectory

[STRING]$GLOBAL:TimeStamp = Get-Date -Format "MM-dd-yy_HH-mm"
$UTCDateStampToday = [DateTime]::Today.ToUniversalTime().Ticks
# New Time Window Targets: DISABLE After 194days [~ 6 Months] | Delete after 273 [~ 9 months]
$UTCDateStampLess194Days = [DateTime]::Today.ToUniversalTime().AddDays(-194).Ticks # This is the CURRENT DISABLE time window
$UTCDateStampLess273Days = [DateTime]::Today.ToUniversalTime().AddDays(-273).Ticks # THEN this is the CURRENT DELETE Time Window
# 2 Weeks is for DISABLED Hold Window
$UTCDateStampLess2Weeks = [DateTime]::Today.ToUniversalTime().AddDays(-14).Ticks

# General Variables
$StaleAcctsMasterInv = @()
$Box = Get-ADDomainController -Discover -DomainName "<DFQDN>" | Select -Property "Hostname"
[STRING]$GLOBAL:DomainServer = $Box.hostname
$ThresholdCounter = 0 # Used for reporting/testing

# Logfiles
$GLOBAL:CompDataLog = ".\ComputerAccts_UserDataExport" + $TimeStamp + ".csv"
"AccountExpirationDate;accountExpires;CanonicalName;CN;Created;createTimeStamp;Deleted;Description;DisplayName;DistinguishedName;DNSHostName;Enabled;IPv4Address;IPv6Address;isCriticalSystemObject;isDeleted;LastKnownParent;LastLogonDate;lastLogonTimestamp;Location;LockedOut;ManagedBy;MemberOf;Modified;modifyTimeStamp;Name;ObjectCategory;ObjectClass;ObjectGUID;objectSid;OperatingSystem;OperatingSystemVersion;PasswordExpired;PasswordLastSet;PasswordNeverExpires;ProtectedFromAccidentalDeletion;pwdLastSet;SamAccountName;ServiceAccount;servicePrincipalName;ServicePrincipalNames;SID;whenChanged;whenCreated" | Add-Content $CompDataLog

$GLOBAL:ChangeACTIONsLog = ".\ComputerAccts_ChangeACTIONs" + $TimeStamp + ".log"
"Heading1;Heading2;Heading3;Heading4" | Add-Content $ChangeACTIONsLog
$GLOBAL:BitLockerLog = ".\ComputerAccts_BitLockerKeyExports" + $TimeStamp + ".log"
$CompLC_Cand_LogFile = "ORIG-Candidates-List" + $TimeStamp + ".log"
$DisabledListLog = ".\ComputerAccts_DisabledList" + $TimeStamp + ".log"
"Action;SamAccountName;CanonicalName;GUID;WhenCreated;LastLogonDate" | Add-Content $DisabledListLog
$DELETEDListLog = ".\ComputerAccts_DELETEDList" + $TimeStamp + ".log"
"Action;SamAccountName;CanonicalName;GUID;WhenCreated;LastLogonDate" | Add-Content $DELETEDListLog

####################################################
####                Functions                   ####
####################################################

function FullCompLog ($CompDataSAM)
{
	
	## SIMPLE Raw Log File Data Collection for ALL user Attributes
	
	[STRING]$RawDataLine = $null
	$RawDataLine = $CompData.AccountExpirationDate + ";" + $CompData.accountExpires + ";" + $CompData.CanonicalName + ";" + $CompData.CN + ";" + $CompData.Created + ";" + $CompData.createTimeStamp + ";" + $CompData.Deleted + ";" + $CompData.Description + ";" + $CompData.DisplayName + ";" + $CompData.DistinguishedName + ";" + $CompData.DNSHostName + ";" + $CompData.Enabled + ";" + $CompData.IPv4Address + ";" + $CompData.IPv6Address + ";" + $CompData.isCriticalSystemObject + ";" + $CompData.isDeleted + ";" + $CompData.LastKnownParent + ";" + $CompData.LastLogonDate + ";" + $CompData.lastLogonTimestamp + ";" + $CompData.Location + ";" + $CompData.LockedOut + ";" + $CompData.ManagedBy + ";" + $CompData.MemberOf + ";" + $CompData.Modified + ";" + $CompData.modifyTimeStamp + ";" + $CompData.Name + ";" + $CompData.ObjectCategory + ";" + $CompData.ObjectClass + ";" + $CompData.ObjectGUID + ";" + $CompData.objectSid + ";" + $CompData.OperatingSystem + ";" + $CompData.OperatingSystemVersion + ";" + $CompData.PasswordExpired + ";" + $CompData.PasswordLastSet + ";" + $CompData.PasswordNeverExpires + ";" + $CompData.ProtectedFromAccidentalDeletion + ";" + $CompData.pwdLastSet + ";" + $CompData.SamAccountName + ";" + $CompData.ServiceAccount + ";" + $CompData.servicePrincipalName + ";" + $CompData.ServicePrincipalNames + ";" + $CompData.SID + ";" + $CompData.whenChanged + ";" + $CompData.whenCreated
	$RawDataLine | Add-Content $CompDataLog
	
}

function LeafCleanUp ($CompDataSAM)
{
	# Expect an incoming SamAccountName value to work with; but also calling on GLOBAL CompData Attributes
	
	# Fetch Children Objects, if any
	[ARRAY]$ChildCheck = Get-ADObject -Filter * -SearchBase $CompData.DistinguishedName.ToString()
	
	if (($ChildCheck.Count -gt 1) -and ($CompData.enabled -eq $false))
	{
		
		Write-Host "Leaf objects FOUND on a Disabled Computer Account..."
		"Leaf objects FOUND (and function called) on Disabled Account..." + $CompData.Samaccountname | Add-Content $ChangeACTIONsLog
		[INT32]$ChildCt = $ChildCheck.Count
		
		# Cycle thru each child item and REMOVE it! - Oh ... and Export a copy of any BitLocker recovery keys
		# Note: increment starts at 1 as [0] is the COMPUTER Account
		
		for ($ii = 1; $ii -lt $ChildCt; $ii++)
		{
			#REPORT THIS
			Write-Host $ChildCheck[$ii].ToString()
			
			# Deal with BitLocker KEYs!!
			if ($ChildCheck[$ii].ObjectClass -eq "msFVE-RecoveryInformation") { Write-Host "BITLocker RECOVERY Key!" -ForegroundColor Red; Get-ADObject $ChildCheck[$ii].ObjectGuid -Properties msFVE-KeyPackage, msFVE-RecoveryGuid, msFVE-RecoveryPassword, msFVE-VolumeGuid, Name | Out-String | Add-Content $BitLockerLog }
			
			Remove-ADObject -Identity $ChildCheck[$ii].ToString() -Server $DomainServer -Confirm:$false
			"Deleteing: " + $ChildCheck[$ii].ToString() | Add-Content $ChangeACTIONsLog
		}
		
		Write-Host "Removing Computer " $CompData.DistinguishedName
		"Removing Computer " + $CompData.DistinguishedName | Add-Content $ChangeACTIONsLog
		Remove-ADComputer -Identity $CompData.DistinguishedName -Server $DomainServer -Confirm:$false
		
	} # End IF Children Present Check
	
} # End LeafCleanUp Function Container

#endregion

# Step 1 - Raw Candidate AD Query
# Returns ALL Computer Objects INACTIVE for 194 days --OR-- Never Logged On!!

Search-ADAccount -AccountInactive -Server $DomainServer -TimeSpan "194.00:00:00" -ComputersOnly | %{ $StaleAcctsMasterInv += $_.SamaccountName }
$StaleAcctsMasterInv | Out-File $CompLC_Cand_LogFile

# With Master Inventory, Loop Thru ALL Accounts
foreach ($Item in $StaleAcctsMasterInv)
{
	# START Master Account Loop
	Write-Host "Working on..." $Item
	$GLOBAL:CompData = Get-ADComputer -Identity $Item -Properties * -Server $DomainServer
	
	# Step 2.a - Check Protected Status
	## Filter for PROTECTED Accounts [This is Exceptions Filter 1 of 2] -->
	if (($CompData.isCriticalSystemObject -ne $true) -and ($CompData.ProtectedFromAccidentalDeletion -eq $false))
	{
		
		# 07.06 Update -->
		# Running Results --> Inactive 194 days (or NULL LastLogon) AND NOT Protected
		# Check for Disable Time Window; target is between 194-273 (although this will capture > 273 ENABLED objects); if TRUE .... DISABLE
		
		
		if (($CompData.LastLogonDate -lt $UTCDateStampLess194Days) -and ($CompData.whencreated.ticks -lt $UTCDateStampLess194Days) -and ($CompData.Enabled -eq $true))
		{
			
			# 7.6 UPDATE --> Conditions Met: Inactive, between 194--273 AND enabled
			# This is DISABLE Candidate
			
			# AND AND AND Accounts where LastLogonDate is NULL -- Returns Condition "Stale > 104 Days"
			# note; captures ALL accts at least 104 and enabled - this will incl. population > 180 days old and set to ACTIVE
			# outcome: 104 and older set to DISABLED... for revisit
			# RESULT: Disable & TimeStamp
			
			Write-Host "Computer " $CompData.SamAccountName " is within DISABLED window... Setting to DISABLED"
			FullCompLog $CompData.Samaccountname ## Prove this OUT
			"Disabled;" + $CompData.Samaccountname + ";" + $CompData.CanonicalName + ";" + $CompData.ObjectGUID + ";" + $CompData.WhenCreated + ";" + $CompData.LastLogonDate | Add-Content $DisabledListLog
			";;ACTION: " + $CompData.Samaccountname + " is > 104 Days Stale and ACTIVE - Setting to DISABLED & TimeStamping for future deletion" | Add-Content $ChangeACTIONsLog
			
			
			# TimeStamp Me & Disable Me
			#
			$DisabledMARK = "DISABLED:" + $UTCDateStampToday
			$CompData.description = $DisabledMARK
			$CompData.Enabled = $false
			Set-ADComputer -Instance $CompData -Server $DomainServer
			
		}
		
		else
		{
			
			# Step  - DELETE candidate (based on LastLogon & Created > 273 days old) AND Object is ALREADY Disabled
			# so: Object is DISABLED ... and at least 273 days LL / Creation
			
			if (($CompData.LastLogonDate -lt $UTCDateStampLess273Days) -and ($CompData.whencreated.ticks -lt $UTCDateStampLess273Days) -and ($CompData.Enabled -eq $false))
			{
				# Conditions: Inactive > 273 Days & Older than 273days & is DISABLED
				
				Write-Host "Computer " $CompData.SamAccountName " is candidate for DELETION"
				
				
				#IF timestamp MATCH; THEN Delete
				# IF timestamp NOT Match --- AND IGNORE is NOT True; do some stuff -- I don't know if we're going to care / use ignore validation ;;; as there is a 2 wk hold
				
				if ($CompData.Description -match '[D][I][S][A][B][L][E][D][:][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
				{
					# Timestamp FOUND; Compare for Completion of Holding Period (e.g. was account disabled over 14 days ago?)
					$ObjectTimeCompareBuffer = $CompData.Description | Select-String '[D][I][S][A][B][L][E][D][:][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
					$ObjectTimeCompare1 = $ObjectTimeCompareBuffer -replace "DISABLED:", ""
					
					if ($ObjectTimeCompare1 -lt $UTCDateStampLess2Weeks)
					{
						#Condition; TimeStamp Present on disalbed acct;;; AND the ts is OLDER than 2 Weeks - TIME FOR DELETE
						Write-Host "Object TimeStamp is OLDER than 2 weeks; Contine to DELETE Action... " $CompData.SamaccountName
						";;ACTION: DELETING Account " + $CompData.Samaccountname | Add-Content $ChangeACTIONsLog
						
						FullCompLog $CompData.Samaccountname ## Prove this OUT
						
						### NEED TO ADD IN A TRY / CATCH loop to second this out to Leaf Remove Function as needed | THis should incl. a MATCH on the Specific ERROR -- else report the Generic ERROR
						try
						{
							Remove-ADComputer -Identity $CompData.samaccountname -Server $DomainServer -Confirm:$false -ErrorAction Stop
							"Deleted;" + $CompData.Samaccountname + ";" + $CompData.CanonicalName + ";" + $CompData.ObjectGUID + ";" + $CompData.WhenCreated + ";" + $CompData.LastLogonDate | Add-Content $DELETEDListLog
						}
						
						catch
						{
							# Error Handeling - Check the ERROR Message Text ... and if it is Leaf -- Pass off to Leaf Function; Else just log it and move on
							
							if ($_.Exception.Message -match "leaf") { LeafCleanUp $CompData.SamAccountName }
							else { $_.Exception.Message | Add-Content $ChangeACTIONsLog }
						}
						
						
					}
					
					
				}
				
				
				if (($CompData.Description -notmatch '[D][I][S][A][B][L][E][D][:][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')`
                 -and($CompData.DistinguishedName -match "OU=DDC Disabled Objects"))
				{
					# Condition; Delete Candidate, Disabled, and NO TIMEStamp Present
					# There is NO TimeStamp; LOG this as an error/exception and DO Nothing; e.g. in the case of someone else setting user to disabled, etc.
					Write-Host "TimeStamp Validation Exception: Note " $CompData.SamaccountName
					";;INFO: TimeStamp Validation Exception: " + $CompData.SamaccountName + " is missing TimeStamp. Skipping..." | Add-Content $ChangeACTIONsLog
					
					## 02-2019 ... Let's make it go away ! Regardless
					## You'll need to deal with the leaf problem here as well !
					
					######if ($IGNORETSVALIDATION -eq $true)  # Old and Moldy
					######{   # Old and Moldy
					
					
					FullCompLog $CompData.Samaccountname ## Prove this OUT
					Write-Host "WARNING!! Ignoring TimeStamp Validation on DISABLED Account " $CompData.Samaccountname -ForegroundColor Yellow
					
					";;ACTION: Bypassing Timestamp Validation & trying DELETE --> " + $CompData.Samaccountname | Add-Content $ChangeACTIONsLog
					
					### NEED TO ADD IN A TRY / CATCH loop to second this out to Leaf Remove Function as needed | THis should incl. a MATCH on the Specific ERROR -- else report the Generic ERROR
					try
					{
						Remove-ADComputer -Identity $CompData.samaccountname -Server $DomainServer -Confirm:$false -ErrorAction Stop
						"Deleted;" + $CompData.Samaccountname + ";" + $CompData.CanonicalName + ";" + $CompData.ObjectGUID + ";" + $CompData.WhenCreated + ";" + $CompData.LastLogonDate | Add-Content $DELETEDListLog
					}
					
					catch
					{
						# Error Handeling - Check the ERROR Message Text ... and if it is Leaf -- Pass off to Leaf Function; Else just log it and move on
						
						if ($_.Exception.Message -match "leaf") { LeafCleanUp $CompData.SamAccountName }
						else { $_.Exception.Message | Add-Content $ChangeACTIONsLog }
					}
					
					
					
					######} # End of TS Validation OVER-RIDE !!   # Old and Moldy
					
					
					
				}
				
				
			}
			
		} ## END Disable Check ELSE Loop Segment; the intent is to SKIP all Deletion activity ... if the account required a DISABLE action FIRST
		
		
		
		
	}
	
	
	
	$ThresholdCounter += 1
	#if ($ThresholdCounter -gt 200) { Write-Host "Threshold Counter Pause..." -ForegroundColor Green; Pause; $ThresholdCounter = 0 }
	
	# END Master Account Loop
}




#Convert The Running LogFiles

$FinalChangeActionsLogFile = "FinalChangeActionsLog" + $TimeStamp + ".csv"

$ActionRPTFinal = Import-Csv $ChangeACTIONsLog -Delimiter ";"
$ActionRPTFinal | Export-Csv -NoTypeInformation -Path $FinalChangeActionsLogFile

## LogFile Management - Simple Inventory Report

$SimpleInvReport1 = Import-Csv -Path $DisabledListLog -Delimiter ";"
$SimpleInvReport2 = Import-Csv -Path $DELETEDListLog -Delimiter ";"
$SimpleInvReportCombined = $SimpleInvReport1 + $SimpleInvReport2
$SimpleInvReportFILE = ".\ComputerAccts_SimpleInventoryReport" + $TimeStamp + ".csv"
$SimpleInvReportCombined | Export-Csv -Path $SimpleInvReportFILE -NoTypeInformation


$CompDataLogTransLate = Import-Csv $CompDataLog -Delimiter ";"
$CompDataLogTransLateFN = "ComputerUserDataExport" + $TimeStamp + ".csv"
$CompDataLogTransLate | Export-Csv -Path $CompDataLogTransLateFN -NoTypeInformation
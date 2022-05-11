# Public Cleared
<# 

Prod Run Job for <DOMAIN> Domain
Last Update 01.09.20

Schedule Version is for TIDAL Install!!

ToDO: Add Null Check when acconut LastLogonDate is "Less Than" = TRUE for users where LastLogonDate is $null

09.01.15 Change: Traded Explicit DN filter; Removed "shared mailbox" and inserted "messaging"
09.23.15 Change: Added a "LastLogonDate -eq $Null" check for the interm DISABLE

03.01.18: Tidal Sucks - so we need to change the FullUserLog function to OUTPUT to an Array; which gets dumped in ONE CALL at end of job
. this is because Tidal worker is on PS Version 2.0 - and cannot use the "-Append" switch

11-2019 -> Expand this job, to ALSO deal with accounts that come online as 'Password Not Required'
    Find them
    Try to toggle the flag (regardless of enabled status)
    REPORT on activity, and CAN'T CHANGE objects

#>

#region JobInitiation

# Modules & VARs Initalization
Import-Module ActiveDirectory
$env:PWSValidation = "<ID>"
[STRING]$TimeStamp = Get-Date -Format "MM-dd-yy_HH-mm"
$UTCDateStampToday = [DateTime]::Today.ToUniversalTime().Ticks
$UTCDateStampLess2Month = [DateTime]::Today.ToUniversalTime().AddMonths(-2).Ticks
$UTCDateStampLess2Weeks = [DateTime]::Today.ToUniversalTime().AddDays(-15).Ticks
$UTCDateStampLess120Days = [DateTime]::Today.ToUniversalTime().AddDays(-120).Ticks
$UTCDateStampLess15Month = [DateTime]::Today.ToUniversalTime().AddMonths(-15).Ticks

# Master Functions File Include
$emailtocc = "<SVC ACCT>"
[STRING]$ChainBuild1 = . .\Functions.exe
$ADDSSetup1 = $ChainBuild1 | ConvertTo-SecureString -AsPlainText -Force
$ADDSSetup2 = $emailtocc -Split "@"
[STRING]$ADDSSetup3 = "<DOMAIN>\" + $ADDSSetup2[0]
$ADDSEntry = New-Object System.Management.Automation.PSCredential($ADDSSetup3, $ADDSSetup1)

# Logfiles
$GLOBAL:UserDataLog = ".\C1F1_DDC_NEWFORMATUserDataExport" + $TimeStamp + ".csv.txt"
$ChangeACTIONsLog = ".\C1F1_DDC_ChangeACTIONs" + $TimeStamp + ".log"
$GroupMembershipLog = ".\C1F1_DDC_GroupMemberships" + $TimeStamp + ".log"

# Temp Addl. Reporting Files
$DisabledListLog = ".\C1F1_DDC_DisabledList" + $TimeStamp + ".log"
$DELETEDListLog = ".\C1F1_DDC_DELETEDList" + $TimeStamp + ".log"
"Action;SamAccountName;CanonicalName;GUID;WhenCreated;LastLogonDate" | Add-Content $DisabledListLog
"Action;SamAccountName;CanonicalName;GUID;WhenCreated;LastLogonDate" | Add-Content $DELETEDListLog

# Master Candidate Account Inventory VAR
$StaleAcctsMasterInv = @()
$DomainServer = "DC.<DOMAIN><DDC>"

"Heading1;Heading2;Heading3;Heading4" | Add-Content $ChangeACTIONsLog

$GLOBAL:DeleteLogQueue = @() #This holds FULL User Log Info - until end of script; it is called by the FullUserLog function

#endregion

#Functions
function FullUserLog ($UserDataSAM) {
	# This is an updated function that uses CSV Row objects instead of attribute level 'Add-Content' calls
	[STRING]$RawDataLine = $null
	$RawDataLine = $userdata | Out-String
	
	$NewRow = New-Object -TypeName psobject
	$NewRow | Add-Member -MemberType NoteProperty -Name "samaccountname" -Value $UserData.samaccountname.ToString()
	$NewRow | Add-Member -MemberType NoteProperty -Name "userdataexport" -Value $RawDataLine
	#$NewRow | Export-Csv -NoTypeInformation -Append -LiteralPath $UserDataLog
	$GLOBAL:DeleteLogQueue += $NewRow
	
	"UserName: " + $UserData.samaccountname + ";MemberOf: " + $UserData.Memberof | Add-Content $GroupMembershipLog
}



# Step 1 - Gather All Potential Candidate Acccounts - Returns ALL user objects that have been inactive for 120 days (w/ 14 day buffer)
Search-ADAccount -AccountInactive -Server $DomainServer -TimeSpan "134.00:00:00" -UsersOnly -Credential $ADDSEntry | % { $StaleAcctsMasterInv += $_.SamaccountName }

# With Master Inventory, Loop Thru ALL Accounts
foreach ($Item in $StaleAcctsMasterInv) {
	# START Master Account Loop
	
	$GLOBAL:UserData = Get-ADUser -Identity $Item -Properties * -Server $DomainServer -Credential $ADDSEntry
	"Working On User: " + $UserData.SamAccountName | Add-Content $ChangeACTIONsLog
	# ALL Full User Data Export Needs to be moved to "ACTION" Areas | This Should be converted into a function
	# See Function Above - Before start of MASTER loop
	
	# Step 2.a - Check Protected Status
	## Filter for PROTECTED Accounts [This is Exceptions Filter 1 of 2] -->
	if (($UserData.isCriticalSystemObject -ne $true) -and ($UserData.ProtectedFromAccidentalDeletion -eq $false)) {
		
		# Step 2.b - Filter out known/intended Exceptions

		if (($UserData.DistinguishedName -notmatch "ServiceAccount") -and ($UserData.DistinguishedName -notmatch "Service Account")`
				-and ($UserData.DistinguishedName -notmatch "microsoft exchange") -and ($UserData.DistinguishedName -notmatch "messaging")`
				-and ($UserData.DistinguishedName -notmatch "secure") -and ($UserData.DistinguishedName -notmatch "quest") -and ($UserData.DistinguishedName -notmatch "OU=Hadoop")`
				-and ($UserData.DistinguishedName -notmatch "CN=Users,DC=<DOMAIN>,<DDC>")) {
			
			# Step 3 - Is this a DISABLE Candidate where LastLogonDate > 134 but < 471 | Note... what happens to ALREADY Disabled?? - Think this will get managed in DELETE Phase
			
			if (($UserData.LastLogonDate -gt $UTCDateStampLess15Month) -and ($UserData.whencreated.ticks -lt $UTCDateStampLess120Days) -and ($UserData.Enabled -eq $true)) {
				
				# Conditions MET: *Stale between 120-470, *At LEAST 120 Days Old, *Currently ENABLED, & *NOT Protected
				# RESULT: This Get's DISABLED
				
				"Disabled;" + $UserData.Samaccountname + ";" + $UserData.CanonicalName + ";" + $UserData.ObjectGUID + ";" + $UserData.WhenCreated + ";" + $UserData.LastLogonDate | Add-Content $DisabledListLog
				";;ACTION: " + $UserData.Samaccountname + " is between 120-471 Days Stale - Setting to DISABLED" | Add-Content $ChangeACTIONsLog
				FullUserLog $UserData.Samaccountname
				# SET Actions on the User Account -->
				
				$DisabledMARK = "DISABLED:" + $UTCDateStampToday
				$UserData.info = $DisabledMARK
				$UserData.Enabled = $false
				Set-ADUser -Instance $UserData -Server $DomainServer -Credential $ADDSEntry
				
				# Note... if it is Old... but ALREADY Disabled... I don't need to do anything here as I will Filter within the DELETE Candidate Processing
				
			}
			
			
			## 09.23 LastLogon NULL Check Add-In -->
			## GRC Group MbrShip Check !! This is NOT IN PRD - 09.23.15; Used for LastLogonDate as NULL Compare
			$MembershipChkString = $null
			$MembershipChkString = $UserData.MemberOf | Out-String
			if (($UserData.LastLogonDate -eq $null) -and ($UserData.whencreated.ticks -lt $UTCDateStampLess120Days) -and ($UserData.Enabled -eq $true) -and ($MembershipChkString -notmatch "GRC-")) {
				
				# Conditions MET: *Stale unknown as LastLogon is NULL, *At LEAST 120 Days Old, *Currently ENABLED, & *NOT Protected
				# RESULT: This Get's DISABLED
				
				Write-Host "DISABLED" $UserData.SamaccountName
				"Disabled;" + $UserData.Samaccountname + ";" + $UserData.CanonicalName + ";" + $UserData.ObjectGUID + ";" + $UserData.WhenCreated + ";" + $UserData.LastLogonDate | Add-Content $DisabledListLog
				";;ACTION: " + $UserData.Samaccountname + " is between 120-471 Days Stale and NEVER LOGGED ON - Setting to DISABLED" | Add-Content $ChangeACTIONsLog
				
				# SET Actions on the User Account -->
				
				$DisabledMARK = "DISABLED:" + $UTCDateStampToday
				$UserData.info = $DisabledMARK
				$UserData.Enabled = $false
				Set-ADUser -Instance $UserData -Server $DomainServer -Credential $ADDSEntry
				
			}
			
			
			# Step 4 - Is this a DELETE Candidate Where LastLogonDate > 471
			
			
			# DELETE Candidate AND is Enabled; Disable & TimeStamp
			if (($UserData.LastLogonDate -lt $UTCDateStampLess15Month) -and ($UserData.whencreated.ticks -lt $UTCDateStampLess15Month) -and ($UserData.Enabled -eq $true)) {
				
				# Conditions MET: *Stale > than 470 (OLD), *At LEAST 15 Months Old, *Currently ENABLED, & *NOT Protected
				# AND AND AND Accounts where LastLogonDate is NULL -- Returns Condition "Stale > 470 Days"
				# RESULT: Disable & TimeStamp
				
				"Disabled;" + $UserData.Samaccountname + ";" + $UserData.CanonicalName + ";" + $UserData.ObjectGUID + ";" + $UserData.WhenCreated + ";" + $UserData.LastLogonDate | Add-Content $DisabledListLog
				";;ACTION: " + $UserData.Samaccountname + " is > 470 Days Stale - Setting to DISABLED & TimeStamping for future deletion" | Add-Content $ChangeACTIONsLog
				FullUserLog $UserData.Samaccountname
				
				# TimeStamp Me & Disable Me
				
				$DisabledMARK = "DISABLED:" + $UTCDateStampToday
				$UserData.info = $DisabledMARK
				$UserData.Enabled = $false
				Set-ADUser -Instance $UserData -Server $DomainServer -Credential $ADDSEntry
				
			}
			
			# DLETE w/ Disable check T !! Add In TS Validation w/ FLAG OVERRIDE AND Disabled- check for ticks -- and do some stuff
			
			if (($UserData.LastLogonDate -lt $UTCDateStampLess15Month) -and ($UserData.whencreated.ticks -lt $UTCDateStampLess15Month) -and ($UserData.Enabled -eq $false)) {
				# Conditions: Inactive > 471 Days & Older than 15 Months & is Disabled
				# NOTE: Timestamp Validation is necessary to accomidate Disable holding period as we phase lifecycle in; else it will DELETE previously disabled too soon (on very next run)
				
				#IF timestamp MATCH; THEN Delete
				# IF timestamp NOT Match --- AND IGNORE is NOT True; do some stuff -- I don't know if we're going to care / use ignore validation ;;; as there is a 2 wk hold
				
				if ($UserData.Info -match '[D][I][S][A][B][L][E][D][:][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') {
					# Timestamp FOUND; Compare for Completion of Holding Period (e.g. was account disabled over 14 days ago?)
					$ObjectTimeCompareBuffer = $UserData.Info | Select-String '[D][I][S][A][B][L][E][D][:][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
					$ObjectTimeCompare1 = $ObjectTimeCompareBuffer -replace "DISABLED:", ""
					
					if ($ObjectTimeCompare1 -lt $UTCDateStampLess2Weeks) {
						#Condition; TimeStamp Present on disalbed acct;;; AND the ts is OLDER than 2 Weeks - TIME FOR DELETE
						";;ACTION: DELETING Account " + $UserData.Samaccountname | Add-Content $ChangeACTIONsLog
						FullUserLog $UserData.Samaccountname
						
						## OLD CALL -> Remove-ADUser -Identity $UserData.samaccountname -Server $DomainServer -Confirm:$false -Credential $ADDSEntry
						Remove-ADObject -Identity $UserData.ObjectGuid -Recursive -Server $DomainServer -Confirm:$false -Credential $ADDSEntry
						if ($Error.count -gt 0) { $Error[0] | Add-Content $ChangeACTIONsLog; $Error.Clear() }
						
						"Deleted;" + $UserData.Samaccountname + ";" + $UserData.CanonicalName + ";" + $UserData.ObjectGUID + ";" + $UserData.WhenCreated + ";" + $UserData.LastLogonDate | Add-Content $DELETEDListLog
						
					}
					
					
				}
				
				
				if ($UserData.Info -notmatch '[D][I][S][A][B][L][E][D][:][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') {
					# Condition; Delete Candidate, Disabled, and NO TIMEStamp Present
					# There is NO TimeStamp; LOG this as an error/exception and DO Nothing; e.g. in the case of someone else setting user to disabled, etc.
					
					# Jan 2018 CHANGE -> Copied the TimeStamp Matching Action HERE - WE don't need this validation anymore
                    
					## LEGACY Aciton ";;INFO: TimeStamp Validation Exception: " + $UserData.SamaccountName + " is missing TimeStamp. Skipping..." | Add-Content $ChangeACTIONsLog
					";;INFO: TimeStamp Validation Exception: " + $UserData.SamaccountName + " is missing TimeStamp. Deleting ANYWAY!!" | Add-Content $ChangeACTIONsLog
					";;ACTION: DELETING Account " + $UserData.Samaccountname | Add-Content $ChangeACTIONsLog
					FullUserLog $UserData.Samaccountname
						
					## OLD Call -> Remove-ADUser -Identity $UserData.samaccountname -Server $DomainServer -Confirm:$false -Credential $ADDSEntry
					Remove-ADObject -Identity $UserData.ObjectGuid -Recursive -Server $DomainServer -Confirm:$false -Credential $ADDSEntry
					if ($Error.count -gt 0) { $Error[0] | Add-Content $ChangeACTIONsLog; $Error.Clear() }
						
					"Deleted;" + $UserData.Samaccountname + ";" + $UserData.CanonicalName + ";" + $UserData.ObjectGUID + ";" + $UserData.WhenCreated + ";" + $UserData.LastLogonDate | Add-Content $DELETEDListLog
					
				}
				
				
				### What does the LastLogonDate COMP Return when the value is 0 or NOT PRESENT; Job is currently using BOOL operators
				## When is is $null; Returns <0 as TRUE [and >0 as FALSE]
			}
			
			
		}
		
	}
	
	# END Master Account Loop
}

###############
###############
#
#
#
#     QUICK FIX - For the '<DABRV> Disabled Objects' OU
#     Added Jan 2018
#
###############
###############

# Make a statement in the running logfile - "Starting <DABRV> Disabled Objects Container Trim..." via | Add-Content $ChangeACTIONsLog
"Version 1 Processing Completed!`nStarting <DABRV> Disabled Objects Container Trim..." | Add-Content $ChangeACTIONsLog

# Collect ALL Disabled within the '<DABRV> Disabled Objects' OU
$DISOUInvMaster = @()
Search-ADAccount -AccountInactive -Server $DomainServer -TimeSpan "365.00:00:00" -UsersOnly -SearchBase "OU=<DABRV> Disabled Objects,DC=<DOMAIN>,<DDC>" -SearchScope Subtree -Credential $ADDSEntry | % { $DISOUInvMaster += $_.SamaccountName }

# Trim these based on LASTLOGONTIMESTAMP data - we want ones with no activity in 15+ months
# So - REPLICATE the ENTIRE ForEach Account loop from Version 1 -- REMOVING the TimeStamp Validation
# ? What was the "Null LastLogon" note above - all about ?

# With Master Inventory, Loop Thru ALL Accounts
foreach ($Item in $DISOUInvMaster) {
	# START Master Account Loop
	$GLOBAL:UserData = Get-ADUser -Identity $Item -Properties * -Server $DomainServer -Credential $ADDSEntry
	"Working On User: " + $UserData.SamAccountName | Add-Content $ChangeACTIONsLog
	
	# Check Protected Status
	## Filter for PROTECTED Accounts [This is Exceptions Filter 1 of 2] -->
	if (($UserData.isCriticalSystemObject -ne $true) -and ($UserData.ProtectedFromAccidentalDeletion -eq $false)) {
		
		# Step 2.b - Filter out known/intended Exceptions
		if (($UserData.DistinguishedName -notmatch "ServiceAccount") -and ($UserData.DistinguishedName -notmatch "Service Account") -and ($UserData.DistinguishedName -notmatch "microsoft exchange") -and ($UserData.DistinguishedName -notmatch "messaging") -and ($UserData.DistinguishedName -notmatch "secure") -and ($UserData.DistinguishedName -notmatch "quest")) {
			
			# DELETE ACTION ON INACTIVE > 471 Days AND Disabled
			# --> 
			
			if (($UserData.LastLogonDate -lt $UTCDateStampLess15Month) -and ($UserData.whencreated.ticks -lt $UTCDateStampLess15Month) -and ($UserData.Enabled -eq $false)) {
				# Conditions: Inactive > 471 Days & Older than 15 Months & is Disabled
				
				";;ACTION: DELETING Account " + $UserData.Samaccountname | Add-Content $ChangeACTIONsLog
				FullUserLog $UserData.Samaccountname
				
				Remove-ADUser -Identity $UserData.samaccountname -Server $DomainServer -Confirm:$false -Credential $ADDSEntry
				
				if ($Error.count -gt 0) {
					
					if ($Error[0].exception.message -match "requested operation only on a leaf object") {
						
						# This has chidlren - try again with a Recursive call!
						try {
							Remove-ADObject -Identity $UserData.ObjectGuid -Recursive -Server $DomainServer -Confirm:$false -Credential $ADDSEntry -ErrorAction Stop
							$Error.Clear()
						}
						
						catch {
							# Had children - and the recursive call failed - Just log it and move on!
							$Error[0] | Add-Content $ChangeACTIONsLog
							$Error.Clear()
						}
					}
					
					else {
						# Some other weird issue - Log it!
						$Error[0] | Add-Content $ChangeACTIONsLog; $Error.Clear()
					}
				}
				
				"Deleted;" + $UserData.Samaccountname + ";" + $UserData.CanonicalName + ";" + $UserData.ObjectGUID + ";" + $UserData.WhenCreated + ";" + $UserData.LastLogonDate | Add-Content $DELETEDListLog
				
				
			}
			
		}

	}
	# End of the master FOR EACH Account Loop	
}


#Convert The Running LogFiles
$FinalChangeActionsLogFile = ".\C1F1_DDC_FinalChangeActionsLog" + $TimeStamp + ".csv"

$ActionRPTFinal = Import-Csv $ChangeACTIONsLog -Delimiter ";"
$ActionRPTFinal | Export-Csv -NoTypeInformation -Path $FinalChangeActionsLogFile

## LogFile Management - Simple Inventory Report

$SimpleInvReport1 = Import-Csv -Path $DisabledListLog -Delimiter ";"
$SimpleInvReport2 = Import-Csv -Path $DELETEDListLog -Delimiter ";"
$SimpleInvReportCombined = $SimpleInvReport1 + $SimpleInvReport2
$SimpleInvReportFILE = ".\C1F1_SimpleInventoryReport" + $TimeStamp + ".csv"
$SimpleInvReportCombined | Export-Csv -Path $SimpleInvReportFILE -NoTypeInformation

# Define the LogFile
$UserDataLog = "C1F1_DDC_NEWFORMATUserDataExport" + $TimeStamp + + ".csv.txt"
$GLOBAL:DeleteLogQueue | Export-Csv -Path $UserDataLog -NoTypeInformation


###############
###############
#
#
#
#     Password Not Required - Remediation Steps
#     Added Nov 2019
#
###############
###############

# Setup some more log files - for this section
$PWDnrListLog = ".\C1F1_DDC_PWDNotReq_Processing" + $TimeStamp + ".log"
"Action-Result;GUID;Details(if any)" | Add-Content $PWDnrListLog

# Collect the DOMAIN's "Password Not Required" Inventory
$NREnStartRAW = Get-ADUser -Filter { (PasswordNotRequired -eq $true) } -Properties PasswordNotRequired, IsCriticalSystemObject -Server $DomainServer -Credential $ADDSEntry
# Trim out some important things
$NREnStart = $NREnStartRAW | Where IsCriticalSystemObject -ne "True"

# Dump CANDIDATEs to CSV - for historical Record
$PWDnrListInven = ".\C1F1_DDC_PWDNotReq_CandidateList" + $TimeStamp + ".csv"
$NREnStart | Export-Csv $PWDnrListInven -NoTypeInformation


foreach ($Target in $NREnStart) {

	Try {
		Set-ADUser -Identity $Target.ObjectGuid -PasswordNotRequired $false -Server $DomainServer -Credential $ADDSEntry -ErrorAction Stop
		"SUCCESS - Set PWD Flag;" + $Target.ObjectGuid + ";" | Add-Content $PWDnrListLog
	}

	catch {
		"ERROR - Trying to Set PWD Flag;" + $Target.ObjectGuid + ";" + $Error[0].Exception.Message | Add-Content $PWDnrListLog
	}

}




# Global Response to the Tidal Service/log
Write-Host "Completed Script Successfully"
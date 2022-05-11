# Public Cleared
# Last Update: Apr. 18, 2022
########################
# Section 1 of 6: Setup some initial things
# 
# What is Does:
#   gather service account credentials
#   set log file names / dates
#   GET SOURCE DATA FROM ServiceNow, and the Identity Map flat-file
#
########################
#regionSTARTUP
$MyAccess = Get-Credential("<USERNAME>")
[STRING]$ChainBuild1 = Read-Host("WhatSayYou") # again, for INTERACTIVE job runs

################################################
# Setup logfile(s)
################################################
$RunTimeStamp = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ChangeLogfile = "HardeningGrpMgr-Changelog- " + $RunTimeStamp + ".txt"
$newIDMapFileExpName = "IdentityMap_" + $RunTimeStamp + ".json.txt"

################################################
# GET Identity Map - from the flat file
################################################    
$mapLSsrc = Get-ChildItem IdentityMap_*
$mapLS = $mapLSsrc | sort "name"
[STRING]$TargetIDMapFile = $mapLS[($mapLS.Count - 1)].name
$IDMAPSrc = Get-Content $TargetIDMapFile
[ARRAY]$IDMAP = $IDMAPSrc | Convertfrom-JSON




################################################
# GET all the info from ServiceNow - total of 3 files needed
################################################
if (Test-Path "SvcNow-ServerCI-InvSrc.csv") { Remove-Item "SvcNow-ServerCI-InvSrc.csv" }
if (Test-Path "SVCNOW-APP-CIs-Export.json.txt") { Remove-Item "SVCNOW-APP-CIs-Export.json.txt" }
if (Test-Path "SVCNOW-subAPP-CIs-Export.json.txt") { Remove-Item "SVCNOW-subAPP-CIs-Export.json.txt" }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient
$credCache = new-object System.Net.CredentialCache
$creds = new-object System.Net.NetworkCredential("<USERNAME>", $ChainBuild1)
$credCache.Add("https://<TENANTNAME>.service-now.com/", "Basic", $creds)
$wc.Credentials = $credCache
$wc.Headers.Add("Accept", "application/json");
# fetch explicit working directory - to avoid errors with WebClient downloads, save location; WebClient doesn't like dynamically mapped PSDrive locations
$fileNameTst = (pwd).ProviderPath.ToString()
$wc.DownloadFile("https://<TENANTNAME>.service-now.com/sys_report_template.do?CSV&jvar_report_id=fddba41b87187c902e1dc9d7cebb35d8", "$fileNameTst\SvcNow-ServerCI-InvSrc.csv") # New Report as of May 2021
$wc.DownloadFile("https://<TENANTNAME>.service-now.com/api/now/table/cmdb_ci_appl?sys_class_name=cmdb_ci_appl", "$fileNameTst\SVCNOW-APP-CIs-Export.json.txt")
$wc.DownloadFile("https://<TENANTNAME>.service-now.com/api/now/table/u_sub_applications", "$fileNameTst\SVCNOW-subAPP-CIs-Export.json.txt")
$wc.Dispose();

$SvrCItoAppMap = Import-Csv "SvcNow-ServerCI-InvSrc.csv" -Encoding Default


################################################
# Setup a function - to make new group creations easier
################################################

function createNewGroup {
    param(
        [Parameter(Mandatory = $true)]
        [STRING]$AppSYSid,
        [Parameter(Mandatory = $true)]
        [STRING]$AppCiDispName,
        [Parameter(Mandatory = $true)]
        [STRING]$EnvParam,
        [Parameter(Mandatory = $true)]
        [PSCredential]$MyAccess
    )
            
    try {
        [STRING]$CompE1 = ($AppCiDispName -replace '[^a-zA-Z0-9]', '')
        $CompE1 = $CompE1.ToLower()
        
        [STRING]$MyNextNewGrpName = "gpo-ENT-SHA-" + $EnvParam + "_" + $CompE1
    
        ## MAX LEN is 64 chars  - ask me how I know : )
        ## This means -- children apps with the same name will end up in the VERY FIRST GROUP CREATED; deal with this as needed 
        if ($MyNextNewGrpName.Length -gt 64) {
            # Shimmy this down - to 64 len.
            [STRING]$MyNextNewGrpName = $MyNextNewGrpName.Substring(0, 64)
        }    
        
        Write-Host "Trying to create new group  -> " $MyNextNewGrpName -ForegroundColor Yellow
    
     
        ## Create a New Group - can capture GuiD
        $CreateGrpCall = ""
        [STRING]$DispNameStr = $AppCiDispName
        [STRING]$DescNotesStr = "SVCNOWSYSID_SHA:" + $AppSYSid
        [STRING]$infoNotesStr = $AppCiDispName
        
        # IF - the IDMAP ever gets jacked (or crazy people make the same groups) - You'll get a duplicate error here
        # when that happens - might have to go back in time - thru IDMap files ... for resolution

        $CreateGrpCall = New-ADGroup $MyNextNewGrpName -SamAccountName $MyNextNewGrpName -DisplayName $DispNameStr `
            -Description $DescNotesStr -GroupScope DomainLocal -OtherAttributes @{info = "$infoNotesStr" } -Path "OU=tstOU,<DOMAIN DN>" `
            -ErrorAction Stop -Credential $MyAccess -PassThru
    
    }

    catch {

        if ($error[0].exception.message -match "group already exists") {
            # Correct for mistakes in my ID MAP; just send back the existing daters
            $prvsThereGrp = Get-ADGroup $MyNextNewGrpName -Credential $MyAccess
            return @{status = "success"; name = $prvsThereGrp.name; results = $prvsThereGrp.objectGuid }

        }
        else {
            # All other "Group Create" Errors
            [STRING]$ErrDaters = $error[0].exception.message
            Write-Host "error occured within the CreateGroup funciton call -> `n" $ErrDaters -ForegroundColor Red
            pause
            return @{status = "failure"; results = $ErrDaters }
        }
    }


    return @{status = "success"; name = $CreateGrpCall.name; results = $CreateGrpCall.objectGuid }

}

#endregion



########################
# Section 2 of 6: Add Any NEW - Application CIs - to the Identity Map
# 
# What is Does:
#   if new stuff has been created in ServiceNow since the last job run
#   add the details to the Identity Map - in memory
#   If - no new apps - then ... it doesn't do anything
#
########################

#regionParseNEWAPPs
$AppsTBLsrc = Get-Content "SVCNOW-APP-CIs-Export.json.txt" -Encoding UTF8
$AppsTBLall = $AppsTBLsrc | ConvertFrom-JSON
$AppsTBL = $AppsTBLall.result | Where "install_status" -ne 7 # trim the results, because '7' means RETIRED

$SubAppsTBLsrc = Get-Content "SVCNOW-subAPP-CIs-Export.json.txt" -Encoding UTF8
$SubAppsTBLall = $SubAppsTBLsrc | ConvertFrom-JSON
$SubAppsTBL = $SubAppsTBLall.result | Where "install_status" -ne 7 # trim the results, because '7' means RETIRED

# Also - Grab a consolidated NAME DIFF - that includes RETIRED
$namediffSvcNowJSONSrc = @()
$namediffSvcNowJSONSrc += $AppsTBLall.result ## Includes Retired
$namediffSvcNowJSONSrc += $SubAppsTBLall.result ## Includes Retired

# compare (parent)APPCIs to IDMAP based on sys_ID - and PROCEED with <-ON-LEFT-but-NOT-on-RIGHT<-
# VERY-FIRST-RUN_only ->  $NewAPPsListCompSrc = compare $AppsTBL.sys_id ""
$NewAPPsListCompSrc = compare $AppsTBL.sys_id $IDMAP.app_sys_id
$NewAPPsListDIFF = $NewAPPsListCompSrc | Where "sideIndicator" -eq "<="

# compare subAPPCIs to IDMAP based on sys_ID - and PROCEED with <-ON-LEFT-but-NOT-on-RIGHT<-
# VERY-FIRST-RUN_only ->  $NewsubAPPsListCompSrc = compare $SubAppsTBL.sys_id ""
$NewsubAPPsListCompSrc = compare $SubAppsTBL.sys_id $IDMAP.app_sys_id
$NewsubAPPsListDIFF = $NewsubAPPsListCompSrc | Where "sideIndicator" -eq "<="

# Refactor - this into a SINGLE list / SINGLE loop at some point
# Two loops is unnecessary; compare to the APP RENAME validation steps for reference of combined steps


foreach ($HappyNewROOTApp in $NewAPPsListDIFF.inputObject) {

    $TheCurRTarget = ""
    $TheCurRTarget = $AppsTBL | Where "sys_id" -eq $HappyNewROOTApp

    Write-Host "Time to get down to business -> " $TheCurRTarget.name -ForegroundColor Yellow
    Write-Host " -> " $TheCurRTarget.sys_id -ForegroundColor Yellow
        
    # Add to ID Map
    $newmapEntry = ""
    
    $newmapEntry = New-Object -TypeName PSObject
    $newmapEntry | Add-Member -MemberType NoteProperty -Name "app_sys_id" -Value $TheCurRTarget.sys_id
    $newmapEntry | Add-Member -MemberType NoteProperty -Name "current_display_name" -Value $TheCurRTarget.name
    $newmapEntry | Add-Member -MemberType NoteProperty -Name "AD_Groups_ARRAY" -Value $null # This Gives me a .COUNT -eq 0

    $IDMAP += $newmapEntry

}

foreach ($HappyNewChildApp in $NewsubAPPsListDIFF.inputobject) {
    
    $TheCurRTarget = ""
    $TheCurRTarget = $SubAppsTBL | Where "sys_id" -eq $HappyNewChildApp

    Write-Host "Time to get down to business -> " $TheCurRTarget.name -ForegroundColor Yellow
    Write-Host " -> " $TheCurRTarget.sys_id -ForegroundColor Yellow
        
    # Add to ID Map
    
    $newmapEntry = ""
    
    $newmapEntry = New-Object -TypeName PSObject
    $newmapEntry | Add-Member -MemberType NoteProperty -Name "app_sys_id" -Value $TheCurRTarget.sys_id
    $newmapEntry | Add-Member -MemberType NoteProperty -Name "current_display_name" -Value $TheCurRTarget.name
    $newmapEntry | Add-Member -MemberType NoteProperty -Name "AD_Groups_ARRAY" -Value $null # This Gives me a .COUNT -eq 0

    $IDMAP += $newmapEntry

}

#endregionParseNEWAPPs



########################
# Section 3 of 6: Check - the Display Names of ALL Application CIs
# 
# What is Does:
#   Since the last job run - some App Names might have changed
#   if so - update the Identity Map, to the NEW name(s)
#   this is REQUIRED, because the server to app info runs ONLY based on App Display Name
#
########################
#regionUpdateDispNames
# ok - NOW - revisit names ... because Paul is trying to ruin my life

foreach ($appEntity in $IDMAP) {

    Write-Host "Checking display name for: " $appEntity -ForegroundColor Green

    $curSVCNOWDeets = $null

    $curSVCNOWDeets = $namediffSvcNowJSONSrc | Where-Object "sys_id" -eq $appEntity."app_sys_id"

    if ($curSVCNOWDeets -eq $null) {
        Write-Host "PROBLEM - trying to compare Display Names" -ForegroundColor Red
        Pause
    }


    # fix non-Matching
    else {
        # Only update - if a match was found; otherwise - just skip the problem
        if ($appEntity.current_display_name -ne $curSVCNOWDeets.name) {
            # Update the IDMAP content !! - this will get exported to a NEW json map at end
            Write-Host "a Display Name is different - updating ID Map! "
            Write-Host $appEntity
            Write-Host "New Name of - " $curSVCNOWDeets.name
            #Pause
    
            # UPDATE - the IDMAP Entry

            $ActualMapIdx = ""; $ActualMapIdx = ($IDMAP.app_sys_id).IndexOf($appEntity.app_sys_id)
            $IDMAP[$ActualMapIdx].current_display_name = $curSVCNOWDeets.name


        }
    }

}
#endregionUpdateDispNames


########################
# Section 4 of 6: Dump all EXISTING Active Directory Group Memberships
# 
# What is Does:
#   for all of the AD groups I know about - just dump membership with Get-ADGroupMember
#   save the list of members in memory, so I can compare it to servers later
# 
########################


###
#    Compose - CURRENT Group Members - Roster
#             as -> $CurrentMembershipHash
###

# all those that have GUIds; things in the map with no guid - have not yet been created in Active Directory
$AppsWITHGroupsLIST = $IDMAP | Where "AD_Groups_ARRAY" -ne $null
# a place to hold mbr daters
$CurrentMembershipHash = @{}

foreach ($activeAppThing in $AppsWITHGroupsLIST) {

    #
    ## Mar. 16 Note:   SOME, of the result entries will have NO MEMBERS
    <# 

Qry -> $CurrentMembershipHash.keys | %{$CurrentMembershipHash[$_]; pause}
& Sample Results

        objectGuid                     d7816e3f-aa01-4505-9c38-2985895468b9                                                                                                                   
        members                        {<SERVER>}                                                                                                    

        objectGuid                     823644e8-60b2-4cfd-aeec-516919d3ee6e                                                                                                                   
        members                                                                                                                                                                               


#>
    #

    # the Groups - will be listed in an ARRAY -- call the SUB ITEMs ???

    write-Host "scanning any children groups for -" $activeAppThing.current_display_name -ForegroundColor Yellow

    foreach ($AliveGroupItem in $activeAppThing.AD_Groups_ARRAY) {
        # Process the Get-ADMbr .... and ADD to roster
            
        $thisList = ""
        $thisList = Get-ADGroupMember $AliveGroupItem.AD_Group_objectGuid -Credential $MyAccess

        # Prob. need to filter for the $ at end of line - for sams
        $CurrentMembershipHash.Add($AliveGroupItem.ComposedSysIdwEnv, @{"objectGuid" = $AliveGroupItem.AD_Group_objectGuid; "members" = $thisList.SamAccountName })

    }
        
}


$DevCounter = 0


########################
# Section 5 of 6: BIG DADDY LOOP !! Go Thru EACH SERVER, and validate group membership(s)
# 
# What is Does:
#   using the SERVER LIST from ServiceNow - check that each single server is in the right groups
#   servers can be members of MORE THAN ONE Application, and therefore MORE than one group as well
#   this BIG LOOP - checks each server to make sure it is in the right security groups
#
#  ALSO: if the required security group does NOT YET exist, this loop will create it!
#
########################


foreach ($ciInstanceRow in $SvrCItoAppMap) {


    Write-Host "Processing" $ciInstanceRow -ForegroundColor Yellow

    # *STEP* lookup membership of the composed APPLICATION-Env -- if it's avail.
    # contained within $CurrentMembershipHash - via the "ComposedSysIdwEnv"
    # if it's NOT populated, assume the group doesn't yet exist (or possilby that it doesn't have any members ?? - need to confirm null/count/etc. here)


    # Grab the larger IDMAP entry - to start
    $IDMapHit = $null

    #3/16 ToDo
    # I should ALLLLLLWAYS have a result here; fail if not
    # HEEEEEEEEEY --> the [0], will default to the FIRST RECORD RETURNED; but there __ARE__ apps with idential names; e.g. 'NIC-Premium-Web-Service-CL-Demo'
    # tough luck
    $IDMapHit = ($IDMAP | Where "current_display_name" -eq $ciInstanceRow.rel_u_appname)[0]

    if ($IDMapHit -eq $null) {
        # this is an UNEXPECTED Result -- I need to take some action here
        # Gotta Dig a little more for app info; it may have been renamed
        Write-Host "CAN'T FIND THE APP - Based on displayname" -ForegroundColor Red
        Write-Host $ciInstanceRow
        pause
    }
 
    ##
    # What - if this attribute is blank/null; I should write a 'catch all' group namer
    ##
    # ->   $ciInstanceRow.'app_u_environment.u_abbreviation'

    [STRING]$grpAryMapLookupKey = ""
    if (($ciInstanceRow.'app_u_environment.u_abbreviation').Length -gt 0) { $grpAryMapLookupKey = $IDMapHit.app_sys_id + "&env=" + $ciInstanceRow.'app_u_environment.u_abbreviation' }
    else { $grpAryMapLookupKey = $IDMapHit.app_sys_id + "&env=noenv" }


    # NO CLUE, is this call works ... >>>>
    # Consider a .count check here

    # Be MINDFUL - I'll need to call element 0-Zed , with this format

    [ARRAY]$GroupListMatch = @()
    [ARRAY]$GroupListMatch = $IDMapHit.AD_Groups_ARRAY | Where "ComposedSysIdwEnv" -eq $grpAryMapLookupKey

    ##$IDMapHit | Where "AD_Groups_ARRAY" -eq $null

    # Should I worry about count > 1 ?

    if ($GroupListMatch.count -ne 1) {
    
        $envDataforCall = ""
    
        if (($ciInstanceRow.'app_u_environment.u_abbreviation').length -gt 0) { $envDataforCall = $ciInstanceRow.'app_u_environment.u_abbreviation' }
        else { $envDataforCall = "noenv" }

        try {
            # We DO NOT HAVE AN EXISTING SECURITY GROUP ... Dude - So MAKE ONE !
            $grpCreateCall = ""
            $grpCreateCall = createNewGroup -AppSYSid $IDMapHit.app_sys_id -AppCiDispName $IDMapHit.current_display_name `
                -EnvParam $envDataforCall -MyAccess $MyAccess -ErrorAction Stop
        }
        catch {
            "Error: Something went not good trying to create new group for " + $ciInstanceRow.rel_u_appname | Add-Content $ChangeLogfile;
            $error[0] | Add-Content $ChangeLogfile;

            Write-Host "Error: Something went not good trying to create new group for "  $ciInstanceRow.rel_u_appname -ForegroundColor Red
            Write-Host $error[0] 
            Pause
        }
    
        # Manage errors on group creation

        if ($grpCreateCall.status -eq "success") {
            # the security group creation returned a SUCCESS ---->>>>

            "Created a new security group for: " + $IDMapHit.current_display_name | Add-Content $ChangeLogfile
    
            $GrpRefetch = $null
            while ($GrpRefetch -eq $null) {
                write-host "looking up new group (with a pause)..."
                $LookUp = ""
                try { $LookUp = Get-ADGroup $grpCreateCall.results.guid -ErrorAction Stop -Credential $MyAccess }
                catch { sleep 5 }

                if ($LookUp.objectguid -eq $grpCreateCall.results.guid) {
                
                    [STRING]$CompSamVal = $ciInstanceRow.app_name + "$"

                    # I am CERTAIN -- some accounts will fail -- just NOTE it and MOVE ON !!
                    try {
                    
                        # added GC step Jun. 15
                        $tgtComputerAccObj = ""
                        $tgtComputerAccObj = Get-ADComputer -Filter { samaccountname -eq $CompSamVal } -Server "<DC FQDN>:3268" -ErrorAction Stop
                        $AddCall = Add-ADGroupMember -Identity $grpCreateCall.results.guid -Members $tgtComputerAccObj -ErrorAction Stop -Credential $MyAccess
                    
                        "added " + $CompSamVal + " to NEW group" | Add-Content $ChangeLogfile

                    }
                    catch {
                        # record the error 
                        "Problem trying to add " + $CompSamVal + " to brand new group for " + $grpCreateCall.results  | Add-Content $ChangeLogfile
                        $error[0] | Add-Content $ChangeLogfile;
                    
                        Write-Host "Problem trying to add " $CompSamVal " to brand new group for " $grpCreateCall.results -ForegroundColor Red
                        Write-Host $error[0]


                        #Pause
                    }

                    $GrpRefetch = $true
                }
                # end WHILE
            }

    
            # Now - Update the IDMAP table -- and the membership roster !!

      
            $NewDataforGRP = ""
            $NewDataforGRP = @{"ComposedSysIdwEnv" = $grpAryMapLookupKey; "AD_Group_objectGuid" = $grpCreateCall.results.guid }
      
            # index me; WHAT is the benefit of doing it this way ????????
            # am I able to IMPORT into a hash -- instead of this general ARRAY ?? it's coming / going from|to .json.txt flat files
      
            $BackRollIdx = ""
            # Scan ALL app_sys_id values, and capture the Index Position of my current working target
            $BackRollIdx = ($IDMAP.app_sys_id).IndexOf($IDMapHit.app_sys_id)
      
      
            if ($IDMapHit.AD_Groups_ARRAY.count -gt 0) {
                $IDMAP[$BackRollIdx].AD_Groups_ARRAY += $NewDataforGRP
            }

            elseif ($IDMapHit.AD_Groups_ARRAY.count -eq 0) {
                # super massive CRITICAL - that the value content is explicitally typed as an ARRAY -- or subsequent adds will explode : (
                $IDMAP[$BackRollIdx].AD_Groups_ARRAY = @($NewDataforGRP)
            }
      

            # <<<<---- END: the security group creation returned a SUCCESS
        }
                
        # end - if - for new Group CREATE

    }



    else {



        # COLLECT any MEMBERHSIP Roster deets -- NOTE that it it may be NULL

        $DesiredADGrpgData = ""
        $DesiredADGrpgData = $CurrentMembershipHash.($GroupListMatch[0].ComposedSysIdwEnv).members -replace "\$", ""



        # Add to the membership roster - once you add the current record ... as there can be more of the same coming...


        $isItALREADYMbr = ""
        $isItALREADYMbr = compare $DesiredADGrpgData $ciInstanceRow.app_name -IncludeEqual -ExcludeDifferent

        if ($isItALREADYMbr -eq $null) {
            # We GOT a group - but the Server ain't in it!
            [STRING]$mbrAddDaters = $ciInstanceRow.app_name + "$"

            try {
                # added GC step Jun. 15
                $tgtComputerAccObj = ""
                $tgtComputerAccObj = Get-ADComputer -Filter { samaccountname -eq $mbrAddDaters } -Server "<DC FQDN>:3268" -ErrorAction Stop
                ## reference cmd fr above - $eAddCall = //Add-ADGroupMember -Identity $grpCreateCall.results.guid -Members $tgtComputerAccguid.objectguid.guid -ErrorAction Stop -Credential $MyAccess


                # Critical - NOT to filter down the '$tgtComputerAccObj' to the guid value; PASS THIS AS AN INSTANCE - so the Add cmd can FIND the computer!!
                $eAddCall = Add-ADGroupMember -Identity $GroupListMatch[0].AD_Group_objectGuid -Members $tgtComputerAccObj -ErrorAction Stop -Credential $MyAccess
                # No need to udpate the Membership roster - because this add event should be a DISTINCT step - PER job RUN
                # We'll see the membership next time : )

                "added " + $mbrAddDaters + " to //existing// group" | Add-Content $ChangeLogfile

            }
            catch {
                "Problem when trying to add " + $mbrAddDaters + " to " + $GroupListMatch[0] + "..." | Add-Content $ChangeLogfile
                $Error[0] | Add-Content $ChangeLogfile;
        
                Write-Host "Problem when trying to add " $mbrAddDaters " to " $GroupListMatch[0] "..." -ForegroundColor Red
                Write-Host $Error[0]
                # Pause
          
            }

        }


        # end - ELSE , where there IS INDEED an Active MATCHING Group Found
    }


    # Simple - pause counter; until I'm comfortable with job stability
    # This can be REMOVED - in the future; and MUST be removed for scheduled jobs to work

    $DevCounter ++
    Write-Host $DevCounter
    if ($DevCounter -gt 600) {
        Write-Host "Count Pause!"
        pause
        $DevCounter = 0
    }



    #End - for EACH SvrCI Instance Loop
}








########################
# Section 6 of 6: Save the Identity Map - back to a File
# 
# What is Does:
#   update any changes to the ID Map file
#   including any NEW Applications, and New security groups
#   the file - will be used the NEXT time the job runs
########################

# Depth is CRITICAL here -- to capture the nested "System.Collections.Hashtable" -- of the "AD_Groups_ARRAY" component
($IDMAP | ConvertTo-Json -Depth 10) | Set-Content $newIDMapFileExpName


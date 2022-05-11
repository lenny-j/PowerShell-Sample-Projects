Import-Module ActiveDirectory
$theQuery = @()
$theQuery = Get-ADUser -Filter * -Properties Memberof
$simpleExpTBL = @()
foreach ($result in $theQuery) {

# Collect and Set - the GUID as _id; and Deal w/ the odd 'sid' problem
$simpleExpTBL += ($result | Select @{N='_id';E={$_.ObjectGuid.ToString()}},@{N='Record';E={$_ | Select * -ExcludeProperty SID}}) | ConvertTo-Json -Depth 99 -Compress

}
$simpleExpTBL | Set-Content ThisExport.csv

.\mongoimport.exe --db=adtest --collection=users --mode=upsert --file=ThisExport.csv mongodb://10.0.0.237:27017/

#>.\mongoimport.exe --db=test1 --collection=aduser --file=MyImportFile.json --jsonArray
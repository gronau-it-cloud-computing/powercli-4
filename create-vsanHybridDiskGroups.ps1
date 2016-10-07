
$ESXHosts = "host1,host2"
Connect-VIServer vcenter.something.com

$ESXHosts | Foreach {
 
 
  

   
   Write-Host "Finding disks for $($_)"
   # Find the blank SSDs for the current host
   $disks = Get-VMHost $_ | Get-VMHostDisk
   $SSDs = $disks | Where { $_.scsilun.extensiondata.ssd }
   $BlankSSDs = $SSDs | Where { -not $_.Extensiondata.Layout.Partition[0].partition }
   #Write-Host "Blank SSDs"
   $BlankSSDsArray = @()
   $BlankSSDs | Foreach { $BlankSSDsArray += $_.scsilun.CanonicalName }
   #$BlankSSDsArray 
    
   # Find the blank Magnetic disks for the current host
   $HDDs = $disks | Where { ((-not $_.scsilun.extensiondata.ssd) -and ( $_.scsilun.Vendor -ne "HP iLO")) }
   $BlankHDDs = $HDDs | Where { -not $_.Extensiondata.Layout.Partition[0].partition }
   #Write-Host "Blank HDDs"
  $BlankHDDsArray = @()
   $BlankHDDs | Foreach { $BlankHDDsArray += $_.scsilun.CanonicalName }
   #$BlankHDDsArray
    
	
	 #  Write-Host "all disks"
	 $diskgroup=1
 Get-VMHost $_ | Get-VMHostHba | where { $_.Model -like "*P440*"} | Foreach {
 	$LocalSSDArray = @()
	$LocalSSDString = ""
	$LocalHDDArray = @()
	$LocalHDDString = ""
	$_.ScsiLunUids| %{ 
	
		 $Disk=($_.split("=")[3]).split("/")[0] 
		 if($BlankHDDsArray -contains $Disk )
		 {
		 	$LocalHDDArray += $Disk
			
		 }
		 if($BlankSSDsArray -contains $Disk )
		 {
		 	$LocalSSDArray += $Disk
			
		 }
	 }
	 
write-host "creating diskgroup " $diskgroup " on " $_.vmhost
  
  $LocalSSDString = $LocalSSDArray[0]
  $LocalHDDString = [string]$LocalHDDArray -replace " ","," 
 #$LocalSSDArray[0]
 #[string]$LocalHDDArray -replace " ",","
 
 New-VsanDiskGroup -VMHost $_.vmhost -SSDCanonicalName $LocalSSDString -DataDiskCanonicalName $LocalHDDArray| Out-Null	
 Write-Host "---"
 
 $diskgroup+=1
 }#foreachHBA
 
 
 

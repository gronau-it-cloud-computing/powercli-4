
Param (
	#You must provide a vCenter, host
	$vcenter,
	$cluster,
	$vds_name,
	[switch]$removeHost,
	[switch]$migrateVMnic1,
	[switch]$migrateVMnic0,
	[switch]$migrateVmkernels,
	[switch]$checkDistributedSwitch

	)

Connect-VIServer $vcenter

# ESXi hosts to migrate from VSS-&gt;VDS
$vmhost_array = get-vmhost -location $cluster 

# VDS to migrate from

$vds = Get-VDSwitch -Name $vds_name

# VSS to migrate to
$vss_name = "vSwitch0"

# Name of portgroups to create on VSS
$mgmt_name = "Management Network"
$storage_name = "IPStorage"

$vmotion_name = "VMotion"




foreach ($vmhost in $vmhost_array) {
	Write-Host "Processing" $vmhost
	# vSwitch to migrate to
	$vss = Get-VMHost -Name $vmhost | Get-VirtualSwitch -Name $vss_name


	
	if ($migrateVMnic0){
		Write-Host "Moving vmnic0 to VSS on " $vmhost
		$vmnic0 = Get-VMHostNetworkadapter -VMHost $vmhost -Name "vmnic0"
		$pnic_array = @($vmnic0)
		Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss -VMHostPhysicalNic $pnic_array  -Confirm:$false
	}
	
	if ($migrateVMnic1){
		Write-Host "Moving vmnic1 to VSS on " $vmhost
		$vmnic1 = Get-VMHostNetworkadapter -VMHost $vmhost -Name "vmnic1"
		$pnic_array = @($vmnic1)
		Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss -VMHostPhysicalNic $pnic_array  -Confirm:$false
	}
	
	if($migrateVmkernels){
		# Migrate VMkernel interfaces to VDS

		# Management #
		

		
		$vmks = Get-VMHostNetworkAdapter -VMHost $vmhost -vmkernel
		
		
		foreach($vmk in $vmks){
			$thirdOctet=$vmk.IP.Split(".")[2]
			switch -regex ($thirdOctet)
			{
				1 { $portgroup= "Management Network"; $vlanid=100 }
				2 { $portgroup= "IPStorage"; $vlanid=200 }			
				3 { $portgroup= "VMotion"; $vlanid=300 }
			}
			
			
			$pg = Get-VirtualPortGroup -Name $portgroup -VMHost $vmhost
			if ( -not $pg ){
				Write-Host "Creating " $portgroup " on " $vss_name
				$pg = New-VirtualPortGroup -VirtualSwitch $vss -Name $portgroup -VLanId $vlanid		
			}
			$pg_array=@($pg)
			$vmk_array=@($vmk)
			$vmnic0 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name vmnic0
			$vmnic1 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name vmnic1
			$pnic_array=@($vmnic0)
			Write-Host "migrating vmkernel to " $portgroup " on " $vss_name
			Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss  -vmhostphysicalnic $pnic_array -VMHostVirtualNic $vmk_array -VirtualNicPortgroup $pg_array  -Confirm:$false
		}
	}
	
	if($checkDistributedSwitch){
		Write-Host "checking for anything on the distributed switch of " $vmhost
		   
   		get-VMHostNetworkAdapter -vmhost $vmhost -VMKernel | Where-Object {$_.PortGroupName -like "*bit"}
		Get-VMHost $vmhost | Get-VM | Get-NetworkAdapter | where {$_.networkname -like "*bit"}

	}
	
	if ($removehost){
		Write-Host "Removing" $vmhost "from" $vds_name
		$vds | Remove-VDSwitchVMHost -VMHost $vmhost -Confirm:$false
	}
}


Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false


Param (
	#You must provide a vCenter, host, and path for CSV file 
	$vcenter,
	$cluster,
	$vds_name,
	[switch]$addHost,
	[switch]$migrateVMnic1,
	[switch]$migrateVMnic0,
	[switch]$migrateVmkernels,
	[switch]$checkStandardSwitch

	)




if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PsSnapin VMware.VimAutomation.Core
	
}
if ((Get-PSsnapin -Name VMware.VimAutomation.Vds -ErrorAction SilentlyContinue) -eq $null )
{
	Add-PSSnapin vmware.Vimautomation.vds
}


Connect-VIServer $vcenter

# ESXi hosts to migrate from VSS-&gt;VDS
$vmhost_array = Get-VMHost -Location $cluster
#
## Create VDS
#$vds_name = "VDS-01"
#Write-Host "`nCreating new VDS" $vds_name


# get VDS
$vds = Get-VDSwitch -Name $vds_name


foreach ($vmhost in $vmhost_array) {


	if ($addHost){

		# Add ESXi host to VDS
		Write-Host "Adding" $vmhost "to" $vds_name
		$vds | Add-VDSwitchVMHost -VMHost $vmhost | Out-Null
	}
	if ($migrateVMnic0){
		$uplinks = $vmhost | Get-VDSwitch|Get-VDPort -Uplink | where {$_.ProxyHost -like $VMHost.name}
		write-host "Adding vmnic0 to "	$vds_name "on " $vmhost
		$VMHost | Get-VMHostNetworkAdapter -Name vmnic0 | Remove-VirtualSwitchPhysicalNetworkAdapter -Confirm:$false
		
		
		$config = New-Object VMware.Vim.HostNetworkConfig
		$config.proxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
		$config.proxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
		$config.proxySwitch[0].changeOperation = "edit"
		$config.proxySwitch[0].uuid = $vds.Key
		$config.proxySwitch[0].spec = New-Object VMware.Vim.HostProxySwitchSpec
		$config.proxySwitch[0].spec.backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
		$config.proxySwitch[0].spec.backing.pnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (2)
		$config.proxySwitch[0].spec.backing.pnicSpec[1] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
		$config.proxySwitch[0].spec.backing.pnicSpec[1].pnicDevice = "vmnic0"
		$config.proxySwitch[0].spec.backing.pnicSpec[1].uplinkPortKey = ($uplinks | where {$_.Name -eq "Uplink 1"}).key
		$_this = Get-View (Get-View $vmhost).ConfigManager.NetworkSystem
		#check if in VDS
		if ($_this.NetworkConfig.ProxySwitch)
		{
			#check if alternate vmnic has been added
			if ($_this.NetworkConfig.ProxySwitch[0].spec.backing.pnicspec)
			{
				if($_this.NetworkConfig.ProxySwitch[0].spec.backing.pnicspec[0].pnicdevice -eq "vmnic1")
				{
					$config.proxySwitch[0].spec.backing.pnicSpec[0] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
					$config.proxySwitch[0].spec.backing.pnicSpec[0].pnicDevice = "vmnic1"
					$config.proxySwitch[0].spec.backing.pnicSpec[0].uplinkPortKey = ($uplinks | where {$_.Name -eq "Uplink 2"}).key	
					
				}
			#echo
			}
		
			$_this.UpdateNetworkConfig($config, "modify")
		
		}
		else
		{
			Write-Host "Host does not belong to a VDS, skipping"
		}
		

	}
	if ($migrateVMnic1){
		$uplinks = $vmhost | Get-VDSwitch|Get-VDPort -Uplink | where {$_.ProxyHost -like $VMHost.name}
		write-host "Adding vmnic1 to "	$vds_name "on " $vmhost
		$VMHost | Get-VMHostNetworkAdapter -Name vmnic1 | Remove-VirtualSwitchPhysicalNetworkAdapter -Confirm:$false
		
		$config = New-Object VMware.Vim.HostNetworkConfig
		$config.proxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
		$config.proxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
		$config.proxySwitch[0].changeOperation = "edit"
		$config.proxySwitch[0].uuid = $vds.Key
		$config.proxySwitch[0].spec = New-Object VMware.Vim.HostProxySwitchSpec
		$config.proxySwitch[0].spec.backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
		$config.proxySwitch[0].spec.backing.pnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (2)
		$config.proxySwitch[0].spec.backing.pnicSpec[0] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
		$config.proxySwitch[0].spec.backing.pnicSpec[0].pnicDevice = "vmnic1"
		$config.proxySwitch[0].spec.backing.pnicSpec[0].uplinkPortKey = ($uplinks | where {$_.Name -eq "Uplink 2"}).key
		$_this = Get-View (Get-View $vmhost).ConfigManager.NetworkSystem
		#check if in VDS
		if ($_this.NetworkConfig.ProxySwitch)
		{
			#check if alternate vmnic has been added
			if ($_this.NetworkConfig.ProxySwitch[0].spec.backing.pnicspec)
			{
				if($_this.NetworkConfig.ProxySwitch[0].spec.backing.pnicspec[0].pnicdevice -eq "vmnic0")
				{
					$config.proxySwitch[0].spec.backing.pnicSpec[0] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
					$config.proxySwitch[0].spec.backing.pnicSpec[0].pnicDevice = "vmnic0"
					$config.proxySwitch[0].spec.backing.pnicSpec[0].uplinkPortKey = ($uplinks | where {$_.Name -eq "Uplink 1"}).key	
					$config.proxySwitch[0].spec.backing.pnicSpec[1] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
					$config.proxySwitch[0].spec.backing.pnicSpec[1].pnicDevice = "vmnic1"
					$config.proxySwitch[0].spec.backing.pnicSpec[1].uplinkPortKey = ($uplinks | where {$_.Name -eq "Uplink 2"}).key	
				}
			#echo
			}
		
			$_this.UpdateNetworkConfig($config, "modify")
		
		}
		else
		{
			Write-Host "Host does not belong to a VDS, skipping"
		}
		
		
		
			
	
	}


	if($migrateVmkernels){
		# Migrate VMkernel interfaces to VDS

		# Management #
		
		Write-Host "Migrating Management to" $vds_name " on " $vmhost
		$vmks = Get-VMHostNetworkAdapter -VMHost $vmhost -vmkernel
		
		
		$vmk = $vmks | Where-Object {$_.PortGroupName -eq "Management Network"}
		$portgroup="MGMT-vds"
		
		
		$dvportgroup = Get-VDPortgroup -name $portgroup -VDSwitch $vds
		if ($dvportgroup){
			Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -confirm:$false | Out-Null
		}
		$vmk = $null
		$portgroup= $null
		$dvportgroup = $null
		
		# Storage  regular
		Write-Host "Migrating Storage to" $vds_name
		
		$vmk = $vmks | Where-Object {$_.PortGroupName -eq "IPStorage" }
		$portgroup = "IPStorage-vds"
		if ($vmk){
			
			
			$dvportgroup = Get-VDPortgroup -name $portgroup -VDSwitch $vds
			if ($dvportgroup){
				Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -confirm:$false | Out-Null
			}
			
		}
			
		$vmk = $null
		$portgroup= $null
		$dvportgroup = $null


		
		

		# vMotion regular#
		Write-Host "Migrating vmotion bit to" $vds_name
		
		$vmk = $vmks | Where-Object {$_.PortGroupName -eq "VMotion" }
		$porgroup = "VMotion-vds"
		if ($vmk){
			
			$dvportgroup = Get-VDPortgroup -name $portgroup -VDSwitch $vds
			if ($dvportgroup){
				Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -confirm:$false | Out-Null
			}
			
		}
			
		$vmk = $null
		$portgroup= $null
		$dvportgroup = $null	
		

	}
	
	if($checkStandardSwitch){
		Write-Host "checking for anything on the standard switch of " $vmhost
		   
   get-VMHostNetworkAdapter -vmhost $vmhost -VMKernel | Where-Object {$_.PortGroupName -notlike "*bit"}
	Get-VMHost $vmhost | Get-VM | Get-NetworkAdapter | where {$_.networkname -notlike "*bit"}


	
	}


	

}

Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false
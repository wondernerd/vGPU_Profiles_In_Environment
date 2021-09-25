############################################################################
# vGPU Supported Profiles list
# Copyright (C) 2019-2021 Tony Foster
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>
############################################################################


Function vGPUsInASystem {
	param(
	
	[Parameter(Mandatory = $false)]
	[string]
	$vGPULocations,
	
	[Parameter(Mandatory = $false)]
	[string]
	$vGPUHostState
	# Valid states (connected,disconnected,notresponding,maintenance) or comma seperated combination 
	)

# Take care of function paramaters
		if("" -eq $vGPULocations){ #if nothing is passed set the value to all clusters
			$vGPULocations = "*"
		} 
		if("" -eq $vGPUHostState){ #if nothing is passed set the value to all states
			$vGPUHostState = "connected" #,disconnected,notresponding,maintenance"
		}

#echo "Running profiles function"
# Create a list of GPU Specs
		[System.Collections.ArrayList]$vGPUlist = @()
			#Name, vGPU per GPU, vGPU per Board, physical GPUs per board
			#P4
			#$obj = [pscustomobject]@{CardType="P4";vGPUname="grid_p4-8q"; vGPUperGPU=1; vGPUperBoard=1; pGPUperBoard=1}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="p4";vGPUname="grid_p4-4q";vGPUperGPU=2;vGPUperBoard=2; pGPUperBoard=1}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="p4";vGPUname="grid_p4-2q";vGPUperGPU=4;vGPUperBoard=4; pGPUperBoard=1}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="p4";vGPUname="grid_p4-1q";vGPUperGPU=8;vGPUperBoard=8; pGPUperBoard=1}; $vGPUlist.add($obj)|out-null
			#M60
			#$obj = [pscustomobject]@{CardType="m60";vGPUname="grid_m60-8q";vGPUperGPU=1;vGPUperBoard=2; pGPUperBoard=2}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m60";vGPUname="grid_m60-4q";vGPUperGPU=2;vGPUperBoard=4; pGPUperBoard=2}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m60";vGPUname="grid_m60-2q";vGPUperGPU=4;vGPUperBoard=8; pGPUperBoard=2}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m60";vGPUname="grid_m60-1q";vGPUperGPU=8;vGPUperBoard=16; pGPUperBoard=2}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m60";vGPUname="grid_m60-0q";vGPUperGPU=16;vGPUperBoard=32; pGPUperBoard=2}; $vGPUlist.add($obj)|out-null
			##M10
			#$obj = [pscustomobject]@{CardType="m10";vGPUname="grid_m10-8q";vGPUperGPU=1;vGPUperBoard=4; pGPUperBoard=4}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m10";vGPUname="grid_m10-4q";vGPUperGPU=2;vGPUperBoard=8; pGPUperBoard=4}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m10";vGPUname="grid_m10-2q";vGPUperGPU=4;vGPUperBoard=16; pGPUperBoard=4}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m10";vGPUname="grid_m10-1q";vGPUperGPU=8;vGPUperBoard=32; pGPUperBoard=4}; $vGPUlist.add($obj)|out-null
			#$obj = [pscustomobject]@{CardType="m10";vGPUname="grid_m10-0q";vGPUperGPU=16;vGPUperBoard=64; pGPUperBoard=4}; $vGPUlist.add($obj)|out-null
			#Null
			$obj = [pscustomobject]@{CardType="empty";vGPUname="default";vGPUperGPU=0;vGPUperBoard=0; pGPUperBoard=0}; $vGPUlist.add($obj)|out-null #catch any non-defined cards and force them out as zeros
		#help from www.idmworks.com/what-is-the-most-efficient-way-to-create-a-collection-of-objects-in-powershell/



Try {
		#get-vmhost -state $vGPUHostState -location $vGPULocations | ExtensionData.Config.SharedPassthruGpuTypes | ForEach-Object {
		get-vmhost -state $vGPUHostState -location $vGPULocations | ForEach-Object { #itterate trhough the hosts
			#echo '------------------------------------------------------------'
			#echo "Host: " $_.name
							
			$CurrGPU = 'empty' #Set to empty so it catches the garbage collection if the host has no GPUs
			$_ | Get-VMHostPciDevice -deviceClass DisplayController -Name "NVIDIA Corporation NVIDIATesla*" | ForEach-Object {
				$CurrGPU = ($_.Name -split " ")[3] #only get the last part of the GPU name ie P4 
			} #this wil only get the last item in the list
			
			#Echo 'Looking for GPU: ' $CurrGPU
			#check if GPU is already in the list, if so skip it
			$GPUalreadyHere = $null #Set things to Null to make sure it's caught in the check below
			$GPUalreadyHere = $vGPUlist.CardType | where { $_.ToLower() -eq $CurrGPU.ToLower() } | Select -First 1;  #Find if the GPU is already in the array
			
			#echo '------------------------------------------------------------'
			#echo 'vGPU List:'
			#echo $vGPUlist
			#echo '------------------------------------------------------------'
			#echo $vGPUlist | where { $_.CardType -eq "P4" }
			#echo '------------------------------------------------------------'
			#echo 'Check this line'
			#echo $GPUalreadyHere "bob" 
			
			if ($GPUalreadyHere -eq $null){  #The GPU is not in the array
				
				#Added 8-3-21 as the profile size changed in a previous vSphere release
				$LargestProfileSize4Host = 0 #Set to 0 for garbage collection
				$_.ExtensionData.Config.SharedPassthruGpuTypes | ForEach-object { #itterate through the cards supported configs and find largest size
					$CurrProfile = ($_ -split "-")[1] #Get just the profile  (ex: 8q)
					#echo $CurrCard " : " $CurrProfile
					
					#Safety Check for 2b4 and 1b4 profiles which should be removed eventually
					if ($CurrProfile -eq "2b4") {
						$CurrProfile = "2b"
					}
					if ($CurrProfile -eq "1b4") {
						$CurrProfile = "1b"
					}
					#echo "==============="
					#echo $CurrProfile
					$ProfileNum = $CurrProfile -replace "[^0-9]" , '' #get just the profile number
					#echo $ProfileNum
					
					if ($ProfileNum -gt $LargestProfileSize4Host) {
						$LargestProfileSize4Host = $ProfileNum #find the largest profile size and set it
						#echo "Largest Profile Size set to: " $LargestProfileSize4Host
					}
				}
				
				$_.ExtensionData.Config.SharedPassthruGpuTypes | ForEach-object { #itterate through the cards supported configs
					#echo "========================================================"
					#echo "vGPU Profile: " $_ #(ex: grid_p4-8q)
					
					$TempCard = ($_ -split "_")[1] #remove the grid-card entry from the profile name 
					$CurrCard = ( $TempCard -split "-")[0] #get the card type of the profile string (ex: p4)
					
					$CurrProfile = ($_ -split "-")[1] #Get just the profile  (ex: 8q)
					#echo $CurrCard " : " $CurrProfile
					
					#Safety Check for 2b4 and 1b4 profiles which should be removed eventually
					if ($CurrProfile -eq "2b4") {
						$CurrProfile = "2b"
					}
					if ($CurrProfile -eq "1b4") {
						$CurrProfile = "1b"
					}
					#echo "==============="
					#echo $CurrProfile
					$ProfileNum = $CurrProfile -replace "[^0-9]" , '' #get just the profile number
					#echo $ProfileNum
					
					#########################################################################
					#Deal with M series cards even though not likely to use this
					#########################################################################
					$GPUsOnBoard = 1 #Everything but M series cards have a single GPU on the board
					if ($CurrCard.ToLower() -eq 'm60' -or $CurrCard.ToLower() -eq 'm6'){ #These two cards have 2 GPUs on the board
						$GPUsOnBoard = 2 #Set the number of GPUs on the board
						if ($ProfileNum -eq 0){ 
							$ProfileNum = 0.5 #Only these cards of 0 profiles which is technichnically 0.5 for math
						}
					}
					if ($CurrCard.ToLower() -eq 'm10'){ #This host has 4 GPUs on the board
						$GPUsOnBoard = 4 #Set the number of GPUs on the board
						if ($ProfileNum -eq 0){ 
							$ProfileNum = 0.5 #Only these cards of 0 profiles which is technichnically 0.5 for math
						}
					}
					
					#########################################################################
					#Assumes that top most profile is the largest profile returned, so a P4-8q is largest
					#Assumes we are not mixxing card types in the same hosts
					#########################################################################
					#echo $ProfileNum
					
					if ($ProfileNum -gt $LargestProfileSize4Host) { #if the profile is larger than 0 set it as the max GPU size
						$LargestProfileSize4Host = $ProfileNum
					}
					
					#Saftey check to avoid division by 0
					if ($LargestProfileSize4Host -gt 0){
						$vGPUperGPU = $LargestProfileSize4Host / $ProfileNum #(ex: 1 vGPU per board)
						#echo "Max vGPU per GPU: "  $vGPUperGPU
					}
					
					$vGPUsPerBoard = $vGPUperGPU * $GPUsOnBoard #Set the number of vGPUs per board based on GPUs per board times number of vGPUs per GPU chip
					
					#echo '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
					#echo 'Add entry to array'
					#echo $_
					#$obj = [pscustomobject]@{CardType="m10";vGPUname="grid_m10-8q";vGPUperGPU=1;vGPUperBoard=4; pGPUperBoard=4}; $vGPUlist.add($obj)|out-null
					$obj = [pscustomobject]@{CardType=$CurrCard;vGPUname=$_; vGPUperGPU=$vGPUperGPU; vGPUperBoard=$vGPUsPerBoard; pGPUperBoard=$GPUsOnBoard}; $vGPUlist.add($obj)|out-null
					#echo '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
				}					
			}
			#echo $vGPUlist
			#echo "Just about to return"
			
		}
		#echo $vGPUlist
		#echo "this is what we want"
		return $vGPUlist
	}
Catch {
		write-Host "Error creating entries for vGPUs"
		#echo "failed to create entries for vGPUs"
		return -1 #return an invalid value so user can test
		Break #stop working
	}
	
}

#echo "pre call"
#Example: vGPUsInASystem "*" "connected"

vGPUsInASystem "*" "connected" #, maintenance"

#echo "Post Call"
		

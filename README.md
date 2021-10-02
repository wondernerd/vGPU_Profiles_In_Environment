# vGPU_Profiles_In_Environment
This script dynamically gathers the vGPU profiles of all specified hosts into an array. 

For those who’ve seen or are using my VDI by day Compute by Night PowerShell scripts you may have noticed that the vGPU profiles are entered manually in an array. Wouldn’t it be nice if those vGPU profiles could be easily captured and loaded into an array? That’s what this module does. This post is a deep dive on the PowerCLI module for finding vGPU profiles. It is now a key module in the VDI by day Compute by Night scripts and returns an object collection of vGPU profiles.
List of vGPU profiles supported by a host as shown in the VMware Managed Object Browser (MOB)

The vGPU_Profiles_In_Environment PowerShell module checks hosts, retrieves the supported vGPU profiles, and is now called in the VDI by Day script. This new module make this script more efficient, that’s because the script no longer has to iterate through all the GPU profiles, even for GPUs that aren’t in any of your hosts. Now you could comment out the array entries for cards not used. You just need to keep the array up to date.

You’re probably wondering at this point how it works and what’s at the set of commands at the core of this design. That’s what we’ll dig into first. Then I’ll go into how I used that to create this new module.
Breaking Down The Command

Getting the vGPU profiles can be done with two lines of code.
	
get-vmhost -state $vGPUHostState -location $vGPULocations | ForEach-Object { #iterate through the hosts
    #Do other stuff here
    echo $_.ExtensionData.Config.SharedPassthruGpuTypes 
}

Now you probably don’t want to just drop this code in and run it. There’s a pretty good chance you’re going to get some errors with it. Unless all the hosts that the get-vmhost view is retrieving have GPUs in them your script won’t like a call into .ExtensionData.Config.SharedPassthruGpuTypes. Most likely it will throw an error and kill your script. That’s part of the reason I have those two lines separated by several other lines of code in this module.

The way this code works is it takes an array of ESXi hosts and iterates through them in a ForEach loop. The resulting object variable (that represents a host) is represented as $_ . Having the host, we can then check to see if it has the .ExtensionData.Config.SharedPassthruGpuTypes properties.

If you look up .ExtensionData.Config.SharedPassthruGpuTypes in the Managed Object Browser for your vCenter (provided you have a host with an NVIDIA GPU) you will see that this returns a string array type. That array contains all the supported vGPU profiles for that GPU. It also means you can pass that array or iterate through it and perform some work on the profiles like I did in the new module. Which is where we’re heading next. I’m going to break down how the new module works for you.
Exploring the Module

Where going to break down the lines of code that make up the module. We’ll start at the top and work our way down through the module.

The first several lines of code define the function. It takes two optional arguments, $vGPULocations and $vGPUHostState. One tells us where we are looking for the vGPUs, by default it looks for all (*) hosts. The vGPUHostState is the state of the host in vSphere. This can be connected, disconnected, notresponding, or maintenance. You can pass only one of these states to the get-vmhost-view as of vSphere 7.0 U2. This shouldn’t be a problem. Rarely will you want to run this against anything but “connected” hosts. And even rarer still is running it against multiple states.
	
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

We then instantiate the list of vGPUs as a collection. with some additional information you cant get directly from the ESXi hosts.
	
# Create a list of GPU Specs
        [System.Collections.ArrayList]$vGPUlist = @()
            #Name, vGPU per GPU, vGPU per Board, physical GPUs per board
            #Removed examples...
            #Null
            $obj = [pscustomobject]@{CardType="empty";vGPUname="default";vGPUperGPU=0;vGPUperBoard=0; pGPUperBoard=0}; $vGPUlist.add($obj)|out-null #catch any non-defined cards and force them out as zeros
        #help from www.idmworks.com/what-is-the-most-efficient-way-to-create-a-collection-of-objects-in-powershell/

You’ll notice most of this is comments with examples of how the entries are formatted. This ties back to how we did the collection prior to this script. We follow the same configuration, which is nice because it makes it accessible to the other scripts to use without major modification. You will note that we create a single NULL or empty object in the collection. This serves as a catch for when a host without any GPUs is passed.

This is where we get into the meat of this function. The block of code below gets a host view and starts processing it. We start with a “try” to catch any errors, remember when I said if you ran just the 3 lines of code it takes to get the profiles it may fail. Hence we should catch errors even though we test for failures. Then we create our host view and loop through the objects in a for loop all in one line.

We then take the $CurrGPU variable and set it to ’empty’ before we start iterating through the host. This way we can do some garbage collection within the loop. We then take the current host ($_) and create a new view with the Get-VMHostPciDevice, where wwe are looking for a Display controller with the NVIDIA name using a wild card at the end to capture any such cards. This view is the run through a forEach loop. (Because a host may have more than one GPU.)

This will then assign the GPU type to the CurrGPU value. This process is using an assumption on my part. I’m assuming that these hosts are following manufacturers guidelines of one type of GPU per host. (Yes, I know people who have put multiple GPUs into a single host and it doesn’t “break”.) If you wanted you could turn CurrGPU into an array and get all the card types per host and do a bit of extra processing.

Once we have that we do some garbage collection and check the existing GPU collection for any identical cards in a fun little where / select clause.

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

In the next block of code we check and make sure the GPU hasn’t been added to the array. If it has there’s no point in adding it again. Assuming it’s a new GPU we create a variable that deals with the largest host size and make it 0 to start with. We then go to the host ($_) and get the ExtensionData.Config.SharedPasthruGpuTypes and iterate through them with a ForEach_object loop.
	
if ($GPUalreadyHere -eq $null){  #The GPU is not in the array
     
    #Added 8-3-21 as the profile size changed in a previous vSphere release
    $LargestProfileSize4Host = 0 #Set to 0 for garbage collection
    $_.ExtensionData.Config.SharedPassthruGpuTypes | ForEach-object { #itterate through the cards supported configs and find largest size

Inside of this ForEach loop we do the work of creating the object entry for the object collection of GPUs. We start by removing the “grid” entry from the returned array entry as “grid” is understood at this point and not needed.

$CurrProfile = ($_ -split "-")[1] #Get just the profile  (ex: 8q)
#echo $CurrCard " : " $CurrProfile

The next set of code is handling some special cases that are tied more to using this for VDI than for AI workloads, because they focus on older profiles. The first two if statements check for the 2b4 profile and the 1b4 profile. These profiles are on some older cards. They will eventually be aged off as the cards reach end of life and will no longer be a concern with the code. For now we keep them in and equate them to their 2b and 1b counterparts. We also capture the profile number here for use later in the code.

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

Next we perform a conditional check to make sure we are dealing with a profile larger than 0 and set it accordingly. We do this so it doesn’t matter which order the cards are listed in the vSphere array that was returned and we are currently iterating through. We then exit out of the if the GPU and thus its profiles are in the array conditional check.

    if ($ProfileNum -gt $LargestProfileSize4Host) {
        $LargestProfileSize4Host = $ProfileNum #find the largest profile size and set it
        #echo "Largest Profile Size set to: " $LargestProfileSize4Host
    }
}

We follow this block by looping through the vGPU profiles of the given host ($_) using the ExtensionData.Config.SharedPassthruGpuTypes again. This second loop through the vGPU profiles is what adds them to the collection. It starts by getting the card type and profiles and assigning them to the CurrCard and the CurrProfile variables using split. We then take care of the 2b4 and 1b4 profiles again for this loop. Then, we finish this block by retrieving the profile number (the 8 in 8q) and assigning it to the ProfileNum variable.
	
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

Now its necessary to deal with a couple of M series cards. Specifically the M60 and M10. These cards have multiple GPU chips on them which means they support 2 or more profiles each so we need to account for that by setting the GPUsOnBoard and setting the ProfileNum variable correctly for each card. In the near future this will also need to be done for the A16 GPU which also has 4 GPU chips.

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

Now we start looking at profile sizes and how they relate to our vGPUs. It will take the ProfileNum that we got in previous lines of code, and compare it to the largest GPU profile size. This starts at 0 and keeps growing. We then take that largestProfileSize4Host and check to see if it’s greater than 0. (We dont want any division by zero issues.) We then divide the LargestProfileSize4Host by the ProfileNum to find out how may vGPUs per GPU chip are supported which is the vGPUperGPU variable. Lastly we multiply vGPUperGPU times the number of GPUsOnBoard to get the total number of profiles supported for the board.
	
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

Once we have all that information we can add the vGPU to the object list. All the previous code worked out our profile counts, GPUs per board, and much more. Amazing what you can get from a little list isn’t it. We have several commented out echos to validate our results. We then add the vGPU profile to the array. Exit our inner for loop. Exit our conditional statement insuring the GPU hasn’t been checked yet (the echo $vGPUlist line). Then exit the for loop for the hosts ($_). At this point we can return the vGPUlist to the calling program. At which point we conclude the try statement
	
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

The last part of this function is a catch statement. If anything went wrong that we didn’t test for and handle we through a catch statement. We use the write-host to make sure the error is seen as this should be presumed to be a fatal event. We also return a -1 for testing which is an invalid value. We also put an example of how to call it at the bottom.
	
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

That pretty well covers the way this module works. If you have questions let me know. If you want to improve the code please be sure to fire off a new branch of code. 

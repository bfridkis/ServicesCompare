function processRequest {
	param ($_comps, 
		   $_patches, 
		   [bool]$_saveToFile=$false, 
		   [string]$_path,
           [bool]$_noConsoleOut=$false,
           [bool]$_listAll,
		   [bool]$_complianceCheck)

    $errorList = New-Object System.Collections.Generic.List[System.Object]
    
    if($_saveToFile) { 
        $errorPath = $_path + "_ERRORS.csv"
        $_path += ".csv"
        New-Item -Path $_path -ItemType "file" *>$null
    }

    if ($_complianceCheck -and !$userPassedCheckComplianceAsOfDate) {
        $checkDate = read-host -prompt "`nCheck for compliance as of [Default=Today] (Use format mm/dd/yyyy)"
        if ($checkDate.ToUpper() -eq "Q") { exit }
        if ($checkDate.ToUpper() -eq "B") { return }
        if (!$checkDate) { $checkDate = Get-Date }
        else { $checkDate = Get-Date($checkDate) }
        $checkDateDisplayOut = "$($checkDate.Month)/$($checkDate.Day)/$($checkDate.Year)"
    }
    elseif ($_complianceCheck -and $userPassedCheckComplianceAsOfDate) {
        if ($userPassedCheckComplianceAsOfDate -eq "Today" -or $userPassedCheckComplianceAsOfDate -eq "Default") { $checkDate = Get-Date }
        else { $checkDate = Get-Date($userPassedCheckComplianceAsOfDate) }
        $checkDateDisplayOut = "$($checkDate.Month)/$($checkDate.Day)/$($checkDate.Year)"
    }

    if ($_listAll) {
        
        write-output "`nRunning...Please wait..."
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        if($_noConsoleOut) {
			if ($_complianceCheck) {
				    $_comps | ForEach-Object {
                        $currComp = $_
                        Try {
					        $wmiHash = Get-WmiObject -ComputerName $_ -Class 'Win32_QuickFixEngineering' -ErrorAction Stop
					        $wmiHash | Select-Object -Property PSComputerName, Description, HotFixID, InstalledBy, InstalledOn |
							           Sort-Object InstalledOn | Select-Object -Last 1 -Property PSComputerName,
																	@{ n = 'Most Recent Patch' ; e = {$_.HotfixID}},
																	@{ n = 'Installed On' ; e = {"$($_.InstalledOn.Month)/$($_.InstalledOn.Day)/$($_.InstalledOn.Year)"}}, 
																	@{ n = "Compliant? (Installed within 180 days of $($checkDateDisplayOut)?)" ; e = {$checkDate.adddays(-180) -lt $_.InstalledOn}},
                                                                    @{ n = "Days Past Due (+) or Until Due (-)" ; e = { (New-TimeSpan -Start $_.InstalledOn -End $checkDate.adddays(-180)).Days }}
				            }
                        Catch { $errorList.Add( @{ 'Hostname' = $currComp ; 'Exception' = $_.Exception.Message } ) } 
                    } | Sort-Object 'Days Past Due (+) or Until Due (-)'-Descending -OutVariable Export *>$null
			}
			else {	
				$_comps | ForEach-Object {
                    $currComp = $_
					Try {
                        $wmiHash = Get-WmiObject -ComputerName $_ -Class 'Win32_QuickFixEngineering' -ErrorAction Stop
					    $wmiHash | select-object -Property PSComputerName, Description, HotFixID, InstalledBy, @{n='InstalledOn';e={"$($_.InstalledOn.Month)/$($_.InstalledOn.Day)/$($_.InstalledOn.Year)"}} -OutVariable Export *>$null
                        if ($_saveToFile) { $Export | export-CSV -Path $_path -NoTypeInformation -Append }
                    }
                    Catch { $errorList.Add( @{ 'Hostname' = $currComp ; 'Exception' = $_.Exception.Message } ) }      
				}
            }
        }

        else {
			if($_complianceCheck) {
				$_comps | ForEach-Object {
                    $currComp = $_
					Try { 
                        $wmiHash = Get-WmiObject -ComputerName $_ -Class 'Win32_QuickFixEngineering' -ErrorAction Stop
                        $wmiHash | Select-Object -Property PSComputerName, Description, HotFixID, InstalledBy, InstalledOn |
							   Sort-Object InstalledOn | Select-Object -Last 1 -Property PSComputerName,
														    @{ n = 'Most Recent Patch' ; e = {$_.HotfixID}},
															@{ n = 'Installed On' ; e = {"$($_.InstalledOn.Month)/$($_.InstalledOn.Day)/$($_.InstalledOn.Year)"}}, 
															@{ n = "Compliant? (Installed within 180 days of $($checkDateDisplayOut)?)" ; e = {$checkDate.adddays(-180) -lt $_.InstalledOn}},
                                                            @{ n = "Days Past Due (+) or Until Due (-)" ; e = { (New-TimeSpan -Start $_.InstalledOn -End $checkDate.adddays(-180)).Days }}
                    }
                    Catch { $errorList.Add( @{ 'Hostname' = $currComp ; 'Exception' = $_.Exception.Message } ) }
				} | Sort-Object 'Days Past Due (+) or Until Due (-)' -Descending -OutVariable Export | format-table 
			}
			else {
				$_comps | ForEach-Object {
                    $currComp = $_
					Try {    
                        $wmiHash = Get-WmiObject -ComputerName $_ -Class 'Win32_QuickFixEngineering' -ErrorAction Stop
					    $wmiHash | select-object -Property PSComputerName, Description, HotFixID, InstalledBy, @{n='InstalledOn';e={"$($_.InstalledOn.Month)/$($_.InstalledOn.Day)/$($_.InstalledOn.Year)"}} -OutVariable Export
                        if ($_saveToFile) { $Export | export-CSV -Path $_path -NoTypeInformation -Append }
                    }
                    Catch { $errorList.Add( @{ 'Hostname' = $currComp ; 'Exception' = $_.Exception.Message } ) }
				} | format-table
			}
        }
    }

    else {
        if (!$userPassedGroupByHostName) {
            write-output "`n* Grouping by hostname will result in a data set that includes only patches applied,  *"
            write-output   "* one row per hostname. The 'Patched' attribute will only yield false if NONE of the  *"
            write-output   "* specified patches have been applied. (i.e. 'Patched' will yield ""True"" so long as    *"
            write-output   "*  at least one of the patches exists.) If grouping by hostname is not enabled, each  *"
            write-output   "*   patch status ('True' or 'False') is shown for each hostname on a dedicated row,   *"
            write-output   "*                                grouped by patch.                                    *`n"
    
            do {
                $groupByHostName = read-host -prompt "Group by Hostname? (Y or N) [Default=N]"
            }
            while ($groupByHostName.ToUpper() -ne "Y" -and $groupByHostName.ToUpper() -ne "N" -and
                   $groupByHostName.ToUpper() -ne "B" -and $groupByHostName.ToUpper() -ne "Q" -and
                   ![string]::IsNullOrEmpty($groupByHostName))
        }
        else { $groupByHostName = $userPassedGroupByHostName }

        if ($groupByHostName -eq "Q") { exit }

        if ($groupByHostName.ToUpper() -eq "N" -or $groupByHostName.ToUpper() -eq "Y" -or [string]::IsNullOrEmpty($groupByHostName)) {
            write-output "`nRunning...Please wait..."
            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        }
    
        if ($groupByHostName.ToUpper() -eq "N" -or [string]::IsNullOrEmpty($groupByHostName)) {
            #This statement is to avoid appending the last patch check twice if the default is used.
            $groupByHostName = "N"
            
            $_patches | ForEach-Object {
	            $currentPatch = $_
                $myHash = @{
		            Filter = 'HotFixID = "{0}"' -f $_  
		            ComputerName = $_comps     
		            Class = 'Win32_QuickFixEngineering' 
	            }
                # This Try/Catch block is not in effect because the Get-WmiObject call is not set to '-ErrorAction stop' (required for error handling non-terminating errors).
                # Need to use a different approach for error handling here if needed, perhaps a distinct Get-WmiObject call for each comp...
                Try {
	                $wmiHash = Get-WmiObject @myHash | Group-Object PSComputerName -AsHashTable -AsString

	                if ($_noConsoleOut) { 
                        $_comps | select-object @{ n = 'Hostname'; e = {$_}},
                                                @{ n = 'Patch' ; e = { $currentPatch } },
                                                @{ n = 'Patched' ; e = { ($wmiHash -ne $null -and $wmiHash.ContainsKey($_)) } },
		                                        @{ n = 'Date Installed' ; e = { 
                                                                                  if ($wmiHash -and $wmiHash.ContainsKey($_)) {"$($wmiHash[$_].InstalledOn.Month)/$($wmiHash[$_].InstalledOn.Day)/$($wmiHash[$_].InstalledOn.Year)"} 
                                                                                  else {"N/A"} 
                                                                               } } -OutVariable Export *>$null
                    }

                    else {
                        $_comps | select-object @{ n = 'Hostname'; e = {$_}},
                                                @{ n = 'Patch' ; e = { $currentPatch } },
                                                @{ n = 'Patched' ; e = { ($wmiHash -ne $null -and $wmiHash.ContainsKey($_)) } },
		                                        @{ n = 'Date Installed' ; e = { 
                                                                                  if ($wmiHash -and $wmiHash.ContainsKey($_)) {"$($wmiHash[$_].InstalledOn.Month)/$($wmiHash[$_].InstalledOn.Day)/$($wmiHash[$_].InstalledOn.Year)"} 
                                                                                  else {"N/A"} 
                                                                               } } -OutVariable Export
                    }

                    if ($_saveToFile) { $Export | export-CSV -Path $_path -NoTypeInformation -Append }
                }
                Catch { $errorList.Add( @{ 'Hostname' = $currComp ; 'Exception' = $_.Exception.Message } ) }
            } | format-table
        }

        elseif ($groupByHostName.ToUpper() -eq "Y") {
            $myHash = @{
                Filter = (($Patches | ForEach-Object { 'HotFixID = "{0}"' -f $_ } ) -join " OR ")
		        ComputerName = $_comps     
		        Class = 'Win32_QuickFixEngineering' 
	        }
            # This Try/Catch block is not in effect because the Get-WmiObject call is not set to '-ErrorAction stop' (required for error handling non-terminating errors).
            # Need to use a different approach for error handling here if needed, perhaps a distinct Get-WmiObject call for each comp...
            Try {
	            $wmiHash = Get-WmiObject @myHash | Group-Object PSComputerName -AsHashTable -AsString
        
                if ($_noConsoleOut) {
	                $_comps | select-object @{ n = 'Hostname'; e = {$_}},
                                            @{ n = 'Patched' ; e = { ($wmiHash -ne $null -and $wmiHash.ContainsKey($_)) } },
		                                    @{ n = 'Patches Found' ; e = { 
                                                                            if ($wmiHash -and $wmiHash.ContainsKey($_)) {$wmiHash[$_].HotFixID} 
                                                                            else {"NONE"} 
                                                                          } },
		                                     @{ n = 'Date Installed' ; e = { 
                                                                              if ($wmiHash -and $wmiHash.ContainsKey($_)) {"$($wmiHash[$_].InstalledOn.Month)/$($wmiHash[$_].InstalledOn.Day)/$($wmiHash[$_].InstalledOn.Year)"} 
                                                                              else {"N/A"} 
                                                                           } } -OutVariable Export *>$null
                }

                else {
                    $_comps | select-object @{ n = 'Hostname'; e = {$_}},
                                            @{ n = 'Patched' ; e = { ($wmiHash -ne $null -and $wmiHash.ContainsKey($_)) } },
		                                    @{ n = 'Patches Found' ; e = { 
                                                                            if ($wmiHash -and $wmiHash.ContainsKey($_)) {$wmiHash[$_].HotFixID} 
                                                                            else {"NONE"} 
                                                                         } },
		                                    @{ n = 'Date Installed' ; e = { 
                                                                             if ($wmiHash -and $wmiHash.ContainsKey($_)) {"$($wmiHash[$_].InstalledOn.Month)/$($wmiHash[$_].InstalledOn.Day)/$($wmiHash[$_].InstalledOn.Year)"} 
                                                                             else {"N/A"} 
                                                                           } } -OutVariable Export | format-table
                }
            }
            Catch { $errorList.Add( @{ 'Hostname' = $currComp ; 'Exception' = $_.Exception.Message } ) }
        }
    }

    if ((($groupByHostName -and $groupByHostName.ToUpper() -eq "Y") -or $_complianceCheck) -and $_saveToFile) {
        $Export | export-CSV -Path $_path -NoTypeInformation -Append 
    }

    if ($errorList.Count -gt 0) {
        if ($_noConsoleOut) {
            $errorList | Select-Object @{ n = 'Unavailable Hosts' ; e = {$_.Hostname}},
                                       @{ n = 'Exceptions Generated' ; e = {$_.Exception}} -OutVariable Export *>$null
        }
        else {
            write-Output "`n`t`t`t*** Unreachable Nodes ***"
            $errorList | Select-Object @{ n = 'Unavailable Hosts' ; e = {$_.Hostname}},
                                       @{ n = 'Exceptions Generated' ; e = {$_.Exception}} -OutVariable Export
        }

        if($_saveToFile) { $Export | export-CSV -Path $errorPath -NoTypeInformation }
    }

    if ([string]::IsNullOrEmpty($groupByHostName) -or $groupByHostName.ToUpper() -eq "N" -or $groupByHostName.ToUpper() -eq "Y") {
            $elapsedTime = $stopWatch.Elapsed.TotalSeconds
            write-output "`nExecution Complete. $elapsedTime seconds.`n"   
    }
}

function outputPrompt {

    param ($_comps, 
		   $_patches,
           [bool]$_listAll,
		   [bool]$_complianceCheck)

    #write-output "`n"
	
    if ($userPassedOutputMode -notin 1..3) {	    
        do { 
            $outputMode = read-host -prompt "`nSave To File (1), Console Output (2), or Both (3) [Default=3]"
            if (!$outputMode) { $outputMode = 3 }
        }
        while ($outputMode -ne 1 -and $outputMode -ne 2 -and $outputMode -ne 3 -and
               $outputMode.ToUpper() -ne "Q" -and $outputMode.ToUpper() -ne "B")
    }
    else { $outputMode = $userPassedOutputMode }

    if ($outputMode -eq "Q") { exit }

    $defaultOutFileName = "PatchCheckerOut-$(Get-Date -Format MMddyyyy_HHmmss)"

    if ($outputMode -eq 1 -or $outputMode -eq 3) {
                
        if (!$userPassedOutputFileName) {
            write-output "`n* To save to any directory other than the current, enter fully qualified path name. *"
            write-output   "*              Leave this entry blank to use the default file name of               *"
            write-output   "*                       '$defaultOutFileName.csv',                      *"
            write-output   "*                which will save to the current working directory.                  *"
            write-output   "*                                                                                   *"
            write-output   "*  THE '.csv' EXTENSION WILL BE APPENDED AUTOMATICALLY TO THE FILENAME SPECIFIED.   *"
            write-output   "*                                                                                   *"
            write-output   "*                              OPTIONS 2 & 3 ONLY:                                  *"
            write-output   "*        Errors will log to a sepearte file with the same name + '_ERRORS'.         *"
            write-output   "*                                                                                   *"
            write-output   "*                                 OPTION 1 ONLY:                                    *"
            write-output   "*  Errors will not be indicated in output file. However, any patch check resulting  *"
            write-output   "*   in an error will indicate a 'Patched' status of False. Check node accordingly.  *`n"
        }

        do { 
            if (!$UserPassedOutputFileName) { $fileName = read-host -prompt "Save As [Default=$defaultOutFileName.csv]" }
            elseif ($userPassedOutputFileName -eq "Default") { $fileName = $null }
            else { $fileName = $UserPassedOutputFileName }

            if ($fileName -and $fileName.ToUpper() -eq "Q") { exit }

            $pathIsValid = $true
            $overwriteConfirmed = "Y"

            if (![string]::IsNullOrEmpty($fileName) -and $fileName.ToUpper() -ne "B") {

                #$fileName += ".csv"
                                        
                $pathIsValid = Test-Path -Path $fileName -IsValid

                if ($pathIsValid) {
                        
                    $fileAlreadyExists = Test-Path -Path $fileName

                    if ($fileAlreadyExists) {

                        do {

                            $overWriteConfirmed = read-host -prompt "File '$fileName' Already Exists. Overwrite (Y) or Cancel (N)"
                                    
                            if ($overWriteConfirmed.ToUpper() -eq "Q") { exit }

                        } while ($overWriteConfirmed.ToUpper() -ne "Y" -and $overWriteConfirmed.ToUpper() -ne "N" -and 
                                    $overWriteConfirmed.ToUpper() -ne "B")
                    }
                }

                else { write-output "* Path is not valid. Try again. ('b' to return to main, 'q' to quit.) *" }
            }
        }
        while (!$pathIsValid -or $overWriteConfirmed.ToUpper() -eq "N")

        if (!$fileName -and $outputMode -eq 1) { 
            processRequest $comps $patches $true $defaultOutFileName -_noConsoleOut $true -_listAll $_listAll -_complianceCheck $_complianceCheck
        }
        elseif(!$fileName) { processRequest $comps $patches $true $defaultOutFileName -_listAll $_listAll -_complianceCheck $_complianceCheck}
        elseif ($fileName.ToUpper() -ne "B" -and $overWriteConfirmed.ToUpper() -ne "B" -and $outputMode -eq 1) { 
            processRequest $comps $patches $true $fileName $true $_listAll $_complianceCheck
        }
        elseif ($fileName.ToUpper() -ne "B" -and $overWriteConfirmed.ToUpper() -ne "B") {
            processRequest $comps $patches $true $fileName -_listAll $_listAll -_complianceCheck $_complianceCheck
        }
    }

    elseif ($outputMode.ToUpper() -eq 2) { processRequest $comps $patches -_listAll $_listAll -_complianceCheck $_complianceCheck}	
}    

clear-host

write-output "`n"
write-output "`t`t`t`t`t*!*!* Patch Checker *!*!*"

$option = $comps = $patches = $compsInput = $patchesInput = $compsFilePath = $patchesFilePath = $commandLineProvidedOption = 
$allNodesTriggeredFromCL = $userPassedOutputMode = $userPassedGroupByHostName = $userPassedOutputFileName = $userPassedCheckComplianceAsOfDate = $null

([string]$args).split('-') | %{ 
                                if ($_.Split(' ')[0] -eq "Option") { $option = $_.Split(' ')[1] } 
                                elseif ($_.Split(' ')[0] -eq "CompsFilePath") { $compsFilePath = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "PatchesFilePath") { $patchesFilePath = $_.Split(' ')[1] } 
                                elseif ($_.Split(' ')[0] -eq "AllNodes") { $allNodesTriggeredFromCL = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "OutputMode") { $UserPassedOutputMode = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "GroupOutputByHostName") { $userPassedGroupByHostName = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "OutputFile") { $userPassedOutputFileName = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "CheckComplianceAsOfDate") { $userPassedCheckComplianceAsOfDate = $_.Split(' ')[1] }
                              }
if ($option) { $commandLineProvidedOption = $true }
if ($compsFilePath) { $usePassedCompsFilePath = $true } else { $usePassedCompsFilePath = $false }
if ($patchesFilePath) { $usePassedPatchesFilePath = $true } else { $usePassedPatchesFilePath = $false }
if ($allNodesTriggeredFromCL -and $allNodesTriggeredFromCL -eq "TRUE") { $allNodesTriggeredFromCL = $true } else { $allNodesTriggeredFromCL = $false }
$firstLoop = $true
$readFileOrManualEntryOrAllNodes = 0
if ($userPassedOutputMode -and $userPassedOutputMode -notin 1..3) { 
    if ($userPassedOutputMode -eq "Default") { $userPassedOutputMode = 3 } else { $userPassedOutputMode = $false }
}
if ($userPassedGroupByHostName -and $userPassedGroupByHostName -ne "Y" -and $userPassedGroupByHostName -ne "N") {
    if ($userPassedGroupByHostName -eq "Default") { $userPassedGroupByHostName = "N" }
    else { $userPassedGroupByHostName = $null }
}

do {
   
	if (!$commandLineProvidedOption -or !$firstLoop) {
        write-output "`n`tSelect an option below by pressing its corresponding number."
        write-output "`t(From any prompt, enter 'b' to return to main, 'q' to exit.)`n"
	    write-output "1. Validate Patches"
	    write-output "2. List Patches"
	    write-output "3. Compliance Check"
        write-output "4. Exit`n"
	
	    do { $option = read-host -prompt $($env:UserName) } 
        while ($option.ToUpper() -ne "Q" -and 
               $option -ne 1 -and $option -ne 2 -and $option -ne 3 -and $option -ne 4)

        if ($option.ToUpper() -eq "Q" -or $option -eq 4) { exit }

        write-host
    }
    if ($firstLoop) { 
        if ($commandLineProvidedOption) {
            $options = "Validate Patches", "List Patches", "Compliance Check"
            write-output "`nOption $option '$($options[$option])' selected via command line..."
        }
        if ($compsFilePath) { write-output "File '$compsFilePath' specified for node list input via command line..." }
        if ($patchesFilePath) { write-output "File '$patchesFilePath' specified for patch list input via command line..." }
        if ($allNodesTriggeredFromCL) { write-output "Check all nodes option specified via command line..." }
        if ($outputMode) { 
            $outputModes = "Save to File", "Console Output", "Save to File and Console Output"
            write-output "Output mode $outputMode '$($outputModes[$outputMode])' specified via command line..."
        }
        if ($userPassedGroupByHostName) { write-output "Group by Hostname specified via command line..." }
        if ($userPassedOutputFileName) { write-output "File '$userPassedOutputFileName' specified for results output via command line..." }
        if ($userPassedCheckComplianceAsOfDate) { write-output "Date of '$userPassedCheckComplianceAsOfDate' specified for 'compliant as of' check date specified via command line..." }
        if ($commandLineProvidedOption -or $compsFilePath -or $patchesFilePath -or $allNodesTriggeredFromCL -or $outputMode -or 
            $userPassedGroupByHostName -or $userPassedGroupByHostName -or $userPassedCheckComplianceAsOfDate) { write-host }
    }

    $comps = New-Object System.Collections.Generic.List[System.Object]
    $patches = New-Object System.Collections.Generic.List[System.Object]
	
    if ($option -eq 1 -and (((!$compsFilePath -or !$patchesFilePath) -and $firstLoop) -or !$firstLoop)) {
        do {
            $readFileOrManualEntryOrAllNodes = read-host -prompt "Read Input From File (1) or Manual Entry (2)"
        } 
        while ($readFileOrManualEntryOrAllNodes -ne 1 -and $readFileOrManualEntryOrAllNodes -ne 2 -and 
                $readFileOrManualEntryOrAllNodes.ToUpper() -ne "B" -and $readFileOrManualEntryOrAllNodes.ToUpper() -ne "Q")
    }

    elseif ($option -ne 1 -and !$allNodesTriggeredFromCL -and ((!$compsFilePath -and $firstLoop) -or !$firstLoop)) {
        do {
            $readFileOrManualEntryOrAllNodes = read-host -prompt "Read Input From File (1) or Manual Entry (2) or All Nodes (3) [Default = All Nodes]"
            if (!$readFileOrManualEntryOrAllNodes) { $readFileOrManualEntryOrAllNodes = 3 }
        } 
        while ($readFileOrManualEntryOrAllNodes -ne 1 -and $readFileOrManualEntryOrAllNodes -ne 2 -and $readFileOrManualEntryOrAllNodes -ne 3 -and
                $readFileOrManualEntryOrAllNodes.ToUpper() -ne "B" -and $readFileOrManualEntryOrAllNodes.ToUpper() -ne "Q")
    }

    if ($readFileOrManualEntryOrAllNodes -eq "Q") { exit }
        
    if ((!$allNodesTriggeredFromCL -or $option -eq 1) -and 
        ($readFileOrManualEntryOrAllNodes -eq 1 -or $usePassedCompsFilePath -or $usePassedPatchesFilePath)) {
            
        if (!$usePassedCompsFilePath) { 
            write-output "`n** Remember To Enter Fully Qualified Filenames If Files Are Not In Current Directory **" 
            write-output "`n`tFile must contain one hostname per line.`n"
        }
        do {
            if (!$usePassedCompsFilePath) { $compsFilePath = read-host -prompt "Hostname Input File" }
            if (![string]::IsNullOrEmpty($compsFilePath) -and $compsFilePath.ToUpper() -ne "B" -and $compsFilePath.ToUpper() -ne "Q") { 
                $fileNotFound = $(!$(test-path $compsFilePath -PathType Leaf))
                if ($fileNotFound) { write-output "`n`tFile '$compsFilePath' Not Found or Path Specified is a Directory!`n" }
            }
            if($usePassedCompsFilePath -and $fileNotFound) {
                write-output "`n** Remember To Enter Fully Qualified Filenames If Files Are Not In Current Directory **" 
                write-output "`n`tFile must contain one hostname per line.`n"
            }
            $usePassedCompsFilePath = $false
        }
        while (([string]::IsNullOrEmpty($compsFilePath) -or $fileNotFound) -and 
                $compsFilePath.ToUpper() -ne "B" -and $compsFilePath.ToUpper() -ne "Q")
        if ($compsFilePath.ToUpper() -eq "Q") { exit }

        if ($compsFilePath.ToUpper() -ne "B" -and $option -eq 1) {

            if (!$usePassedPatchesFilePath) { write-output "`n`tFile must contain one patch per line.`n" }

            do {
                if (!$usePassedPatchesFilePath) { $patchesFilePath = read-host -prompt "Patches Input File" }
                if (![string]::IsNullOrEmpty($patchesFilePath) -and $patchesFilePath.ToUpper() -ne "B" -and $patchesFilePath.ToUpper() -ne "Q") { 
                    $fileNotFound = $(!$(test-path $patchesFilePath -PathType Leaf))
                    if ($fileNotFound) { write-output "`n`tFile Not Found or Path Specified is a Directory!`n" }
                }
                if($usePassedPatchesFilePath -and $fileNotFound) {
                    write-output "`n** Remember To Enter Fully Qualified Filenames If Files Are Not In Current Directory **" 
                    write-output "`n`tFile must contain one patch per line.`n"
                }
                $usePassedPatchesFilePath = $false 
            } 
            while (([string]::IsNullOrEmpty($patchesFilePath) -or $fileNotFound) -and 
                    ($patchesFilePath.ToUpper() -ne "B") -and ($patchesFilePath.ToUpper() -ne "Q"))
            if ($patchesFilePath.ToUpper() -eq "Q") { exit }
        }

        if ($compsFilePath.ToUpper() -ne "B" -and ($option -eq 2 -or $option -eq 3 -or $patchesFilePath.Toupper() -ne "B")) { $comps = Get-Content $compsFilePath -ErrorAction Stop }
        if ($compsFilePath.ToUpper() -ne "B" -and $option -eq 1 -and $patchesFilePath.Toupper() -ne "B") { $patches = Get-Content $patchesFilePath -ErrorAction Stop }
    }
        
    elseif ($readFileOrManualEntryOrAllNodes -eq 2) {

        $compCount = 0
        $patchCount = 0

        write-output "`n`nEnter 'f' once finished. Minimum 1 entry. (Enter 'b' for back or 'q' to exit.)`n"
        do {
            $compsInput = read-host -prompt "Hostname ($($compCount + 1))"
            if ($compsInput.ToUpper() -ne "F" -and $compsInput.ToUpper() -ne "B" -and $compsInput.ToUpper() -ne "Q" -and 
                ![string]::IsNullOrEmpty($compsInput)) {
                $comps.Add($compsInput)
                $compCount++
                }
        }
        while (($compsInput.ToUpper() -ne "F" -and $compsInput.ToUpper() -ne "B" -and $compsInput.ToUpper() -ne "Q") -or 
                ($compCount -lt 1 -and $compsInput.ToUpper() -ne "B"))

        if ($compsInput.ToUpper() -eq "Q") { exit }
		    
        if ($compsInput.ToUpper() -eq "F" -and $option -eq 1) {
                
            write-output "============"

            do {
                $patchesInput = read-host -prompt "Patch ($($patchCount + 1))"
                if ($patchesInput.ToUpper() -ne "F" -and $patchesInput.ToUpper() -ne "B" -and $patchesInput.ToUpper() -ne "Q" -and 
                ![string]::IsNullOrEmpty($patchesInput)) {
                    $patches.Add($patchesInput)
                    $patchCount++
                    }
            }
            while (($patchesInput.ToUpper() -ne "F" -and $patchesInput.ToUpper() -ne "B" -and $patchesInput.ToUpper() -ne "Q") -or 
                    ($patchCount -lt 1 -and $patchesInput.ToUpper() -ne "B"))

            if ($patchesInput.ToUpper() -eq "Q") { exit }
        }
    }

    elseif ($readFileOrManualEntryOrAllNodes -eq 3 -or $allNodesTriggeredFromCL) {
        Get-ADObject -LDAPFilter "(objectClass=computer)" | select-object name | Set-Variable -name compsTemp
        $compsTemp | %{ $comps.Add($_.Name) }
        $compsInput = "TRUE"
    }

    if ($readFileOrManualEntryOrAllNodes -ne "B" -and
        ((![string]::IsNullOrEmpty($compsInput) -and $compsInput.ToUpper() -ne "B") -or
        (![string]::IsNullOrEmpty($compsFilePath) -and $compsFilePath.ToUpper() -ne "B")) -and
        ($option -eq 2 -or $option -eq 3 -or
       ((![string]::IsNullOrEmpty($patchesInput) -and $patchesInput.ToUpper() -ne "B") -or
        (![string]::IsNullOrEmpty($patchesFilePath) -and $patchesFilePath.ToUpper() -ne "B")))) {
            if ($option -eq 1) { $listAllPatches = $false } else { $listAllPatches = $true }
            if ($option -eq 3) { $complianceCheck = $true } else { $complianceCheck = $false }
            outputPrompt $comps $patches $listAllPatches $complianceCheck
	}

    $firstLoop = $allNodesTriggeredFromCL = $userPassedOutputMode = $false
    $userPassedOutputFileName = $userPassedCheckComplianceAsOfDate = $userPassedGroupByHostName = $null
}
while (($option -ne 4))


<# RERERENCES
 # https://www.red-gate.com/simple-talk/sysadmin/powershell/the-complete-guide-to-powershell-punctuation/
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-5.1
 # https://powershell.org/2019/04/hear-hear-for-here-strings/
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-wmiobject?view=powershell-5.1
 # https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-quickfixengineering
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-object?view=powershell-7
 # https://stackoverflow.com/questions/30200655/what-does-the-n-and-e-represent-in-this-select-statement
 # https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-powershell-1.0/ff730948(v=technet.10)?redirectedfrom=MSDN
 # https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-powershell-1.0/ee692795(v%3dtechnet.10)https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-host?view=powershell-7
 # https://devblogs.microsoft.com/scripting/powershell-looping-understanding-and-using-do-while/
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_if?view=powershell-7
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/format-table?view=powershell-7
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_format.ps1xml?view=powershell-7#sample-xml-for-a-format-table-custom-view
 # https://stackoverflow.com/questions/3235850/how-to-enter-a-multi-line-command
 # https://stackoverflow.com/questions/31793449/how-to-assign-multiple-lines-string-in-powershell-console
 # https://stackoverflow.com/questions/2085744/how-do-i-get-the-current-username-in-windows-powershell
 # https://www.google.com/search?q=escape+character+for+newline+and+tab+in+powershell&rlz=1C1GGRV_enUS818US818&oq=escape+character+for+newline+and+tab+in+powershell&aqs=chrome..69i57.8292j0j7&sourceid=chrome&ie=UTF-8
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_logical_operators?view=powers
 # https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.psdefaultvalueattribute?view=pscore-6.2.0hell-7
 # https://ss64.com/ps/syntax-datatypes.html
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_return?view=powershell-7
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes?view=powershell-7
 # https://www.google.com/search?q=exit+function+powershell&rlz=1C1GGRV_enUS818US818&oq=exit+function+powershell&aqs=chrome.0.0l8.3422j0j7&sourceid=chrome&ie=UTF-8
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_quoting_rules?view=powershell-7
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions?view=powershell-7
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_do?view=powershell-7
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-7
 # https://stackoverflow.com/questions/2022326/terminating-a-script-in-powershell
 # https://stackoverflow.com/questions/14085077/powershell-how-can-i-to-force-to-get-a-result-as-an-array-instead-of-object
 # https://en.wikiversity.org/wiki/PowerShell/Functions
 # https://stackoverflow.com/questions/25375467/powershell-match-with-containskey-set-value-of-hashtable-dont-work
 # https://stackoverflow.com/questions/45008016/check-if-a-string-is-not-null-or-empty
 # https://stackoverflow.com/questions/14620290/array-add-vs
 # https://stackoverflow.com/questions/18780956/suppress-console-output-in-powershell
 # https://pscustomobject.github.io/powershell/howto/Measure-Script-Time/
 # https://www.pluralsight.com/blog/tutorials/measure-powershell-scripts-speed
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7
 # https://stackoverflow.com/questions/5097125/powershell-comparing-dates
 # https://www.google.com/search?q=line+continuation+character+powershell&rlz=1C1GGRV_enUS818US818&oq=line+continuation+character+powershell&aqs=chrome..69i57j0l5j69i59j0.6289j0j7&sourceid=chrome&ie=UTF-8
 # https://stackoverflow.com/questions/9181473/powershell-testing-a-variable-that-hasnt-being-assign-yet
 # https://stackoverflow.com/questions/44151502/getting-the-no-of-days-difference-from-the-two-dates-in-powershell/44151764
 # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-7
#>
function queryFileNameOut {
    param ([string]$_userPassedMismatchFileName,
           [string]$_userPassedAllServicesFileName=$null,
           [bool]$_forMismatch=$true)

    if ($_forMismatch) { $defaultMismatchOutFileName = "ServicesCompareResults_Mismatches-$(Get-Date -Format MMddyyyy_HHmmss)" }
    else { $defaultAllOutFileName = "ServicesCompareResults_AllServices-$(Get-Date -Format MMddyyyy_HHmmss)" }
    
    if(($_forMismatch -and !$_userPassedMismatchFileName) -or (!$_forMismatch -and !$_userPassedAllServicesFileName)) {          
        write-host "`n* To save to any directory other than the current, enter fully qualified path name. *"
        write-host   "*              Leave this entry blank to use the default file name of               *"
        write-host   "*             $(if($_forMismatch){" '$defaultMismatchOutFileName.csv"} else{"'$defaultAllOutFileName.csv"})',             *"
        write-host   "*                 which will save to the current working directory.                 *"
        write-host   "*                                                                                   *"
        write-host   "*  THE '.csv' EXTENSION WILL BE APPENDED AUTOMATICALLY TO THE FILENAME SPECIFIED.   *`n"
    }

    do { 
        if ($_forMismatch -and !$_userPassedMismatchFileName) { $fileName = read-host -prompt "Save 'Mismatch' Results As [Default=$defaultMismatchOutFileName]" }
        elseif (!$_forMismatch -and !$_userPassedAllServicesFileName) { $fileName = read-host -prompt "Save 'All Services' Results As [Default=$defaultAllOutFileName]" }
        elseif ($_userPassedMismatchFileName) { $fileName = $_userPassedMismatchFileName }
        elseif ($_userPassedAllServicesFileName) { $fileName = $_userPassedAllServicesFileName }

        $_userPassedMismatchFileName = $null
        $_userPassedAllServicesFileName = $null

        if ($fileName -and $fileName -eq "Q") { exit }

        if ($_forMismatch -and !$fileName) { $fileName = $defaultMismatchOutFileName }
        elseif (!$fileName) { $fileName = $defaultAllOutFileName }

        $pathIsValid = $true
        $overwriteConfirmed = "Y"

        $fileName += ".csv"
                                        
        $pathIsValid = Test-Path -Path $fileName -IsValid

        if ($pathIsValid) {
                        
            $fileAlreadyExists = Test-Path -Path $fileName

            if ($fileAlreadyExists) {

                do {

                    $overWriteConfirmed = read-host -prompt "File '$fileName' Already Exists. Overwrite (Y) or Cancel (N) or Quit (Q)"
                                    
                    if ($overWriteConfirmed -eq "Q") { exit }

                } while ($overWriteConfirmed -ne "Y" -and $overWriteConfirmed -ne "N")
            }
        }

        else { write-output "* Path is not valid. Try again. ('q' to quit.) *" }
    }
    while (!$pathIsValid -or $overWriteConfirmed -eq "N")
    
    return $fileName
}

#param([Parameter][string]$Node1,
#      [Parameter][string]$Node2,
#      [Parameter][int32]$OutputMode,
#      [Parameter][bool]$ShowAllServices=$false,
#      [Parameter][string]$Property)

clear-host

$misMatches = $results = $Node1 = $Node2 = $OutputMode = $ShowAllServices = $Property = $MismatchFileName = $AllServicesFileName = $null

write-output "`n"
write-output "`t`t`t`t`t`t`t*%*%*  Services Compare *%*%*`n"

([string]$args).split('-') | %{ 
                                if ($_.Split(' ')[0] -eq "Node1") { $Node1 = $_.Split(' ')[1] } 
                                elseif ($_.Split(' ')[0] -eq "Node2") { $Node2 = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "OutputMode") { $OutputMode = $_.Split(' ')[1] } 
                                elseif ($_.Split(' ')[0] -eq "ShowAllServices") { $ShowAllServices = "True" }
                                elseif ($_.Split(' ')[0] -eq "Property") { $Property = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "MismatchFileName") { $MismatchFileName = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0] -eq "AllServicesFileName") { $AllServicesFileName = $_.Split(' ')[1] }
                              }

if (!$Node1) { $Node1 = read-host -prompt "Node 1" ; if ($Node1 -eq "Q") { exit } }
if (!$Node2) { $Node2 = read-host -prompt "Node 2" ;  if ($Node2 -eq "Q") { exit } }

if (!$OutputMode) { do { $OutputMode = read-host -prompt "`nSave To File (1), Console Output (2), or Both (3)" ;  if (([string]$OutputMode) -eq "Q") { exit } } 
                    while ($OutputMode -ne 1 -and $OutputMode -ne 2 -and $OutputMode -ne 3) }

# NOTE: There is no prompt for the "Show All Services" option. 
# To use this option, call the script from the command line with the -ShowAllServices flag.
# e.g. ".\ServicesCompareV1.0.ps1 -ShowAllServices"
if ($ShowAllServices -and $ShowAllServices -ne "FALSE" -and ($OutputMode -eq 1 -or $OutputMode -eq 3)) { 
    $fileNameForMisMatch = queryFileNameOut $MismatchFileName $null
    $fileNameForAllServices = queryFileNameOut $null $AllServicesFileName $false
}
elseif ($OutputMode -eq 1 -or $OutputMode -eq 3) { $fileNameForMisMatch = queryFileNameOut $MismatchFileName }
    

$CompareOptions = "1) StartType", "2) Status", "3) DisplayName", "4) CanShutdown", "5) CanStop", "6) CanPauseAndContinue",
                  "7) DependentServices", "8) ServicesDependedOn", "9) RequiredServices", "10) ServiceType", "11) ServiceHandle", 
                  "12) Site", "13) Container"
if (!$Property) { 
    do { 
        $Property = read-host -prompt "`nService Property to Compare? [Default=StartType] (To Display Options, Enter 'C')"
        if ($Property -eq "Q") { exit }
        if ($Property -eq "C") {
            #write-output "`n"
            $CompareOptions | %{ write-output $_ }
        }
        if (!$Property) { $Property = "StartType" }
    }
    while ($Property -notin 1..13 -and $Property -notin $($CompareOptions | %{$_.Split(' ')[1]}))
}

if ($Property -in 1..13) { $Property = $CompareOptions[$Property-1].Split(' ')[1] }
if ($Property -notin $($CompareOptions | %{$_.Split(' ')[1]})) { 
    write-output "`nError: Compare Property '$Property' Not Valid. Rerun using one of the following for 'Property to Compare':"
    $CompareOptions | %{ write-output $_ }
    exit
}

write-output "`nRunning...Please wait..."

$results = get-service -ComputerName $Node1, $Node2 |  select-object MachineName, Name, $Property | group-object Name | sort-object Name -OutVariable Export 
$misMatches = New-Object System.Collections.Generic.List[System.Object] 
$results | ForEach-Object {
    if ([string]$_.Group[0].$($Property) -ne [string]$_.Group[1].$($Property)) { 
        if ($_.Group[0].MachineName -eq $Node1) {
            $mismatches.Add(@{'Service' = $_.Name ; "$($_.Group[0].MachineName)_$($Property)" = "$($_.Group[0].$($Property))" ; "$($_.Group[1].MachineName)_$($Property)" = "$($_.Group[1].$($Property))" })
        }
        else {
            $mismatches.Add(@{'Service' = $_.Name ; "$($_.Group[1].MachineName)_$($Property)" = "$($_.Group[1].$($Property))" ; "$($_.Group[0].MachineName)_$($Property)" = "$($_.Group[0].$($Property))" })
        }
    }
}
$Node1_Property = "$($Node1)_$($Property)"
$Node2_Property = "$($Node2)_$($Property)"

if ($misMatches -and $OutputMode -in 2..3) { 
    write-output "`n`t`t* * * Mismatches * * *" 
    $mismatches | select-object @{ n = 'Service' ; e = {$_.Service}},
                                @{ n = "$($Node1_Property)" ; e = {$(if ($_.$($Node1_Property)) { $_.$($Node1_Property) } else { "[Service Not Found]"})}},
                                @{ n = "$($Node2_Property)" ; e = {$(if ($_.$($Node2_Property)) { $_.$($Node2_Property) } else { "[Service Not Found]"})}} -OutVariable MismatchExport | Format-Table
}
else {
     $mismatches | select-object @{ n = 'Service' ; e = {$_.Service}},
                                 @{ n = "$($Node1_Property)" ; e = {$(if ($_.$($Node1_Property)) { $_.$($Node1_Property) } else { "[Service Not Found]"})}},
                                 @{ n = "$($Node2_Property)" ; e = {$(if ($_.$($Node2_Property)) { $_.$($Node2_Property) } else { "[Service Not Found]"})}} -OutVariable MismatchExport >$null
}

if ($ShowAllServices -and $ShowAllServices -ne "FALSE" -and $OutputMode -in 2..3) {
    write-output "`n`n`t`t* * * All Services * * *" 
    $results | select-object @{ n = "Name" ; e = {$_.Name}},
                             @{ n = "Result_Set" ; e = { $( if($_.Group[0].MachineName -and $_.Group[1].MachineName -and $_.Group[0].MachineName -eq $Node1) 
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}, @{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }  
                                                            elseif($_.Group[0].MachineName -and $_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}, @{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            elseif($_.Group[0].MachineName -and !$_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            else
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }
                                                         )
                                                       } },
                             @{ n = "Count" ; e = {$_.Count} } -OutVariable AllServicesExport  | format-table @{ n = "Name" ; e = {$_.Name} ; a = "Left"},
                                                                                                              @{ n = "Result Set" ; e = {$_.Result_Set} ; a = "Left"},
                                                                                                              @{ n = "Count" ; e = {$_.Count} ; a = "Left"} 
}
elseif ($ShowAllServices -and $ShowAllServices -ne "FALSE") {
    $results | select-object @{ n = "Name" ; e = {$_.Name}},
                             @{ n = "Result_Set" ; e = { $( if($_.Group[0].MachineName -and $_.Group[1].MachineName -and $_.Group[0].MachineName -eq $Node1) 
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}, @{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }  
                                                            elseif($_.Group[0].MachineName -and $_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}, @{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            elseif($_.Group[0].MachineName -and !$_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            else
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }
                                                         )
                                                       } },
                             @{ n = "Count" ; e = {$_.Count} } -OutVariable AllServicesExport  | format-table @{ n = "Name" ; e = {$_.Name} ; a = "Left"},
                                                                                                              @{ n = "Result Set" ; e = {$_.Result_Set} ; a = "Left"},
                                                                                                              @{ n = "Count" ; e = {$_.Count} ; a = "Left"} >$null
}

if ($OutputMode -eq 1 -or $OutputMode -eq 3) {
    $MismatchExport | export-CSV -Path $fileNameForMismatch -NoTypeInformation
    if ($ShowAllServices -and $ShowAllServices -ne "FALSE") { $AllServicesExport | export-CSV -Path $fileNameForAllServices -NoTypeInformation }
}

write-output "`n** Finished **"
write-host "`nPress enter to exit..." -NoNewLine
$Host.UI.ReadLine()

# References
# https://stackoverflow.com/questions/5592531/how-can-i-pass-an-argument-to-a-powershell-script
# https://stackoverflow.com/questions/41985736/how-can-you-check-if-a-variable-is-in-an-array-in-powershell
# https://stackoverflow.com/questions/30617758/splitting-a-string-into-separate-variables
# https://stackoverflow.com/questions/24525791/powershell-write-output-inside-if-does-not-output-anything
# https://stackoverflow.com/questions/33707193/how-to-convert-string-to-integer-in-powershell/33707377
# https://stackoverflow.com/questions/27794898/powershell-pass-named-parameters-to-argumentlist
# https://www.google.com/search?q=.%7B%7D+in+powershell&rlz=1C1GGRV_enUS818US818&oq=.%7B%7D+in+powershell&aqs=chrome..69i57j0l4j69i65l3.3050j0j7&sourceid=chrome&ie=UTF-8
# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-typedata?view=powershell-7
# http://powershell-guru.com/powershell-best-practice-2-use-named-parameters-not-positional-and-partial-parameters/
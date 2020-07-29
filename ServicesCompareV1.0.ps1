function queryFileNameOut {
    param ([bool]$_forMismatch=$true)

    if ($_forMismatch) { $defaultMismatchOutFileName = "ServicesCompareResults_Mismatches-$(Get-Date -Format MMddyyyy_HHmmss).csv" }
    else { $defaultAllOutFileName = "ServicesCompareResults_AllServices-$(Get-Date -Format MMddyyyy_HHmmss).csv" }
                
    write-host "`n* To save to any directory other than the current, enter fully qualified path name. *"
    write-host   "*              Leave this entry blank to use the default file name of               *"
    write-host   "*             '$(if($_forMismatch){"$defaultMismatchOutFileName"} else{"$defaultAllOutFileName"})',              *"
    write-host   "*                 which will save to the current working directory.                 *"
    write-host   "*                                                                                   *"
    write-host   "*  THE '.csv' EXTENSION WILL BE APPENDED AUTOMATICALLY TO THE FILENAME SPECIFIED.   *`n"

    do { 
        if($_forMismatch) { $fileName = read-host -prompt "Save 'MisMatch' Results As [Default=$defaultMismatchOutFileName]" }
        else { $fileName = read-host -prompt "`nSave 'All Services' Results As [Default=$defaultAllOutFileName]" }

        if ($fileName -and $fileName.ToUpper() -eq "Q") { exit }

        $pathIsValid = $true
        $overwriteConfirmed = "Y"

        if (![string]::IsNullOrEmpty($fileName) -and $fileName.ToUpper() -ne "B") {

            $fileName += ".csv"
                                        
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
    
    if (!$fileName -and $_forMismatch) { $_fileNameForMismatch = $defaultMismatchOutFileName }
    elseif (!$fileName) { $_fileNameForAllServices = $defaultAllOutFileName }
    elseif ($_forMismatch) { $_fileNameForMismatch = $fileName }
    else { $_fileNameForAllServices = $fileName }

    if ($_forMismatch) { return $_fileNameForMismatch }
    else { return $_fileNameForAllServices }
}

#param([Parameter][string]$Node1,
#      [Parameter][string]$Node2,
#      [Parameter][int32]$OutputMode,
#      [Parameter][bool]$ShowAllServices=$false,
#      [Parameter][string]$Property)

clear-host

if ($misMatches) { clear $misMatches }
if ($results) { clear $results }
if ($Node1) { clear $Node1 }
if ($Node2) { clear $Node2 }
if ($OutputMode) { clear $OutputMode }
$ShowAllServices=$false
if ($Property) { clear $Property }

write-output "`n"
write-output "`t`t`t`t  *%*%*  Services Compare *%*%*`n"

write-output "Node1: $Node1, Node2: $Node2, OutputMode: $OutputMode, ShowAllServices: $ShowAllServices, Property: $Property"
([string]$args).split('-') | %{ 
                                if ($_.Split(' ')[0].ToUpper() -eq "Node1") { $Node1 = $_.Split(' ')[1] } 
                                elseif ($_.Split(' ')[0].ToUpper() -eq "Node2") { $Node2 = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0].ToUpper() -eq "OutputMode") { $OutputMode = $_.Split(' ')[1] } 
                                elseif ($_.Split(' ')[0].ToUpper() -eq "ShowAllServices") { $ShowAllServices = $_.Split(' ')[1] }
                                elseif ($_.Split(' ')[0].ToUpper() -eq "Property") { $Property = $_.Split(' ')[1] } 
                              }
write-output "Node1: $Node1, Node2: $Node2, OutputMode: $OutputMode, ShowAllServices: $ShowAllServices, Property: $Property `n`n"

if (!$Node1) { $Node1 = read-host -prompt "Node 1" ; if ($Node1.ToUpper() -eq "Q") { exit } }
if (!$Node2) { $Node2 = read-host -prompt "Node 2" ;  if ($Node2.ToUpper() -eq "Q") { exit } }

if (!$args["OutputMode"]) { do { $OutputMode = read-host -prompt "`nSave To File (1), Console Output (2), or Both (3)" ;  if (([string]$OutputMode).ToUpper() -eq "Q") { exit } } 
                    while ($OutputMode -ne 1 -and $OutputMode -ne 2 -and $OutputMode -ne 3) }

if ($ShowAllServices -and ($OutputMode -eq 1 -or $OutputMode -eq 3)) { 
    $fileNameForMisMatch = queryFileNameOut
    $fileNameForAllServices = queryFileNameOut $false
}
elseif ($OutputMode -eq 1 -or $OutputMode -eq 3) { $fileNameForMisMatch = queryFileNameOut }
    

$CompareOptions = "1) StartType", "2) Status", "3) RequiredServices", "4) CanShutdown", "5) CanStop", "6) CanPauseAndContinue",
                  "7) DependentServices", "8) ServicesDependedOn", "9) ServiceHandle", "10) ServiceType", "11) Site", "12) Container"
if (!$args["Property"]) { 
    do { 
        $Property = read-host -prompt "`nService Property to Compare? [Default=StartType] (To Display Options, Enter 'C')"
        if ($Property.ToUpper() -eq "Q") { exit }
        if ($Property.ToUpper() -eq "C") {
            #write-output "`n"
            $CompareOptions | %{ write-output $_ }
        }
        if (!$Property) { $Property = "StartType" }
    }
    while ($Property -notin 1..12 -and $Property -notin $($CompareOptions | %{$_.Split(' ')[1]}))
    if ($Property -in 1..12) { $Property = $CompareOptions[$Property].Split(' ')[1] }
}

write-output "`nRunning...Please wait..."

$results = get-service -ComputerName $Node1, $Node2 |  select-object MachineName, Name, $Property | group-object Name | sort-object Name -OutVariable Export 
$misMatches = New-Object System.Collections.Generic.List[System.Object] 
$results | ForEach-Object {
    if ($_.Group[0].$($Property) -ne $_.Group[1].$($Property)) { 
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
    $mismatches | select-object @{n = 'Service' ; e = {$_.Service}},
                                @{n = "$($Node1_Property)" ; e = {$(if ($_.$($Node1_Property)) { $_.$($Node1_Property) } else { "[Service Not Found]"})}},
                                @{n = "$($Node2_Property)" ; e = {$(if ($_.$($Node2_Property)) { $_.$($Node2_Property) } else { "[Service Not Found]"})}} -OutVariable Export
}
else {
     $mismatches | select-object @{n = 'Service' ; e = {$_.Service}},
                                @{n = "$($Node1_Property)" ; e = {$(if ($_.$($Node1_Property)) { $_.$($Node1_Property) } else { "[Service Not Found]"})}},
                                @{n = "$($Node2_Property)" ; e = {$(if ($_.$($Node2_Property)) { $_.$($Node2_Property) } else { "[Service Not Found]"})}} -OutVariable Export >$null
}

if ($ShowAllServices -and $OutputMode -in 2..3) {
    write-output "`n`t`t* * * All Services * * *" 
    $results | format-table @{n = "Name";e = {$_.Name}; Alignment="left"},
                            @{ n = "Result Set" ; e = { $( if($_.Group[0].MachineName -and $_.Group[1].MachineName -and $_.Group[0].MachineName -eq $Node1) 
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))},
                                                               @{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }  
                                                            elseif($_.Group[0].MachineName -and $_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))},
                                                               @{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            elseif($_.Group[0].MachineName -and !$_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            else
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }
                                                         )
                                                       }; Alignment="left" },
                            @{n = "Count";e = {$_.Count}; Alignment="left"} -OutVariable Export
}
elseif ($ShowAllServices) {
    $results | format-table @{n = "Name";e = {$_.Name}; Alignment="left"},
                            @{ n = "Result Set" ; e = { $( if($_.Group[0].MachineName -and $_.Group[1].MachineName -and $_.Group[0].MachineName -eq $Node1) 
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))},
                                                               @{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }  
                                                            elseif($_.Group[0].MachineName -and $_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))},
                                                               @{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            elseif($_.Group[0].MachineName -and !$_.Group[1].MachineName)
                                                            { "@{MachineName=$($_.Group[0].MachineName); $($Property)=$($_.Group[0].$($Property))}" }
                                                            else
                                                            { "@{MachineName=$($_.Group[1].MachineName); $($Property)=$($_.Group[1].$($Property))}" }
                                                         )
                                                       }; Alignment="left" },
                            @{n = "Count";e = {$_.Count}; Alignment="left"} -OutVariable Export >$null
}

if ($OutputMode -eq 1 -or $OutputMode -eq 3) {
    $Export | export-CSV -Path $fileNameForMismatch -NoTypeInformation
    if ($ShowAllServices) { export-CSV -Path $fileNameForAllServices -NoTypeInformation }
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
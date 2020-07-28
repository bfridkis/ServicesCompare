$results = get-service -ComputerName AREESV1B, CK1ESV1B |  select-object MachineName, Name, Status | group-object Name | sort-object Name -OutVariable Export 
$misMatches = New-Object System.Collections.Generic.List[System.Object] 
$results | ForEach-Object {
    #write-output "0 Name: $($_.Group[0].Name) ... 0 Status: $($_.Group[0].Status) 1 Name: $($_.Group[1].Name) ... 1 Status: $($_.Group[1].Status)"
    if ($_.Group[0].Status -ne $_.Group[1].Status) { 
        if ($_.Group[0].MachineName -eq "CK1ESV1B") {
            $mismatches.Add(@{'Service' = $_.Name ; "$($_.Group[0].MachineName)_Status" = "$($_.Group[0].Status)" ; "$($_.Group[1].MachineName)_Status" = "$($_.Group[1].Status)" })
        }
        else {
            $mismatches.Add(@{'Service' = $_.Name ; "$($_.Group[1].MachineName)_Status" = "$($_.Group[1].Status)" ; "$($_.Group[0].MachineName)_Status" = "$($_.Group[0].Status)" })
        }
    }
} 
$mismatches | select-object @{n = 'Service' ; e = {$_.Service}},
                            @{n = "CK1ESV1B_Status" ; e = {$_.CK1ESV1B_Status}},
                            @{n = "AREESV1B_Status" ; e = {$_.AREESV1B_Status}}
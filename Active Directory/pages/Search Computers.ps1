New-UDPage -Url "/Search-Computers" -Name "Find Computer" -Icon (New-UDIcon -Icon 'Search') -Content {
    New-UDTypography -Text "Find Computer by Employee" -Variant h4 -Style @{marginBottom = '20px'}
    
    New-UDAlert -Severity 'info' -Text "Find a computer by searching for the employee who uses it. This is helpful when users report computer problems."
    
    New-UDElement -Tag 'br'
    
    # Simple search form
    New-UDCard -Title "Find Computer by Employee" -Content {
        New-UDForm -Content {
            New-UDTextbox -Label 'Employee Name' -Id 'employeeName' -Placeholder 'Enter employee name (e.g., Ahmed Bensaid, Leila Haddad)'
        } -OnSubmit {
            if (![string]::IsNullOrWhiteSpace($EventData.employeeName)) {
                try {
                    # First, find the user account
                    $foundUser = Get-ADUser -Filter "Name -like '*$($EventData.employeeName)*' -or DisplayName -like '*$($EventData.employeeName)*' -or GivenName -like '*$($EventData.employeeName)*' -or Surname -like '*$($EventData.employeeName)*'" -Properties DisplayName, Department, Title, LastLogonDate -ErrorAction Stop
                    
                    if ($foundUser.Count -eq 0) {
                        Show-UDToast -Message "No employee found with name '$($EventData.employeeName)'" -MessageColor 'error'
                        $Session:FoundComputer = $null
                        $Session:FoundUser = $null
                        Sync-UDElement -Id 'computerDetails'
                        return
                    } elseif ($foundUser.Count -gt 1) {
                        Show-UDToast -Message "Found $($foundUser.Count) employees. Showing results for all matches." -MessageColor 'warning'
                        $Session:MultipleUsers = $foundUser
                        $Session:FoundComputer = $null
                        Sync-UDElement -Id 'computerDetails'
                        return
                    }
                    
                    $Session:FoundUser = $foundUser
                    $username = $foundUser.SamAccountName
                    
                    # Try to find computer by common naming patterns
                    $computerNames = @(
                        $username.ToUpper(),
                        "PC-$($username.ToUpper())",
                        "$($username.ToUpper())-PC",
                        "WS-$($username.ToUpper())",
                        "$($foundUser.GivenName.ToUpper())-PC"
                    )
                    
                    $Session:FoundComputer = $null
                    foreach ($computerName in $computerNames) {
                        try {
                            $computer = Get-ADComputer -Filter "Name -eq '$computerName'" -Properties `
                                Description, OperatingSystem, OperatingSystemVersion, LastLogonDate, `
                                Enabled, Created, Modified, Location, ManagedBy, `
                                IPv4Address, DNSHostName, DistinguishedName -ErrorAction SilentlyContinue
                            
                            if ($computer) {
                                $Session:FoundComputer = $computer
                                break
                            }
                        } catch { }
                    }
                    
                    # If no direct match, search by description or managed by
                    if (-not $Session:FoundComputer) {
                        $Session:FoundComputer = Get-ADComputer -Filter "Description -like '*$($EventData.employeeName)*' -or ManagedBy -eq '$($foundUser.DistinguishedName)'" -Properties `
                            Description, OperatingSystem, OperatingSystemVersion, LastLogonDate, `
                            Enabled, Created, Modified, Location, ManagedBy, `
                            IPv4Address, DNSHostName, DistinguishedName -ErrorAction SilentlyContinue
                    }
                    
                    if ($Session:FoundComputer) {
                        # Try to get additional system information if computer is online
                        try {
                            $Session:SystemInfo = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Session:FoundComputer.Name -ErrorAction SilentlyContinue
                            $Session:OSInfo = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Session:FoundComputer.Name -ErrorAction SilentlyContinue
                            $Session:DiskInfo = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $Session:FoundComputer.Name -Filter "DriveType=3" -ErrorAction SilentlyContinue
                            $Session:IsOnline = $true
                        } catch {
                            $Session:IsOnline = $false
                        }
                        
                        Show-UDToast -Message "Found computer for $($foundUser.Name): $($Session:FoundComputer.Name)" -MessageColor 'success'
                    } else {
                        Show-UDToast -Message "Found employee $($foundUser.Name) but could not locate their computer" -MessageColor 'warning'
                    }
                } catch {
                    Show-UDToast -Message "Search error: $($_.Exception.Message)" -MessageColor 'error'
                    $Session:FoundComputer = $null
                    $Session:FoundUser = $null
                }
                
                Sync-UDElement -Id 'computerDetails'
            }
        }
    }
    
    New-UDElement -Tag 'br'
    
    # Computer details
    New-UDDynamic -Id 'computerDetails' -Content {
        # Handle multiple users found
        if ($Session:MultipleUsers) {
            New-UDCard -Title "Multiple Employees Found" -Content {
                New-UDTypography -Text "Found multiple employees with that name. Click on the correct one:" -Style @{marginBottom = '10px'}
                
                foreach ($user in $Session:MultipleUsers) {
                    New-UDButton -Text "$($user.Name) - $($user.Title) ($($user.Department))" -FullWidth -Style @{marginBottom = '5px'} -OnClick {
                        # Search for this specific user's computer
                        $Session:FoundUser = $user
                        $username = $user.SamAccountName
                        
                        # Try common naming patterns
                        $computerNames = @($username.ToUpper(), "PC-$($username.ToUpper())", "$($username.ToUpper())-PC")
                        $Session:FoundComputer = $null
                        
                        foreach ($computerName in $computerNames) {
                            try {
                                $computer = Get-ADComputer -Filter "Name -eq '$computerName'" -Properties Description, OperatingSystem, LastLogonDate, Enabled, Location, IPv4Address, DNSHostName, DistinguishedName -ErrorAction SilentlyContinue
                                if ($computer) {
                                    $Session:FoundComputer = $computer
                                    break
                                }
                            } catch { }
                        }
                        
                        $Session:MultipleUsers = $null
                        Show-UDToast -Message "Selected $($user.Name)" -MessageColor 'success'
                        Sync-UDElement -Id 'computerDetails'
                    }
                }
            }
            return
        }
        
        if ($Session:FoundComputer -eq $null -and $Session:FoundUser -eq $null) {
            return
        }
        
        # Show user info first
        if ($Session:FoundUser) {
            New-UDCard -Title "Employee Information" -Content {
                New-UDGrid -Container -Content {
                    New-UDGrid -Item -ExtraSmallSize 6 -Content {
                        New-UDTypography -Text "Name: $($Session:FoundUser.Name)" -Style @{fontWeight = 'bold'}
                        if ($Session:FoundUser.Title) {
                            New-UDTypography -Text "Position: $($Session:FoundUser.Title)"
                        }
                        if ($Session:FoundUser.Department) {
                            New-UDTypography -Text "Department: $($Session:FoundUser.Department)"
                        }
                        New-UDTypography -Text "Username: $($Session:FoundUser.SamAccountName)"
                    }
                    New-UDGrid -Item -ExtraSmallSize 6 -Content {
                        if ($Session:FoundUser.LastLogonDate) {
                            $daysAgo = [math]::Round(((Get-Date) - $Session:FoundUser.LastLogonDate).TotalDays)
                            New-UDTypography -Text "Last Login: $($Session:FoundUser.LastLogonDate.ToString('dd/MM/yyyy HH:mm')) ($daysAgo days ago)"
                        }
                    }
                }
            }
            New-UDElement -Tag 'br'
        }
        
        if ($Session:FoundComputer -eq $null) {
            New-UDAlert -Severity 'warning' -Text "Employee found but their computer could not be located. The computer might use a different naming convention or may not exist in Active Directory."
            return
        }
        
        $computer = $Session:FoundComputer
        
        # Main status card
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                $statusColor = if ($computer.Enabled -and $Session:IsOnline) { 'success' } elseif ($computer.Enabled) { 'warning' } else { 'error' }
                $statusText = if ($computer.Enabled -and $Session:IsOnline) { 'Online & Active' } elseif ($computer.Enabled) { 'Enabled but Offline' } else { 'Disabled' }
                
                New-UDCard -Title "$($computer.Name) - Computer Details" -Content {
                    New-UDGrid -Container -Content {
                        New-UDGrid -Item -ExtraSmallSize 6 -Content {
                            New-UDTypography -Text "Status:" -Variant h6
                            New-UDChip -Label $statusText -Color $statusColor -Size 'medium'
                            
                            New-UDElement -Tag 'br'
                            New-UDElement -Tag 'br'
                            
                            if ($computer.LastLogonDate) {
                                $daysAgo = [math]::Round(((Get-Date) - $computer.LastLogonDate).TotalDays)
                                New-UDTypography -Text "Last Seen: $($computer.LastLogonDate.ToString('dd/MM/yyyy HH:mm')) ($daysAgo days ago)"
                            } else {
                                New-UDTypography -Text "Last Seen: Never logged on" -Color 'error'
                            }
                            
                            if ($computer.Description) {
                                New-UDTypography -Text "Description: $($computer.Description)"
                            }
                            
                            if ($computer.Location) {
                                New-UDTypography -Text "Location: $($computer.Location)"
                            }
                        }
                        
                        New-UDGrid -Item -ExtraSmallSize 6 -Content {
                            New-UDTypography -Text "Network Information:" -Variant h6
                            
                            if ($computer.IPv4Address) {
                                New-UDTypography -Text "IP Address: $($computer.IPv4Address)"
                            }
                            
                            if ($computer.DNSHostName) {
                                New-UDTypography -Text "Full Name: $($computer.DNSHostName)"
                            }
                            
                            # Extract department from OU
                            $ouPath = $computer.DistinguishedName -replace "CN=$($computer.Name),", ""
                            if ($ouPath -match "OU=([^,]+)") {
                                New-UDTypography -Text "Department: $($matches[1])"
                            }
                        }
                    }
                }
            }
        }
        
        New-UDElement -Tag 'br'
        
        # Technical details
        New-UDGrid -Container -Content {
            # Operating System Info
            New-UDGrid -Item -ExtraSmallSize 6 -Content {
                New-UDCard -Title "System Information" -Content {
                    if ($computer.OperatingSystem) {
                        New-UDTypography -Text "OS: $($computer.OperatingSystem)"
                    }
                    
                    if ($computer.OperatingSystemVersion) {
                        New-UDTypography -Text "Version: $($computer.OperatingSystemVersion)"
                    }
                    
                    New-UDTypography -Text "Created: $($computer.Created.ToString('dd/MM/yyyy'))"
                    New-UDTypography -Text "Modified: $($computer.Modified.ToString('dd/MM/yyyy'))"
                    
                    # Live system info if available
                    if ($Session:IsOnline -and $Session:SystemInfo) {
                        New-UDElement -Tag 'br'
                        New-UDTypography -Text "Live System Info:" -Variant h6 -Color 'success'
                        New-UDTypography -Text "Manufacturer: $($Session:SystemInfo.Manufacturer)"
                        New-UDTypography -Text "Model: $($Session:SystemInfo.Model)"
                        New-UDTypography -Text "RAM: $([math]::Round($Session:SystemInfo.TotalPhysicalMemory / 1GB, 2)) GB"
                        
                        if ($Session:OSInfo) {
                            New-UDTypography -Text "Uptime: $([math]::Round(((Get-Date) - $Session:OSInfo.ConvertToDateTime($Session:OSInfo.LastBootUpTime)).TotalDays, 1)) days"
                        }
                    } elseif ($computer.Enabled) {
                        New-UDAlert -Severity 'warning' -Text "Computer is offline - cannot retrieve live information"
                    }
                }
            }
            
            # Disk Information
            New-UDGrid -Item -ExtraSmallSize 6 -Content {
                New-UDCard -Title "Storage & Actions" -Content {
                    if ($Session:IsOnline -and $Session:DiskInfo) {
                        New-UDTypography -Text "Disk Information:" -Variant h6 -Color 'success'
                        foreach ($disk in $Session:DiskInfo) {
                            $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
                            $color = if ($freePercent -lt 10) { 'error' } elseif ($freePercent -lt 20) { 'warning' } else { 'success' }
                            New-UDTypography -Text "Drive $($disk.DeviceID) - $([math]::Round($disk.Size / 1GB, 1)) GB total, $freePercent% free" -Color $color
                        }
                        New-UDElement -Tag 'br'
                    }
                    
                    New-UDTypography -Text "Quick Actions:" -Variant h6
                    
                    New-UDButton -Text "Ping Computer" -Size 'small' -Color 'primary' -OnClick {
                        try {
                            $pingResult = Test-NetConnection -ComputerName $computer.Name -Count 1
                            if ($pingResult.PingSucceeded) {
                                Show-UDToast -Message "✅ $($computer.Name) is responding to ping" -MessageColor 'success'
                            } else {
                                Show-UDToast -Message "❌ $($computer.Name) is not responding to ping" -MessageColor 'error'
                            }
                        } catch {
                            Show-UDToast -Message "❌ Cannot ping $($computer.Name): $($_.Exception.Message)" -MessageColor 'error'
                        }
                    }
                    
                    New-UDElement -Tag 'br'
                    
                    if ($computer.Enabled) {
                        New-UDButton -Text "Disable Computer" -Size 'small' -Color 'error' -OnClick {
                            Show-UDModal -Content {
                                New-UDTypography -Text "Are you sure you want to disable $($computer.Name)?"
                                New-UDElement -Tag 'br'
                                New-UDButton -Text "Yes, Disable" -Color 'error' -OnClick {
                                    try {
                                        Disable-ADAccount -Identity $computer.ObjectGUID
                                        Show-UDToast -Message "Computer $($computer.Name) has been disabled" -MessageColor 'success'
                                        Hide-UDModal
                                        # Refresh the search
                                        $Session:FoundComputer = Get-ADComputer -Filter "Name -eq '$($computer.Name)'" -Properties Description, OperatingSystem, LastLogonDate, Enabled, Created, Modified, Location, IPv4Address, DNSHostName, DistinguishedName
                                        Sync-UDElement -Id 'computerDetails'
                                    } catch {
                                        Show-UDToast -Message "Failed to disable computer: $($_.Exception.Message)" -MessageColor 'error'
                                    }
                                }
                                New-UDButton -Text "Cancel" -OnClick { Hide-UDModal }
                            } -Header { "Confirm Action" }
                        }
                    } else {
                        New-UDButton -Text "Enable Computer" -Size 'small' -Color 'success' -OnClick {
                            try {
                                Enable-ADAccount -Identity $computer.ObjectGUID
                                Show-UDToast -Message "Computer $($computer.Name) has been enabled" -MessageColor 'success'
                                # Refresh the search
                                $Session:FoundComputer = Get-ADComputer -Filter "Name -eq '$($computer.Name)'" -Properties Description, OperatingSystem, LastLogonDate, Enabled, Created, Modified, Location, IPv4Address, DNSHostName, DistinguishedName
                                Sync-UDElement -Id 'computerDetails'
                            } catch {
                                Show-UDToast -Message "Failed to enable computer: $($_.Exception.Message)" -MessageColor 'error'
                            }
                        }
                    }
                }
            }
        }
    }
}
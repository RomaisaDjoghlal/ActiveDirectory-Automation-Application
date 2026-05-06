New-UDPage -Url "/group-membership" -Name "Group Membership" -Icon (New-UDIcon -Icon 'Users' -Style @{ marginRight = "10px" }) -Content {
    New-UDTypography -Text 'CNAS Group Membership Management' -Variant h4
    New-UDElement -Tag 'br'
    
    # Group Selection - Only CNAS groups
    New-UDSelect -Id 'groupSelect' -Label 'Select CNAS Group' -Option {
        try {
            # Get only CNAS groups that start with GRP-Users-
            Get-ADGroup -Filter "Name -like 'GRP-Users-*'" | ForEach-Object {
                New-UDSelectOption -Name $_.Name -Value $_.Name
            }
        } catch {
            New-UDSelectOption -Name "No CNAS groups found" -Value ""
        }
    } -OnChange {
        $Session:SelectedGroup = $EventData
        Sync-UDElement -Id 'members'
    }
    
    New-UDElement -Tag 'div' -Attributes @{
        style = @{
            margin = '20px 0'
        }
    }
    
    # Dynamic Members Section
    New-UDDynamic -Id 'members' -Content {
        if ($Session:SelectedGroup) {
            try {
                $Data = Get-ADGroupMember -Identity $Session:SelectedGroup
                $groupInfo = Get-ADGroup -Identity $Session:SelectedGroup -Properties Description
                
                # Group Information Card
                New-UDCard -Title "Group: $($Session:SelectedGroup)" -Content {
                    New-UDGrid -Container -Content {
                        New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -Content {
                            New-UDTypography -Text "Members: $($Data.Count)" -Variant h6
                        }
                        New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -Content {
                            $groupType = if ($Session:SelectedGroup -like "*Centre*") { "Centre Group" } else { "Department Group" }
                            New-UDChip -Label $groupType -Color primary
                        }
                    }
                    if ($groupInfo.Description) {
                        New-UDTypography -Text "Description: $($groupInfo.Description)" -Variant body2 -Style @{marginTop = '10px'; color = '#666'}
                    }
                } -Style @{marginBottom = '20px'}
                
                # Current Members Table
                if ($Data.Count -gt 0) {
                    New-UDTable -Title "Current Members" -Data $Data -ShowPagination -PageSize 10 -Columns @(
                        New-UDTableColumn -Property Name -Title 'User Name' -Sort
                        New-UDTableColumn -Property SamAccountName -Title 'Login Name' -Sort
                        New-UDTableColumn -Property objectClass -Title 'Type' -Render {
                            $color = if ($EventData.objectClass -eq 'user') { '#4caf50' } else { '#ff9800' }
                            New-UDChip -Label $EventData.objectClass -Style @{backgroundColor = $color; color = 'white'}
                        }
                        New-UDTableColumn -Property Remove -Title 'Remove' -Render {
                            $DN = $EventData.DistinguishedName
                            $userName = $EventData.Name
                            $samAccount = $EventData.SamAccountName
                            New-UDButton -Text 'Remove' -Size small -Color secondary -OnClick {
                                try {
                                    # Use SamAccountName instead of DistinguishedName for more reliable removal
                                    Remove-ADGroupMember -Identity $Session:SelectedGroup -Members $samAccount -Confirm:$false -ErrorAction Stop
                                    Show-UDToast -Message "Removed $userName from $($Session:SelectedGroup)" -MessageColor success -Duration 3000
                                    Sync-UDElement -Id 'members'
                                } catch {
                                    Show-UDToast -Message "Error removing user: $($_.Exception.Message)" -MessageColor error -Duration 4000
                                }
                            }
                        }
                    ) -Sort
                } else {
                    New-UDAlert -Severity info -Text "This group has no members yet."
                }
                
                New-UDElement -Tag 'br'
                
                # Add Members Section
                New-UDCard -Title "Add Members to $($Session:SelectedGroup)" -Content {
                    New-UDTypography -Text "Select CNAS users to add to this group:" -Variant body2
                    New-UDElement -Tag 'br'
                    
                    New-UDSelect -Id 'userSelect' -Label 'Select User to Add' -Option {
                        try {
                            Get-ADUser -Filter * -SearchBase "OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz" | ForEach-Object {
                                New-UDSelectOption -Name "$($_.Name) ($($_.SamAccountName))" -Value $_.DistinguishedName
                            }
                        } catch {
                            New-UDSelectOption -Name "No users found" -Value ""
                        }
                    } -OnChange {
                        $Session:SelectedUser = $EventData
                    }
                    
                    New-UDElement -Tag 'br'
                    
                    New-UDButton -Text 'Add Member' -Variant contained -Color primary -OnClick {
                        if ($Session:SelectedUser) {
                            try {
                                # Check if user is already a member
                                $existingMembers = Get-ADGroupMember -Identity $Session:SelectedGroup
                                $userAlreadyMember = $existingMembers | Where-Object { $_.DistinguishedName -eq $Session:SelectedUser }
                                
                                if ($userAlreadyMember) {
                                    $userName = (Get-ADUser -Identity $Session:SelectedUser).Name
                                    Show-UDToast -Message "$userName is already a member of $($Session:SelectedGroup)" -MessageColor warning -Duration 3000
                                } else {
                                    Add-ADGroupMember -Identity $Session:SelectedGroup -Members (Get-ADUser -Identity $Session:SelectedUser)
                                    $userName = (Get-ADUser -Identity $Session:SelectedUser).Name
                                    Show-UDToast -Message "Added $userName to $($Session:SelectedGroup)" -MessageColor success -Duration 3000
                                    Sync-UDElement -Id 'members'
                                }
                            } catch {
                                Show-UDToast -Message "Error adding user: $($_.Exception.Message)" -MessageColor error -Duration 4000
                            }
                        } else {
                            Show-UDToast -Message "Please select a user first" -MessageColor warning -Duration 2000
                        }
                    }
                }
                
            } catch {
                New-UDAlert -Severity error -Text "Error loading group information: $($_.Exception.Message)"
            }
        } else {
            New-UDCard -Content {
                New-UDTypography -Text "Please select a CNAS group above to manage its membership" -Style @{
                    textAlign = 'center'
                    marginTop = '40px'
                    marginBottom = '40px'
                    color = '#666'
                }
            }
        }
    }
}
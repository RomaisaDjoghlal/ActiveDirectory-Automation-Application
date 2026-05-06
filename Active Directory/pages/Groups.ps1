New-UDPage -Url "/Groups" -Name "Groups" -Content {
    New-UDTypography -Text "Search for groups in Active Directory" -Variant h4
    New-UDElement -Tag 'br'
    
    New-UDForm -Content {
        New-UDTextbox -Label 'Group Name' -Id 'groupName' -Placeholder 'Enter group name or leave empty for all groups'
    } -OnSubmit {
        try {
            if ($EventData.groupName -and $EventData.groupName.Trim() -ne "") {
                # Search CNAS groups by name
                $filter = "Name -like 'GRP-*' -and Name -like '*$($EventData.groupName.Trim())*'"
            } else {
                # Show all CNAS groups
                $filter = "Name -like 'GRP-*'"
            }
            
            # Get all properties like the original code
            $Session:Objects = Get-ADGroup -Filter $filter -SearchBase "OU=CNAS-Groups,DC=ag26,DC=cnas,DC=dz" -Properties * | 
                Sort-Object Name
                
        } catch {
            $Session:Objects = @()
            $Session:SearchError = $_.Exception.Message
        }
        
        Sync-UDElement -Id 'adObjects'
    }
    
    New-UDButton -Text 'Show All CNAS Groups' -OnClick {
        try {
            # Get all properties like the original code
            $Session:Objects = Get-ADGroup -Filter "Name -like 'GRP-*'" -SearchBase "OU=CNAS-Groups,DC=ag26,DC=cnas,DC=dz" -Properties * | 
                Sort-Object Name
            $Session:SearchError = $null
        } catch {
            $Session:Objects = @()
            $Session:SearchError = $_.Exception.Message
        }
        Sync-UDElement -Id 'adObjects'
    } -Variant outlined
    
    New-UDElement -Tag 'br'
    
    New-UDDynamic -Id 'adObjects' -Content {
        if ($Session:SearchError) {
            New-UDAlert -Severity error -Text "Error: $($Session:SearchError)"
            return
        }
        
        if ($Session:Objects -eq $null) {
            New-UDTypography -Text "Enter a group name or click 'Show All CNAS Groups' to search" -Style @{
                textAlign = 'center'
                marginTop = '20px'
                color = '#666'
            }
            return
        }
        
        if ($Session:Objects.Count -eq 0) {
            New-UDAlert -Severity info -Text "No groups found"
            return
        }
        
        New-UDTypography -Text "Found $($Session:Objects.Count) group(s)" -Variant h6
        New-UDElement -Tag 'br'
        
        # Table showing only useful properties of YOUR CNAS groups
        New-UDTable -Title 'CNAS Groups' -Data $Session:Objects -Columns @(
            New-UDTableColumn -Property Name -Title "Group Name" -Filter -Sort
            New-UDTableColumn -Property GroupCategory -Title "Type" -Filter -Sort -Render {
                if ($EventData.GroupCategory -eq 'Security') {
                    New-UDChip -Label "Security" -Color primary
                } else {
                    New-UDChip -Label "Distribution" -Color secondary
                }
            }
            New-UDTableColumn -Property GroupScope -Title "Scope" -Filter -Sort -Render {
                New-UDChip -Label $EventData.GroupScope -Color default
            }
            New-UDTableColumn -Property Description -Title "Description" -Filter
            New-UDTableColumn -Property Members -Title "Members" -Render {
                $count = if ($EventData.Members) { $EventData.Members.Count } else { 0 }
                New-UDChip -Label "$count members" -Color success
            }
            New-UDTableColumn -Property WhenCreated -Title "Created" -Sort -Render {
                if ($EventData.WhenCreated) {
                    [DateTime]$EventData.WhenCreated | Get-Date -Format "dd/MM/yyyy"
                } else {
                    "N/A"
                }
            }
        ) -Filter -Sort -PageSize 10 -ShowPagination
    }
    
} -Icon (New-UDIcon -Icon 'Users')
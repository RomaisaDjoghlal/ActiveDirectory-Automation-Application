$Navigation = {
  Protect-UDSection -Role @("Administrator", "AD Admin", "AD Users") -Children {
    New-UDListItem -Label 'Users' -Icon (New-UDIcon -Icon 'User') -Children {
      New-UDListItem -Label 'Search Users' -Icon (New-UDIcon -Icon 'Search') -Href '/search-users' -Nested
      New-UDListItem -Label 'Create User' -Icon (New-UDIcon -Icon 'UserPlus') -Href '/create-user' -Nested
      New-UDListItem -Label 'Reset Password' -Icon (New-UDIcon -Icon 'Key') -Href '/reset-password' -Nested
      New-UDListItem -Label 'Restore Deleted User' -Icon (New-UDIcon -Icon 'Trash') -Href '/restore-deleted-user' -Nested
    }
  }
  Protect-UDSection -Role @("Administrator", "AD Admin", "AD Groups") -Children {
    New-UDListItem -Label 'Groups' -Icon (New-UDIcon -Icon 'Users') -Children {
      New-UDListItem -Label 'Search Groups' -Icon (New-UDIcon -Icon 'Search') -Href '/groups' -Nested
      New-UDListItem -Label 'Create Group' -Icon (New-UDIcon -Icon 'UsersCog') -Href '/create-group' -Nested
      New-UDListItem -Label 'Group Membership' -Icon (New-UDIcon -Icon 'Users') -Href '/group-membership' -Nested
    }
  }
  Protect-UDSection -Role @("Administrator", "AD Admin") -Children {
    New-UDListItem -Label 'Infrastructure' -Icon (New-UDIcon -Icon 'Server') -Children {
      New-UDListItem -Label 'Search Computers' -Icon (New-UDIcon -Icon 'Search') -Href '/Search-Computers' -Nested
      New-UDListItem -Label 'Domain Controllers' -Icon (New-UDIcon -Icon 'Database') -Href '/Domain-Controllers' -Nested
    }
  }
  New-UDListItem -Label 'Object Search' -Icon (New-UDIcon -Icon 'Search') -Href '/object-search'
  New-UDListItem -Label 'Reports' -Icon (New-UDIcon -Icon 'UsersGear') -Href '/reports'
}

function New-ADReportPage {
    param(
        $Title,  
        $Description,
        $Script,
        $Url)

      New-UDPage -Name $Title -Url $Url -Content {
        New-UDStack -Direction row -Content {
          New-UDButton -Text 'Back to Reports' -Icon (New-UDIcon -Icon ArrowAltCircleLeft) -OnClick {
            Invoke-UDRedirect "/reports"
          }

          New-UDButton -Text 'Run Report' -OnClick {
            Show-UDToast "Running report..."
            Invoke-PSUScript -Integrated -Name $Script | Wait-PSUJob -Integrated
            Sync-UDElement -Id "$($Title)_Table" 
            Show-UDToast "Report complete."
          } -Icon (New-UDIcon -Icon 'Play') -ShowLoading 
        }

        New-UDAlert -Severity info -Title $Title -Text $Description

        New-UDDynamic -Id "$($Title)_Table" -Content {
          $Job = Get-PSUScript -Integrated -Name $Script | Get-PSUJob -Integrated -OrderDirection Descending -OrderBy StartTime -First 1
          if ($Job -eq $null) {
            Show-UDToast 'Running report...'
            $Data = Invoke-PSUScript -Integrated -Name $Script -Wait 
            $JobTime = Get-Date
          } else {
            $Data = $Job | Get-PSUJobPipelineOutput -Integrated
            $JobTime = $Job.EndTime
          }

          New-UDTable -Title $Title -Icon (New-UDIcon -Icon User -Style @{ marginRight = "10px"}) -Data $Data -ShowExport -ShowPagination
          New-UDStack -Direction column -Content {
            New-UDTypography -Text "Report Created: $JobTime"
          }
        } -LoadingComponent {
          New-UDSkeleton -Height 10
        }
      }
}

# FIXED: Updated script names to match your registered scripts (without "Reports\" prefix)
$Reports = @(
      @{
          Title = "Accounts - Soon to Expire"
          Url = "/reports/accounts/expiring"
          Description = "A report of accounts that are soon to expire."
          Script = "Accounts - Soon to Expire.ps1"  # REMOVED "Reports\" prefix
      }
      @{
          Title = "Computers - Disabled"
          Url = "/reports/computers/disabled"
          Description = "A report of computers that are disabled."
          Script = "Computers - Disabled.ps1"  # REMOVED "Reports\" prefix
      }
      @{
          Title = "Computers - Domain Controllers"
          Url = "/reports/computers/domain-controllers"
          Description = "A report of domain controllers."
          Script = "Computers - Domain Controllers.ps1"  # REMOVED "Reports\" prefix
      }
      @{
          Title = "Computers - Inactive"
          Url = "/reports/computers/inactive"
          Description = "A report of computers that have been inactive for 30 days or more."
          Script = "Computers - Inactive.ps1"  # REMOVED "Reports\" prefix
      }
      @{
          Title = "Users - Account Expired"
          Url = "/reports/users/account-expired"
          Description = "A report of users with expired accounts."
          Script = "Users - Account Expired.ps1"  # REMOVED "Reports\" prefix
      }
      @{
          Title = "Users - Cannot Change Password"
          Url = "/reports/users/cannot-change-password"
          Description = "A report of users that cannot change their password."
          Script = "Users - Cannot Change Password.ps1"  # REMOVED "Reports\" prefix
      }
      @{
          Title = "Users - Inactive"
          Url = "/reports/users/inactive"
          Description = "A report of users that have been inactive for 30 days or more."
          Script = "Users - Inactive Users.ps1"  # REMOVED "Reports\" prefix
      }
      @{
          Title = "Users - Locked Out"
          Url = "/reports/users/locked-out"
          Description = "A report of users that are locked out."
          Script = "Users - Locked Out.ps1"  # REMOVED "Reports\" prefix
      }
      @{
        Title = "Users - Never Logged On"
        Url = "/reports/users/never-logged-on"
        Description = "A report of users that have never logged on."
        Script = "Users - Never Logged On.ps1"  # REMOVED "Reports\" prefix
    }
    @{
        Title = "Users - Password Expired"
        Url = "/reports/users/password-expired"
        Description = "A report of users with expired passwords."
        Script = "Users - Password Expired.ps1"  # REMOVED "Reports\" prefix
    }
    @{
        Title = "Users - Password Never Expires"
        Url = "/reports/users/password-never-expires"
        Description = "A report of users where their password never expires."
        Script = "Users - Password Never Expires.ps1"  # REMOVED "Reports\" prefix
    }
    @{
        Title = "Users - Recently Created"
        Url = "/reports/users/recently-created"
        Description = "A report of users that have been created in the last 30 days."
        Script = "Users - Recently Created.ps1"  # REMOVED "Reports\" prefix
    }
    @{
        Title = "Users - Recently Modified"
        Url = "/reports/users/recently-modified"
        Description = "A report of users that have been modified in the last 30 days."
        Script = "Users - Recently Modified.ps1"  # REMOVED "Reports\" prefix
    }
    @{
        Title = "Users - Without Manager"
        Url = "/reports/users/without-manager"
        Description = "A report of users that do not have managers"
        Script = "Users - Without Manager.ps1"  # REMOVED "Reports\" prefix
    }
)

New-UDDashboard -Title "Active Directory Tools" -Pages @(
  Get-UDPage -Name "Create User"
  Get-UDPage -Name "Create Group"
  Get-UDPage -Name "Domain Controllers"
  Get-UDPage -Name "Groups"
  Get-UDPage -Name "Group Membership"
  Get-UDPage -Name "Object Info"
  Get-UDPage -Name "Object Search"
  Get-UDPage -Name "Search Computers"
  Get-UDPage -Name "Search Users"
  Get-UDPage -Name "Reset Password"
  Get-UDPage -Name "Restore Deleted User"
  
  # FIXED: Main Reports page with proper error handling and variable scoping
 New-UDPage -Name 'Reports' -Url '/reports' -DefaultHomePage -Content {
    New-UDTypography -Text 'Reports' -Variant h4
    New-UDHtml -Markup '<hr/>'
    
    # REMOVED: New-UDLayout -Columns 3 -Content {
    # REMOVED: New-UDCard
    
    $Reports | ForEach-Object {
        $CurrentReport = $_
        
        # Try to get job info, with error handling
        try {
            $Job = Get-PSUScript -Integrated -Name $_.Script | Get-PSUJob -Integrated -OrderDirection Descending -OrderBy StartTime -First 1
            $LastRun = "Never"
            $Objects = "Unknown"
            if ($Job) {
                $LastRun = $Job.EndTime
                $Objects = ($Job | Get-PSUJobPipelineOutput -Integrated | Measure-Object).Count
            }
        }
        catch {
            $LastRun = "Script not found"
            $Objects = "N/A"
            Write-Output "Error: Could not find script '$($_.Script)'"
        }
        
        # List item instead of card
        New-UDElement -Tag 'div' -Content {
            New-UDTypography -Text $CurrentReport.Title -Variant h6 -Style @{
                color = '#1976d2'
                fontWeight = 'bold'
                marginBottom = '5px'
            }
            New-UDTypography -Text $CurrentReport.Description -Style @{
                fontSize = '14px'
                marginBottom = '5px'
            }
            New-UDTypography -Text "Last Run: $LastRun | Objects: $Objects" -Style @{
                fontSize = '12px'
                color = '#666'
            }
        } -Attributes @{
            onClick = {
                Invoke-UDRedirect $CurrentReport.Url
            }
            style = @{
                cursor = 'pointer'
                padding = '15px'
                marginBottom = '10px'
                border = '1px solid #ddd'
                borderLeft = '4px solid #1976d2'
                backgroundColor = '#fafafa'
            }
        }
    }
}
      
     
  
  # Generate individual report pages
  $Reports | ForEach-Object {
    New-ADReportPage @_
  }
) -NavigationLayout Permanent -LoadNavigation $Navigation
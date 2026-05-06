# Replace your Reports page with this:
New-UDPage -Name 'Reports' -Url '/reports' -DefaultHomePage -Content {
    New-UDTypography -Text 'Reports' -Variant h4
    New-UDHtml -Markup '<hr/>'
    
    # NO LAYOUT - Just iterate through reports in a single column
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
        
        # Create simple clickable div - NO CARDS
        New-UDElement -Tag 'div' -Content {
            New-UDTypography -Text $CurrentReport.Title -Variant h6 -Style @{
                color = '#1976d2'
                fontWeight = 'bold'
                marginBottom = '4px'
            }
            New-UDTypography -Text $CurrentReport.Description -Style @{
                color = '#666'
                fontSize = '14px'
                marginBottom = '4px'
            }
            New-UDTypography -Text "Last Run: $LastRun | Objects: $Objects" -Style @{
                fontSize = '12px'
                color = '#888'
            }
        } -Attributes @{
            onClick = {
                Invoke-UDRedirect $CurrentReport.Url
            }
            style = @{
                cursor = 'pointer'
                padding = '12px'
                marginBottom = '4px'
                border = '1px solid #ddd'
                backgroundColor = '#f9f9f9'
            }
        }
    }
}
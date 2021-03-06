Function Get-AutoStartupSQLServices {
    [cmdletbinding()]
    Param(
        [Parameter(ParameterSetName = "Config", ValueFromPipeline = $true, Position = 0)]
        $Config

        , [Parameter(ParameterSetName = "Values")]
        $ServerInstance
    )

    if ($PSCmdlet.ParameterSetName -eq "Config") {
        $ServerInstance = $Config.ServerInstance
    }

    $query = @"
    select  count(*) as [Count]
    from    sys.dm_server_services
    where   (
                servicename like 'SQL Server (%)%'
        or    servicename like 'SQL Server Agent%'
            )
    and     startup_type_desc <> 'Automatic';
"@

    Invoke-Sqlcmd -ServerInstance $serverInstance -query $query -Database master
    
}
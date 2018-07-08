Param(
    $Config
)

$serverInstance = $config.ServerInstance

$databasesToCheckConfig = $config.DatabasesToCheck
$databasesToCheckParams = @{
    ServerInstance = $serverInstance
}

if($databasesToCheckConfig -eq "AGOnly") {
    $databasesToCheckParams.ExcludeLocal = $true

    if($config.AvailabilityGroup -ne $null) {
        $databasesToCheckParams.AvailabilityGroup = $config.AvailabilityGroup
    }
    
} elseif($databasesToCheckConfig -eq "LocalOnly") {
    $databasesToCheckParams.ExcludePrimary = $true
}

Describe "No large fixed growth transaction logs" -Tag MaxTLogAutoGrowthInKB {
    $MaxTLogAutoGrowthInKB = $Config.MaxTLogAutoGrowthInKB
    $databases = Get-DatabasesToCheck @databasesToCheckParams 
    foreach($database in $databases) {
        It "$database has no log files with autogrowth greater than $MaxTLogAutoGrowthInKB KB on $serverInstance " {
            @(Get-TLogsWithLargeGrowthSize -Config $Config -Database $database).Count | Should Be 0
        }
    }
}

Describe "Data file space used" -Tag MaxDataFileSize {
    $maxDataConfig = $config.MaxDataFileSize
    if($maxDataConfig  -eq $null) {
        continue
    }
    
    $spaceUsedPercentLimit = $maxDataConfig.SpaceUsedPercent
    $MaxDataFileParams=@{
        ServerInstance = $serverInstance
        MaxDataFileSpaceUsedPercent = $spaceUsedPercentLimit
        WhiteListFiles = $maxDataConfig.WhitelistFiles
    }

    
    $databases = Get-DatabasesToCheck @databasesToCheckParams 
    foreach($database in $databases) {
        It "$database files are all under $spaceUsedPercentLimit% full on $serverInstance" {
            $MaxDataFileParams.Database = $database
            @(Get-DatabaseFilesOverMaxDataFileSpaceUsed @MaxDataFileParams).Count | Should -Be 0
        }
    }
}

Describe "DDL Trigger Presence" -Tag MustHaveDDLTrigger {
    $MustHaveDDLTrigger = $config.MustHaveDDLTrigger
    if($MustHaveDDLTrigger  -eq $null) {
        continue
    }

    $triggerName = $MustHaveDDLTrigger.TriggerName
    $databasesToCheckParams.ExcludeSystemDatabases = $true
    $databasesToCheckParams.ExcludedDatabases = $MustHaveDDLTrigger.ExcludedDatabases

    $databases = Get-DatabasesToCheck @databasesToCheckParams

    foreach($database in $databases) {
        It "$database has required DDL triggers on $serverInstance" {  
            Get-DatabaseTriggerStatus -ServerInstance $serverInstance -TriggerName $triggerName -Database $database | Should Be $true
        }
    }
}

Describe "Oversized indexes" -Tag CheckForOversizedIndexes {
    $databasesToCheckParams.ExcludedDatabases = $config.CheckForOversizedIndexes.ExcludedDatabases

    $databases = Get-DatabasesToCheck @databasesToCheckParams
    foreach($database in $databases) {
        It "$database has no oversized indexes on $serverInstance" {
            @(Get-OversizedIndexes -ServerInstance $serverInstance -Database $database).Count | Should Be 0
        }
    }
}

Describe "Percentage growth log files" -Tag CheckForPercentageGrowthLogFiles {
    $databases = Get-DatabasesToCheck @databasesToCheckParams 
    foreach($database in $databases) {
        It "$database has no percentage growth log files on $serverInstance" {
            @(Get-TLogWithPercentageGrowth -ServerInstance $serverInstance -Database $database).Count | Should Be 0
        }
    }
}

Describe "Last good checkdb" -Tag LastGoodCheckDb {
    $checkDbConfig = $config.LastGoodCheckDb
    $maxDays = $checkDbConfig.MaxDaysSinceLastGoodCheckDB
    [string[]]$excludedDbs = $checkDbConfig.ExcludedDatabases
    $excludedDbs += "tempdb"
    $databasesToCheckParams.ExcludedDatabases = $excludedDbs

    $databases = Get-DatabasesToCheck @databasesToCheckParams 
    foreach($database in $databases) {
        It "$database had a successful CHECKDB in the last $maxDays days on $serverInstance"{
            (Get-DbsWithoutGoodCheckDb -ServerInstance $serverInstance -Database $database).DaysSinceLastGoodCheckDB | Should -BeLessOrEqual $maxDays
        }
    }
}

Describe "Duplicate indexes" -Tag CheckDuplicateIndexes {
    $CheckDuplicateIndexesConfig = $config.CheckDuplicateIndexes
    $ExcludeDatabase = $CheckDuplicateIndexesConfig.ExcludeDatabase
    $ExcludeIndex = $CheckDuplicateIndexesConfig.ExcludeIndex
    $ExcludeIndexStr  = "'$($ExcludeIndex -join "','")'"

    $databases = Get-DatabasesToCheck @databasesToCheckParams 
    
    foreach($database in $databases) {
        if($ExcludeDatabase -contains $database) {
            continue
        }

        It "$database has no duplicate indexes on $serverInstance" {
            @(Get-DuplicateIndexes -ServerInstance $serverInstance -Database $database -ExcludeIndex $ExcludeIndexStr).Count | Should Be 0
        }
    }
}

Describe "Zero autogrowth files" -Tag ZeroAutoGrowthFiles {
    $whitelist = $config.ZeroAutoGrowthFiles.Whitelist
    $databases = Get-DatabasesToCheck @databasesToCheckParams
    
    foreach($database in $databases) {
        It "$database has no zero autogrowth files on $serverInstance"{
            @(Get-FixedSizeFiles -ServerInstance $serverInstance -WhitelistFiles $whitelist -Database $database).Count | Should Be 0
        }
    }
}

Describe "Autogrowth space to grow" -Tag ShouldCheckForAutoGrowthRisks {
    $databases = Get-DatabasesToCheck @databasesToCheckParams 

    foreach($database in $databases) {
        It "$database size-governed filegroups have space for their next growth on $serverInstance" {
            @(Get-AutoGrowthRisks -ServerInstance $serverInstance -Database $database).Count | Should Be 0
        }
    }
}
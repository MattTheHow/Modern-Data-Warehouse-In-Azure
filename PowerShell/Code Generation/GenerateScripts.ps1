
########################################
# 
#    Author : Matt How
#    
#    Desc   : Generate SQL scripts using
#             metadata from SQL database
#
#    Usage  : Should be run with
#             PowerShell(64)
#    
########################################

cls

# Define variable values
$TemplateRepo = "C:\@Source\Modern Data Warehouse in Azure\Modern-Data-Warehouse-In-Azure\SQL\Control Database\Templates"
$AzureSQLDatabaseServer = "mdwa-sqlserver.database.windows.net"
$AzureSQLDatabaseName = "Demo Control DB"
$AzureSQLDatabaseAdminUserName = "MattHow"
$AzureSQLDatabaseAdminPassword = "P4ssword"
$Query = "EXEC Metadata.ObtainEntityMetadata"

# Create a connection string for the control database
$ControlDBConnection = "Server='$AzureSQLDatabaseServer';Database='$AzureSQLDatabaseName';User ID='$AzureSQLDatabaseAdminUserName';Password='$AzureSQLDatabaseAdminPassword';"

# Fetch the required template from the repo
$TemplateName = "template.CleanSourceData.sql"
$CleanDatasetTemplate = Get-Content -Path $($TemplateRepo + '\' + $TemplateName)

# Obtain the metadata dataset
$Metadata = Invoke-Sqlcmd -ConnectionString $ControlDBConnection -Query $Query -OutputAs DataSet

$EntityDataset = $Metadata.Tables[0].Rows
$ColumnDataset = $Metadata.Tables[1].Rows

ForEach($Item in $EntityDataset)
{
    
    $Entity = $Item.EntityName
    $SourceSystemName = $Item.SourceSystemName
    
    $ColumnListWithRules = ""
    $ColumnListWithCast = ""

    ForEach($ColumnObject in $ColumnDataset | Where {$ColumnObject.EntityName -eq $Entity})
    {
        
        $ColumnName = $ColumnObject.EntityColumnName
        $DataType = $ColumnObject.ColumnDataType

        $ColumnValueWithRules = "," + $ColumnObject.RuleDefinition -replace "%%COLUMN_NAME%%", $ColumnName
        $ColumnListWithRules += "`t`t`t" + $ColumnValueWithRules + "`n"

        $ColumnValueWithCast = $(",CAST([$ColumnName] AS $DataType)")
        $ColumnListWithCast += "`t`t`t" + $ColumnValueWithCast + "`n"      

    }

    $TemplateOutput = $CleanDatasetTemplate

    $TemplateOutput = $TemplateOutput -replace "%%ENTITY%%", $Entity
    $TemplateOutput = $TemplateOutput -replace "%%SOURCE_SYSTEM%%", $SourceSystemName
    $TemplateOutput = $TemplateOutput -replace "%%SOURCE_COLUMN_LIST_WITH_RULES%%", $ColumnListWithRules
    $TemplateOutput = $TemplateOutput -replace "%%SOURCE_COLUMN_LIST%%", $ColumnListWithCast

    $OutputPath = $TemplateRepo + "\Complete\Clean" + $Entity + ".sql"

    New-Item -Path $OutputPath -ItemType File -Force | Out-Null
    $TemplateOutput | Out-File $OutputPath

    Write-Host "Completed generation of Clean$($Entity).sql"

}





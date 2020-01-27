
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
$TemplateRepo = "<supply-path-to-template-repo>"
$AzureSQLDatabaseServer = "<database-server-for-metadata-db>"
$AzureSQLDatabaseName = "<sql-database-name>"
$AzureSQLDatabaseAdminUserName = "<sql-login>"
$AzureSQLDatabaseAdminPassword = Read-Host "Enter password for $($AzureSQLDatabaseAdminUserName)"
$Query = "EXEC Metadata.ObtainEntityMetadata"

# Create a connection string for the control database
$ControlDBConnection = "Server='$AzureSQLDatabaseServer';Database='$AzureSQLDatabaseName';User ID='$AzureSQLDatabaseAdminUserName';Password='$AzureSQLDatabaseAdminPassword';"

# Fetch the required templates from the repo
$TemplateArray = @(
    "template.Base.CleanData.sql",
    "template.Base.Table.sql",
    "template.Load.ImportData.sql",
    "template.Load.Table.sql",
    "template.Load.TableType.sql"
)

# Obtain the metadata dataset
$Metadata = Invoke-Sqlcmd -ConnectionString $ControlDBConnection -Query $Query -OutputAs DataSet

$EntityDataset = $Metadata.Tables[0].Rows
$ColumnDataset = $Metadata.Tables[1].Rows
$RuleDataset = $Metadata.Tables[2].Rows

# Iterate each entity
ForEach($Item in $EntityDataset)
{
    
    $Entity = $Item.EntityTableName
    $SourceSystemName = $Item.SourceSystemName
    $isSCD = If($Item.SCD2Columns -gt 0) {$true} Else {$False}
    $ScreenSQL = If($Item.screenSQL -eq $null) {""} Else {$Item.screenSQL}

    $ColumnListWithRules = ""
    $ColumnListWithCast = ""
    $ColumnListAsDetyped = ""
    $ColumnListWithDataTypes = ""
    $ColumnList = ""
    $ColumnListAsString = ""
    $ColumnListAsSCD2String = ""
    $ColumnListAsTry = ""
    $ColumnListWithTryCast = ""
    $ColumnListBase = ""
    $ColumnListAsCase = ",CASE "
    $EntityConstraintsArray = @()

    
    If( $isSCD )
    {
        $SCD2HashString = ",HASHBYTES('SHA2_256',CAST(CONCAT(%%COLUMN_LIST_AS_SCD2_STRING%%) AS VARBINARY(64)) )"
        $EntityHashColumnName = $Entity + "HashSCD2"
    }
    Else 
    { 
        $SCD2HashString = ""
        $EntityHashColumnName = "" 
    }

    # Create the required column lists
    ForEach($ColumnObject in $ColumnDataset | Where { $_.EntityTableName -eq $Entity})
    {

        # Define the column variables
        $ColumnName = $ColumnObject.ColumnName
        $ColumnId = $ColumnObject.EntityColumnId
        $ColumnSCD = If($ColumnObject.isSCDType2) {$True} Else {$False} 
        $DataType = $ColumnObject.DataType
        $RuleDefinition = ""
        $CurrentRuleDefinition = ""
        $ColumnDefinition = ""       

        # Create a column list with datatypes
        $ColumnValueWithCast = $(",CAST([$ColumnName] AS $DataType)")
        $ColumnListWithCast += "`t`t`t" + $ColumnValueWithCast + "`n"
        
        # Create a column list in a detyped DDL format
        $ColumnValueDetyped = ",[" + $ColumnName + "] NVARCHAR(1000)" 
        $ColumnListAsDetyped += $ColumnValueDetyped + "`n"

        # Create a column list with try_casts and rules
        $ColumnValue = ",[" + $ColumnName + "]"
        $ColumnList += $ColumnValue + "`n"
        $ColumnListAsString += $ColumnValue   

        # Create column lists for mapped columns
        If ($ColumnObject.isMapped)
        {
            # Create a column list in a typed DDL format
            $ColumnValueWithDataTypes = ",[" + $ColumnName + "] " + $DataType 
            $ColumnListWithDataTypes += $ColumnValueWithDataTypes + "`n"

            # Create a column list as case statement
            $ColumnValueAsCase = "WHEN [try_$ColumnName] IS NULL THEN '$ColumnName'"
            $ColumnListAsCase += $ColumnValueAsCase + "`n"

            $ColumnListAsTry += $($ColumnValue + "+") -replace ",\[", "[try_"

            $ColumnListBase += $ColumnValue + "`n"

            ForEach($Rule in $RuleDataset | Where {$_.EntityColumnId -eq $ColumnId})
            {
                # Prepare the rules for the column
                $RuleString = $Rule.RuleDefinition

                If($Rule.RuleOrder -eq 0)
                {
                    $ColumnDefinition = $RuleString -replace '%%COLUMN_NAME%%', $ColumnName
                }
                Else
                {
                    $ColumnDefinition = $RuleString -replace '\[%%COLUMN_NAME%%\]', $ColumnDefinition
                }
            }  
            
            If( $ColumnDefinition -eq "") {$ColumnDefinition = $ColumnName}

            $ColumnListWithRules += "`t`t`t," + $ColumnDefinition + " AS [$($ColumnName)]`n"

            # Create a column list with try_casts and rules
            $ColumnValueWithTryCast = ",CASE WHEN TRY_CAST(" + $ColumnDefinition + " AS $DataType) IS NULL THEN NULL ELSE 1 END AS [try_$($ColumnName)]"
            $ColumnListWithTryCast += $ColumnValueWithTryCast + "`n"      
            
            If( $ColumnSCD ) 
            { 
                $ColumnListAsSCD2String += "[" + $ColumnName + "]," + "'||'," 
            }
        }   

        # Create array of primary key columns
        If($ColumnObject.isPrimaryKey -eq $true) { $EntityConstraintsArray += $ColumnName }
    }

    $PrimaryKeyColumns = $EntityConstraintsArray -join ', '
    $ColumnListAsCase += " END AS [ErrorColumn] "

    If ($ColumnListWithDataTypes) {$ColumnListWithDataTypes = $ColumnListWithDataTypes.TrimStart(',')}

    If( $isSCD )
    {
        $SCD2HashString = $SCD2HashString -replace "%%COLUMN_LIST_AS_SCD2_STRING%%", $ColumnListAsSCD2String.TrimEnd("'||',")
    }

    ForEach($Template in $TemplateArray)
    {
        # Assign the template output
        $TemplateOutput = Get-Content -Path $($TemplateRepo + '\' + $Template)

        # Replace placeholders with values
        $TemplateOutput = $TemplateOutput -replace "%%ENTITY_TABLE_NAME%%", $Entity
        $TemplateOutput = $TemplateOutput -replace "%%SCREEN_SQL%%", $ScreenSQL
        $TemplateOutput = $TemplateOutput -replace "%%SOURCE_SYSTEM%%", $SourceSystemName
        $TemplateOutput = $TemplateOutput -replace "%%SOURCE_COLUMN_LIST_WITH_RULES%%", $ColumnListWithRules
        $TemplateOutput = $TemplateOutput -replace "%%SOURCE_COLUMN_LIST%%", $ColumnListWithCast
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST%%", $ColumnList
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_BASE%%", $ColumnListBase
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_AS_DETYPED%%", $ColumnListAsDetyped.TrimStart(',')
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_WITH_DATATYPES%%", $ColumnListWithDataTypes
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_WITH_TRY_CAST%%", $ColumnListWithTryCast
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_AS_STRING%%", $ColumnListAsString.TrimStart(',')
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_AS_SCD2_STRING%%", $SCD2HashString
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_AS_TRY%%", $ColumnListAsTry.TrimEnd('+')
        $TemplateOutput = $TemplateOutput -replace "%%COLUMN_LIST_AS_CASE%%", $ColumnListAsCase
        $TemplateOutput = $TemplateOutput -replace "%%SCD_2_HASH%%", $EntityHashColumnName

        $FileName = $Entity + "_" + $($Template -replace 'template.', '')

        $OutputPath = $TemplateRepo + "\Complete\$FileName"
        New-Item -Path $OutputPath -ItemType File -Force | Out-Null
        $TemplateOutput | Out-File $OutputPath

        Write-Host "Completed generation of $Template"
    }
}

CREATE PROC Load.Raw%%ENTITY_TABLE_NAME%%_to_Load%%ENTITY_TABLE_NAME%%
(
    @Data Load.%%ENTITY_TABLE_NAME%%Type READONLY,
    @LoadId INT = NULL,
    @FileName VARCHAR(100) = NULL,
    @UTCDateTime DATETIME
)
AS
BEGIN

    DECLARE @InsertCount INT = 0

        INSERT INTO Load.%%ENTITY_TABLE_NAME%%
        SELECT
             @LoadId
            ,@UTCDateTime
            ,@FileName
            %%COLUMN_LIST%%
        FROM 
            @Data
            
END
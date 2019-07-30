
DROP PROC IF EXISTS %%SOURCE_SYSTEM%%.Clean%%ENTITY%%
GO

CREATE PROC %%SOURCE_SYSTEM%%.Clean%%ENTITY%%
(
    @LoadId INTEGER = NULL
)

AS
BEGIN

    DROP TABLE IF EXISTS #%%ENTITY%%
	
	TRUNCATE TABLE Stage.%%ENTITY%%

	BEGIN TRY

		SELECT
             @LoadId AS LoadId
            ,GETDATE() AS LoadDate
		    %%SOURCE_COLUMN_LIST_WITH_RULES%%
		INTO #%%ENTITY%%
		FROM
		    Stage.%%ENTITY%%

		INSERT INTO Clean.%%ENTITY%%
		SELECT
			 LoadId
            ,GETDATE() AS LoadDate
			%%SOURCE_COLUMN_LIST%%
		FROM
			#%%ENTITY%%

	END TRY

	BEGIN CATCH
		
		RAISERROR('Could not complete the clean / rules step for %%SOURCE_SYSTEM%%.%%ENTITY%%',1,1);

	END CATCH


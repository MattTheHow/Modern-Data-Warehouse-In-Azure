
DROP PROC IF EXISTS Base.Load%%ENTITY_TABLE_NAME%%_to_Base%%ENTITY_TABLE_NAME%%
GO

CREATE PROC Base.Load%%ENTITY_TABLE_NAME%%_to_Base%%ENTITY_TABLE_NAME%%
(	
    @LoadId INTEGER = NULL
)

AS
BEGIN

	DECLARE @ErrorMessage VARCHAR(250)
	DECLARE @TotalCount INT = 0
	DECLARE @InsertCount INT = 0
	DECLARE @RejectCount INT = 0

	DROP TABLE IF EXISTS #tmp

	-- Check data exists in LOAD for LoadID
	IF NOT EXISTS
		(
		SELECT 1
		FROM Load.%%ENTITY_TABLE_NAME%% AS l
		WHERE l.LoadID = @LoadID
		)
	BEGIN
		SELECT @ErrorMessage = CONCAT ('No data found in LOAD for LoadID ', @LoadID)
		RAISERROR(@ErrorMessage,16,1)
		RETURN
	END

-- Check that data does not exist in BASE already
	IF EXISTS
		(
		SELECT 1
		FROM Base.%%ENTITY_TABLE_NAME%% AS b
		WHERE b.LoadID = @LoadID
		)
	BEGIN
		SELECT @ErrorMessage = CONCAT ('Data already exists in BASE for LoadID ', @LoadID)
		RAISERROR(@ErrorMessage,16,1)
		RETURN
	END

-- Get the total count from LOAD
	SELECT @TotalCount = COUNT(*) FROM Load.%%ENTITY_TABLE_NAME%% WHERE LoadID = @LoadID
	

	-- Check for any Bad rows
	SELECT
		LoadId,
		LoadDateTime,
		FileName
		%%COLUMN_LIST_BASE%%
		%%COLUMN_LIST_WITH_TRY_CAST%%
	INTO #tmp
	FROM Load.%%ENTITY_TABLE_NAME%%
	WHERE LoadId = @LoadId
	%%SCREEN_SQL%%

	PRINT 'Loaded rows to temp, starting insert'

	-- If there are bad records, put all records into Bad
	IF EXISTS
		(
		SELECT 1
		FROM #tmp AS t
		WHERE (%%COLUMN_LIST_AS_TRY%%) IS NULL
		)
		BEGIN
			INSERT INTO Bad.%%ENTITY_TABLE_NAME%%
				(
					LoadId,
					LoadDateTime,
					FileName
					%%COLUMN_LIST_BASE%%
					,ErrorColumn
				)
			SELECT
				LoadId,
				LoadDateTime,
				FileName
				%%COLUMN_LIST_BASE%%
				%%COLUMN_LIST_AS_CASE%%
			FROM #tmp

	-- Get the number of bad rows
			SELECT @RejectCount = COUNT(*) FROM #tmp
				WHERE (%%COLUMN_LIST_AS_TRY%%) IS NULL

			SELECT @ErrorMessage = CONCAT ('Data not loaded to Base.%%ENTITY_TABLE_NAME%% - See Bad.%%ENTITY_TABLE_NAME%% for LoadID ', @LoadID)
			RAISERROR(@ErrorMessage,16,1)
			RETURN
		END
	ELSE
		BEGIN
			PRINT 'Loaded rows to temp, starting insert'
	

		BEGIN TRANSACTION
	-- Insert records into BASE
		BEGIN TRY
			INSERT INTO Base.%%ENTITY_TABLE_NAME%%
				(
				LoadID,
				LoadDateTime,
				FileName
				%%COLUMN_LIST_BASE%%		
				)
			SELECT
				t.LoadID,
				t.LoadDateTime,
				t.FileName
				%%SOURCE_COLUMN_LIST_WITH_RULES%%
				%%COLUMN_LIST_AS_SCD2_STRING%%
			FROM #tmp AS t

			SET @InsertCount = @@ROWCOUNT
			PRINT CONCAT(@@ROWCOUNT, ' records loaded')
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	--		SELECT @ErrorMessage = CONCAT ('Error loading data into Base for LoadID ', @LoadID)
	--		RAISERROR(@ErrorMessage,16,1)
	--		RETURN
		END CATCH
	END

	IF @@TRANCOUNT > 0 COMMIT TRANSACTION

	SELECT
		@TotalCount AS TotalCount,
		@InsertCount AS InsertCount,
		@RejectCount AS RejectCount,
		OBJECT_NAME(@@PROCID) AS ProcName
		
END
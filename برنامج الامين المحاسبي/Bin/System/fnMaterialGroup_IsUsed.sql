###########################################################################
CREATE  FUNCTION fnMaterialGroup_IsUsed( @MatGUID [UNIQUEIDENTIFIER], @GroupGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
/*
	this function:
		- returns a constant integer representing the existance of a given material in database tables.
		- is usually called from trg_mt000_CheckConstraints.
	*/    
	DECLARE @result [INT]
	SET @result = 0	
	
	--*************************************************************************************************************
		-- Code to check material is used in Al-Ameen Application
		SELECT @result = [dbo].[fnMaterial_IsUsed](@MatGUID);
		-- Code to check material is used in POS for smart devices		
		IF @result = 0 
			BEGIN
				IF [dbo].[fnObjectExists]('POSSDStationGroup000') <> 0 
					BEGIN
						DECLARE @GroupTemp TABLE (GroupGuid UNIQUEIDENTIFIER)
						DECLARE @GroupToBeVerified UNIQUEIDENTIFIER;
						SET @GroupToBeVerified = @GroupGUID;
						INSERT INTO @GroupTemp SELECT @GroupToBeVerified;
						INSERT INTO @GroupTemp SELECT [GUID] FROM [dbo].[fnGetGroupParents](@GroupToBeVerified) WHERE [GUID] <> 0x0;
						INSERT INTO @GroupTemp SELECT GroupGuid FROM gri000 WHERE MatGuid = @GroupToBeVerified;
						IF EXISTS((SELECT * FROM @GroupTemp GT INNER JOIN POSSDStationGroup000 RP ON GT.GroupGuid = RP.GroupGUID))
						SET @result = 0x000129;
					END;
			END;
	--*************************************************************************************************************
	IF @result IS NULL 
		SET @result = 0
	
	RETURN @result
END
###########################################################################
#END
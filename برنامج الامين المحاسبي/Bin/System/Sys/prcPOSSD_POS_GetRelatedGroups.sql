#################################################################
CREATE PROCEDURE prcPOSGetRelatedGroups
@POSCardGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Groups TABLE
	(
		Number		INT,
		GroupGUID	UNIQUEIDENTIFIER,  
		Name		NVARCHAR(MAX),
		Code		NVARCHAR(MAX),
		ParentGUID	UNIQUEIDENTIFIER,  
		LatinName	NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT
	) 
	DECLARE @GroupGUID UNIQUEIDENTIFIER , @GroupIndex INT
	DECLARE @GroupCursor as CURSOR;
 
	SET @GroupCursor = CURSOR FOR
		SELECT relatedgroup.[GroupGuid], relatedgroup.[Number]
		FROM POSRelatedGroupS000 relatedgroup 
		INNER JOIN gr000 gr on gr.GUID = relatedgroup.GroupGuid 
		WHERE POSGuid = @POSCardGuid
 

	 INSERT INTO @Groups(Name,Number, Code,LatinName, GroupGUID, ParentGUID, PictureGUID, GroupIndex)
		SELECT DISTINCT(gr.Name),gr.Number,gr.Code,gr.LatinName,gr.Guid as GroupGUID, gr.ParentGUID, gr.PictureGUID, pos.Number
		FROM gr000 gr
		INNER JOIN POSRelatedGroupS000 pos ON pos.[GroupGuid] = gr.[GUID]
		WHERE pos.[POSGuid] = @POSCardGuid

	OPEN @GroupCursor;
	FETCH NEXT FROM @GroupCursor INTO @GroupGUID, @GroupIndex;
 
	WHILE @@FETCH_STATUS = 0
	BEGIN
	
	 INSERT INTO @Groups (Name,Number, Code,LatinName, GroupGUID, ParentGUID, PictureGUID, GroupIndex)
			SELECT  DISTINCT(gr.Name),gr.Number,gr.Code,gr.LatinName,gr.Guid as GroupGUID, gr.ParentGUID, gr.PictureGUID, @GroupIndex
			FROM fnGetGroupsList(@GroupGUID) AS tempTb 
			INNER JOIN gr000 gr ON gr.GUID = tempTb.GUID
			INNER JOIN mt000 material ON material.GroupGUID = tempTb.Guid
			WHERE  NOT EXISTS(SELECT GroupGUID
						FROM @Groups t2
					   WHERE t2.GroupGUID = gr.Guid)
			 
	 FETCH NEXT FROM @GroupCursor INTO @GroupGUID, @GroupIndex;
	
	END
 
	CLOSE @GroupCursor;
	DEALLOCATE @GroupCursor;

	SELECT Number,		 
		   GroupGUID,	
		   Name,		
		   Code,	
		   ParentGUID,	
		   LatinName,	
		   PictureGUID, 
		   GroupIndex
	FROM @Groups
END
#################################################################
#END 
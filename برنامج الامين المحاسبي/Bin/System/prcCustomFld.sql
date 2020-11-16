################################################################################
CREATE PROCEDURE rep_GetCustomField 
					@GroupGuid UNIQUEIDENTIFIER,
					@SortBy	   BIT = 0 -- 0 for sorting by SortNumber, 1 for sorting by Number 
AS 
	SET NOCOUNT ON

	SELECT [CF].[Guid], [CF].[Name], [CF].[LatinName], [CF].[FldType], [CF].[Format], [CF].[IsUnique], 
		   [CF].[SortNumber], [CF].[Mandatory] , [CF].[ColumnName], 
  		   [CF].[TextDefaultValue], [CF].[IntDefaultValue], [CF].[FloatDefaultValue], 
		   [CFG].[Guid] AS [GroupGuid], [CFG].[Name] AS [GroupName],    
		   [CFG].[LatinName] AS [GroupLatinName], [CFG].[TableName]
	         
	FROM   CFFlds000 AS CF INNER JOIN CFGroup000  AS CFG ON [CF].[GGuid] = [CFG].[Guid]   
	WHERE     ([CF].[GGuid] = @GroupGuid)   
	ORDER BY  CASE @SortBy WHEN 0 THEN [CF].[SortNumber] ELSE [CF].[Number] END
################################################################################
CREATE  PROCEDURE rep_GetSelectedCustomField
@GroupGuid UNIQUEIDENTIFIER ,
@TypeGuid UNIQUEIDENTIFIER  
AS  
SET NOCOUNT ON 

	DECLARE @OldCF TABLE ([Guid] UNIQUEIDENTIFIER, [Name] NVARCHAR(500), [LatinName] NVARCHAR(500), [FldType] INT, [Format] INT , [IsUnique] INT,  
					[SortNumber] INT, [Mandatory] INT, [ColumnName] NVARCHAR(500), [TextDefaultValue] NVARCHAR(500), [IntDefaultValue] INT, 
					[FloatDefaultValue] FLOAT, [GroupGuid] UNIQUEIDENTIFIER, [GroupName] NVARCHAR(500), [GroupLatinName] NVARCHAR(500), 
					[TableName] NVARCHAR(500), [Selected] INT)

	DECLARE @NewCF TABLE ([Guid] UNIQUEIDENTIFIER, [Name] NVARCHAR(500), [LatinName] NVARCHAR(500), [FldType] INT, [Format] INT , [IsUnique] INT,  
					[SortNumber] INT, [Mandatory] INT, [ColumnName] NVARCHAR(500), [TextDefaultValue] NVARCHAR(500), [IntDefaultValue] INT, 
					[FloatDefaultValue] FLOAT, [GroupGuid] UNIQUEIDENTIFIER, [GroupName] NVARCHAR(500), [GroupLatinName] NVARCHAR(500), 
					[TableName] NVARCHAR(500), [Selected] INT)

INSERT INTO @OldCF SELECT [CF].[Guid], [CF].[Name], [CF].[LatinName], [CF].[FldType], [CF].[Format], [CF].[IsUnique],  
	   [CF].[SortNumber], [CF].[Mandatory] , [CF].[ColumnName],  
		   [CF].[TextDefaultValue], [CF].[IntDefaultValue], [CF].[FloatDefaultValue],  
	   [CFG].[Guid] AS [GroupGuid], [CFG].[Name] AS [GroupName],      
	   [CFG].[LatinName] AS [GroupLatinName], [CFG].[TableName], CFSel.[Selected]
          
FROM   CFFlds000 AS CF  INNER JOIN CFGroup000  AS CFG ON [CF].[GGuid] = [CFG].[Guid]  
			INNER JOIN CFSelFlds000 AS CFSel ON CF.Guid = CFSel.CFGuid 
WHERE     ([CF].[GGuid] = @GroupGuid AND CFSel.BtGuid = @TypeGuid)    


INSERT INTO @NewCF  SELECT [CF].[Guid], [CF].[Name], [CF].[LatinName], [CF].[FldType], [CF].[Format], [CF].[IsUnique],  
	   [CF].[SortNumber], [CF].[Mandatory] , [CF].[ColumnName],  
		   [CF].[TextDefaultValue], [CF].[IntDefaultValue], [CF].[FloatDefaultValue],  
	   [CFG].[Guid] AS [GroupGuid], [CFG].[Name] AS [GroupName],     
	   [CFG].[LatinName] AS [GroupLatinName], [CFG].[TableName] , 0 as Selected
          
FROM   CFFlds000 AS CF  INNER JOIN CFGroup000  AS CFG ON [CF].[GGuid] = [CFG].[Guid]  
			
WHERE     ([CF].[GGuid] = @GroupGuid AND [CF].[Guid] NOT IN (SELECT Guid FROM @OldCF)) 

SELECT * FROM @OldCF 
UNION 
SELECT * FROM @NewCF  
ORDER BY  [SortNumber]  
################################################################################
CREATE PROCEDURE rep_GetCustomFieldForMapping
@TableName NVARCHAR(256) ,
@TypeGuid UNIQUEIDENTIFIER = 0x00, -- for appearing selected Custom Fields as Bill Types and likes 
@SortBy	   BIT = 0	--0 for sorting by SortNumber, 1 for sorting by Number
AS 
SET NOCOUNT ON 
DECLARE @GroupGuid UNIQUEIDENTIFIER 
SET @GroupGuid =( SELECT CFGroup_Guid FROM CFMapping000 WHERE Orginal_Table = @TableName and isMapped = 1) 
IF (@TypeGuid = 0x00)
BEGIN
	EXEC rep_GetCustomField @GroupGuid, @SortBy 
END
ELSE
BEGIN
	EXEC rep_GetSelectedCustomField @GroupGuid , @TypeGuid
END
################################################################################
CREATE PROCEDURE prcDeleteCustomFieldGroup
					@GroupGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE @TableName NVARCHAR(255)

	SET @TableName = (SELECT DISTINCT CFGroup_Table FROM CFMapping000
	WHERE CFGroup_Guid = @GroupGuid)

	DELETE FROM CFFlds000 WHERE GGuid = @GroupGuid
	DELETE FROM CFMapping000 WHERE CFGroup_Guid = @GroupGuid
	DELETE FROM CFGroup000 WHERE Guid = @GroupGuid

###################################################################################
CREATE TRIGGER trg_CFFlds000_Delete
	ON [CFFlds000] FOR DELETE
	NOT FOR REPLICATION
AS   
	-- THIS TRIGGER IS AUTO Drop Column matching with  Deleted Custom Field    
	IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1  
		RETURN  
	SET NOCOUNT ON   
	DECLARE @TableName NVARCHAR(255),  
	        @ColumnName NVARCHAR(255) 
    SET @TableName =(SELECT TableName FROM CFGroup000 G  
                     inner join DELETED D ON G.Guid = D.GGuid  ) 
	SET @ColumnName =(SELECT ColumnName FROM DELETED) 
	EXEC prcDropFld @TableName, @ColumnName 
	
      -- If Exists, Delete CF which involved in Customized printing of bill 
	if exists( SELECT CFGroup_Guid FROM CFMapping000 CFM  
                   INNER JOIN DELETED D ON CFM.CFGroup_Guid = D.GGuid 
		   WHERE Orginal_Table ='bu000') 
	BEGIN
		DECLARE @ColumnNumber INT
		SET @ColumnNumber =(SELECT SortNumber FROM DELETED)
		DELETE FROM BLHeader000 WHERE ID = 16000 + @ColumnNumber
		UPDATE BLHeader000 SET ID = ID -1
		WHERE  ID > 16000 + @ColumnNumber
	END	 	
###################################################################################
CREATE TRIGGER trg_CFFlds000_Update
	ON [CFFlds000] FOR UPDATE
	NOT FOR REPLICATION
AS  
	-- THIS TRIGGER IS AUTO Add Column To Matched Table matching with Updated Custom Field 
	
 	IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1 
		RETURN 
	SET NOCOUNT ON  
   	    
	declare @OldColumnName NVARCHAR(255),
			@NewColumnName NVARCHAR(255)	
   
	SET @OldColumnName =(SELECT ColumnName FROM DELETED )
	SET @NewColumnName =(SELECT ColumnName FROM INSERTED)
	IF @OldColumnName != @NewColumnName
	BEGIN
	declare @TableName NVARCHAR(255), 
			@ColumnType NVARCHAR(255),
		    @Sql NVARCHAR(max) 		
	SET @TableName =(SELECT TableName FROM CFGroup000 G 
                     inner join INSERTED I on G.Guid = I.GGuid  )

	SELECT @ColumnType =  CASE FldType 
						  WHEN 0 THEN ' NVARCHAR(255) '
						  WHEN 1 THEN ' int '
						  WHEN 2 THEN ' float '
						  WHEN 3 THEN ' float '
						  WHEN 4 THEN ' datetime '
						  WHEN 5 THEN ' NVARCHAR(255) '
						  WHEN 6 THEN ' int ' --bit 
					   	  ELSE ' NVARCHAR(255) '
     				   END
					   FROM  INSERTED 				
	
	EXEC prcRenameFld @TableName, @OldColumnName, @NewColumnName
	EXEC prcAlterFld @TableName, @NewColumnName, @ColumnType
END

###################################################################################
CREATE TRIGGER trg_CFlds000_Insert
	ON [CFFlds000] FOR INSERT 
	NOT FOR REPLICATION
	AS
-- THIS TRIGGER IS AUTO Add Column To Matched Table matching with Inserted Custom Field      
	IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1  
		RETURN   
	SET NOCOUNT ON    
   
	DECLARE @TableName NVARCHAR(255),   
	        @ColumnName NVARCHAR(255),  
			@ColumnType NVARCHAR(255),  
		    @Sql NVARCHAR(max) 		  
		      
    SET @TableName =(SELECT TableName FROM CFGroup000 G   
                     INNER JOIN INSERTED I ON G.Guid = I.GGuid  )  
                       
	SET @ColumnName =(SELECT ColumnName FROM  INSERTED )  
   
	SELECT @ColumnType =  CASE FldType   
						  WHEN 0 THEN ' NVARCHAR(255) '  
						  WHEN 1 THEN ' int '  
						  WHEN 2 THEN ' float '  
						  WHEN 3 THEN ' float '  
						  WHEN 4 THEN ' datetime '  
						  WHEN 5 THEN ' NVARCHAR(255) '  
						  WHEN 6 THEN ' int ' --bit  
					   	  ELSE ' NVARCHAR(255) '  
     				   END  
					   FROM  INSERTED 	 					  
	  
	EXEC prcAddFld @TableName, @ColumnName, @ColumnType  
/* insert default value when he adds new CustomField and isMandatory = true */
	DECLARE @Mandatory int  
	SELECT	@Mandatory = Mandatory	FROM  INSERTED 
	IF @Mandatory = 1 
	BEGIN 
		declare @FldType int
		select 	@FldType = FldType from INSERTED
		SET  @Sql = ' UPDATE  ' + @TableName + ' SET ' + @ColumnName + ' = '
			if (@FldType in (0,5))   
				SET  @Sql = @Sql + '''' + (select TextDefaultValue FROM  INSERTED) + ''''
	   else if (@FldType in (2,3))   
				SET  @Sql =@Sql   + (select convert(NVARCHAR(255), FloatDefaultValue) FROM  INSERTED)  
 	   else if (@FldType in (1,4,6)) 
				SET  @Sql =@Sql + (select convert(NVARCHAR(255), IntDefaultValue) FROM  INSERTED)
		else
				SET  @Sql =@Sql  + ' 0 '

        EXEC (@Sql) 
	END  

###################################################################################
CREATE TRIGGER trg_CFGroup000_Insert 
	ON [CFGroup000] FOR INSERT
	NOT FOR REPLICATION 
AS   
	-- THIS TRIGGER IS AUTO Create Table matching with  Inserted Custom Field Group   
	IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1 
		RETURN  
	SET NOCOUNT ON   
  
	declare @TableName NVARCHAR(255), 
		    @Sql NVARCHAR(max)  
		     
	SET @TableName =(SELECT 'CF_Value'+ Convert(NVARCHAR(5),ISNULL(max(substring(TableName,9,3))+1,1)) FROM CFGroup000)  
	 
    Update  CFGroup000 
	SET TableName = @TableName 
	Where Guid = (Select Guid from [INSERTED]) 
	IF [dbo].[fnObjectExists]( @TableName) = 0 
		BEGIN 
			SET @Sql = ' CREATE TABLE [dbo].['+@TableName +']( 
				[Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_'+ @TableName  +'_Guid] DEFAULT (newid()),  
				[Orginal_Guid] [uniqueidentifier] NOT NULL ,
				[Orginal_Table] NVARCHAR(255)   NOT NULL ,
				CONSTRAINT [PK_'+ @TableName +'] PRIMARY KEY  CLUSTERED  
				([Guid]) ON [PRIMARY] ) ON [PRIMARY] ' 
			 EXEC (@Sql) 
		 END 

###################################################################################
CREATE TRIGGER trg_CFGroup000_Delete 
	ON [CFGroup000] FOR DELETE
	NOT FOR REPLICATION
AS  
	-- THIS TRIGGER IS AUTO Drop Table matching with  Deleted Custom Field Group  
	IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1 
		RETURN 
	SET NOCOUNT ON  

	declare @TableName NVARCHAR(255)
		    
	SET @TableName =(SELECT TableName FROM DELETED)
	
	EXEC [prcDropTable] @TableName
	
###################################################################################
CREATE TRIGGER trg_CFMapping_Insert
	ON [CFMapping000] FOR INSERT ,DELETE--, UPDATE
	NOT FOR REPLICATION
AS    
	-- THIS TRIGGER IS AUTO create or Drop Triger on Table matching with Inserted Orginal_Table       
	IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1   
		RETURN    
	SET NOCOUNT ON     
	DECLARE @Orginal_Table NVARCHAR(255),	         
			@TableName     NVARCHAR(255), 
		        @Sql           NVARCHAR(max) 
		          
	IF EXISTS(SELECT * FROM [DELETED])  
	BEGIN 
		SET @Orginal_Table =(SELECT Orginal_Table FROM DELETED ) 
		IF [dbo].[fnObjectExists]( 'trg_CF'+ @Orginal_Table +'_Delete') = 1 
		BEGIN   
			SET  @Sql = ' Drop TRIGGER [trg_CF'+ @Orginal_Table +'_Delete]' 
			 IF(@Orginal_Table = 'bu000')
				SET  @Sql = @Sql + 'Delete from BLHeader000 where id >= 16000 '
			EXEC (@Sql) 
		END 
	END  
	IF EXISTS(SELECT * FROM [inserted])  
	BEGIN	 
		 
		SET @Orginal_Table =(SELECT Orginal_Table FROM INSERTED )  
	    	SET @TableName =(SELECT CFGroup_Table FROM INSERTED )   
		IF [dbo].[fnObjectExists]( 'trg_CF'+ @Orginal_Table +'_Delete') = 0 
		BEGIN 
			SET  @Sql = ' Create  TRIGGER [dbo].[trg_CF'+ @Orginal_Table +'_Delete] 
			 ON ['+ @Orginal_Table + '] FOR DELETE 
			 AS  
			 /* THIS TRIGGER IS AUTO Delete record from ' + @TableName + ' Table when delete record from ' + @Orginal_Table + ' which matching with it */ 
			 IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1   
				 RETURN    
	         SET NOCOUNT ON  
			 DECLARE @Orginal_Guid uniqueidentifier 
			 SET @Orginal_Guid = (SELECT Guid FROM DELETED ) 
			 Delete from ' + @TableName + ' where Orginal_Guid = @Orginal_Guid ' 
			
			 EXEC (@Sql)	 
		END				   
	END 

###################################################################################
CREATE PROCEDURE PrcGetCFBillRecToPrint
@buGUID UNIQUEIDENTIFIER,
@Lang bit  
AS  
-- This Proc to get CFs Name , CFs Value , and CFs SortNumbe To print Bill  
SET NOCOUNT ON   
DECLARE @TableName NVARCHAR(255),  
	@ColumnName NVARCHAR(255),  
	@CustomerGuid as UNIQUEIDENTIFIER,
	@Sql NVARCHAR (max),  
	@C CURSOR  
	
	
	SET @TableName = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000')  
	  
	CREATE TABLE [#CFValue]( [ColumnName] NVARCHAR(255), [ColumnValue] NVARCHAR(255), [SortNumber] INT ,[CFName] NVARCHAR(255), [OrgTbName] NVARCHAR(255))  
	  
	INSERT INTO [#CFValue]   
	SELECT CF.ColumnName ,'', CF.SortNumber, CASE @Lang WHEN 0 THEN CF.Name 
						 ELSE CASE CF.LatinName WHEN '' THEN CF.Name 
						 ELSE CF.LatinName END END , 'bu000'   
	FROM CFFlds000 CF INNER JOIN CFGroup000 CFG ON CFG.Guid = CF.GGuid  
				 	 INNER JOIN CFMapping000 CFM ON CFG.Guid = CFM.CFGroup_Guid  
	WHERE Orginal_Table = 'bu000' ORDER BY CF.SortNumber  
	  
	SET @C = CURSOR FAST_FORWARD FOR SELECT [ColumnName] FROM [#CFValue]   
	OPEN @C FETCH NEXT FROM @C INTO @ColumnName    
	  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		if (substring(@ColumnName,1,4)='Date') 
		BEGIN 
			SET @Sql = 'UPDATE #CFValue  SET ColumnValue = (SELECT convert (NVARCHAR(50), ' + @ColumnName + ' ,105) FROM '+  @TableName + ' WHERE Orginal_Guid = ''' +  
				    Convert (NVARCHAR(36),@buGUID)+''') WHERE ColumnName = ''' + @ColumnName + '''' 	 
		END 
		ELSE 
		BEGIN 
			SET @Sql = 'UPDATE #CFValue  SET ColumnValue = (SELECT ' + @ColumnName + ' FROM '+  @TableName + ' WHERE Orginal_Guid = ''' +  
				    Convert (NVARCHAR(36),@buGUID)+''') WHERE ColumnName = ''' + @ColumnName + ''''  
		END 
		EXEC(@Sql)  
		  
		FETCH NEXT FROM @C INTO @ColumnName  
	END   
	CLOSE @C DEALLOCATE @C  

	-- For Get Customer CustomFields Values
	CREATE TABLE [#CustCFValue]( [ColumnName] NVARCHAR(255), [ColumnValue] NVARCHAR(255), [SortNumber] INT ,[CFName] NVARCHAR(255), [OrgTbName] NVARCHAR(255))
	SET @CustomerGuid = (SELECT CustGUID FROM bu000 where Guid = @buGUID )
	SET @TableName = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000') 
	if (@TableName IS NOT NULL)
	Begin
		INSERT INTO [#CustCFValue]   
		SELECT CF.ColumnName ,'', CF.SortNumber + 200 , CASE @Lang WHEN 0 THEN CF.Name 
						 ELSE CASE CF.LatinName WHEN '' THEN CF.Name 
						 ELSE CF.LatinName END END , 'cu000'   
		FROM CFFlds000 CF INNER JOIN CFGroup000 CFG ON CFG.Guid = CF.GGuid  
				  INNER JOIN CFMapping000 CFM ON CFG.Guid = CFM.CFGroup_Guid  
		WHERE Orginal_Table = 'cu000' ORDER BY CF.SortNumber
		SET @C = CURSOR FAST_FORWARD FOR SELECT [ColumnName] FROM [#CustCFValue]   
	
		OPEN @C FETCH NEXT FROM @C INTO @ColumnName    
		  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			if (substring(@ColumnName,1,4)='Date') 
			BEGIN 
				SET @Sql = 'UPDATE #CustCFValue  SET ColumnValue = (SELECT convert (NVARCHAR(50), ' + @ColumnName + ' ,105) FROM '+  @TableName + ' WHERE Orginal_Guid = ''' +  
					    Convert (NVARCHAR(36),@CustomerGuid)+''') WHERE ColumnName = ''' + @ColumnName + '''' 	 
			END 
			ELSE 
			BEGIN 
				SET @Sql = 'UPDATE #CustCFValue  SET ColumnValue = (SELECT ' + @ColumnName + ' FROM '+  @TableName + ' WHERE Orginal_Guid = ''' +  
					    Convert (NVARCHAR(36),@CustomerGuid)+''') WHERE ColumnName = ''' + @ColumnName + ''''  
			END 
			EXEC(@Sql)  
			  
			FETCH NEXT FROM @C INTO @ColumnName  
		END   
		CLOSE @C DEALLOCATE @C   		
	END	

	SELECT * FROM #CFValue 
	union
	SELECT * FROM #CustCFValue ORDER BY OrgTbName, SortNumber
###################################################################################
CREATE PROCEDURE  PrcGetCFMatRecToPrint
@MatGuid [UNIQUEIDENTIFIER] = 0x00 ,
@Lang bit = 0 , 
@CFName NVARCHAR(255) = ''
AS
SET NOCOUNT ON   
DECLARE @ColumnName NVARCHAR(255),
	@TableName NVARCHAR(255),
	@Sql NVARCHAR (1000)
SET @ColumnName = (SELECT ColumnName FROM CFFlds000 WHERE (CASE @Lang WHEN 0 THEN Name ELSE LatinName END) = @CFName)
if(@ColumnName IS NULL)
begin
	SELECT '' CFValue
END
ELSE
BEGIN
	--select @ColumnName AS ColumnName
	SET @TableName = (SELECT CFGroup_Table from CFMapping000 WHERE Orginal_Table = 'mt000' )
	SET @Sql = ' SELECT CONVERT (NVARCHAR(255),'  + @ColumnName + ') CFValue  FROM ' +  @TableName  + ' WHERE Orginal_Guid = ''' + CONVERT (NVARCHAR(36),@MatGuid)+''''
	EXEC (@Sql)
END
/*
PrcGetCFMatRecToPrint 'CB0CB318-53C9-4CC0-A17C-D4DB16261B5A', 0, ''
*/
###################################################################################
CREATE PROCEDURE prcGetEntryCFsToPrint
	@entGUID UNIQUEIDENTIFIER, 
	@Lang bit   
AS  
	SET NOCOUNT ON    
	DECLARE @TableName NVARCHAR(255),   
		@ColumnName NVARCHAR(255),   
		@CustomerGuid as UNIQUEIDENTIFIER, 
		@Sql NVARCHAR (max),   
		@C CURSOR   	 
	 
	SET @TableName = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'py000')   
	   
	CREATE TABLE [#CFValue]( [ColumnName] NVARCHAR(255), [ColumnValue] NVARCHAR(255), [SortNumber] INT ,[CFName] NVARCHAR(255), [OrgTbName] NVARCHAR(255))   
	   
	INSERT INTO [#CFValue]    
	SELECT CF.ColumnName ,'', CF.SortNumber, CASE @Lang WHEN 0 THEN CF.Name  
						 ELSE CASE CF.LatinName WHEN '' THEN CF.Name  
						 ELSE CF.LatinName END END , 'py000'    
	FROM CFFlds000 CF INNER JOIN CFGroup000 CFG ON CFG.Guid = CF.GGuid   
				 	 INNER JOIN CFMapping000 CFM ON CFG.Guid = CFM.CFGroup_Guid   
	WHERE Orginal_Table = 'py000' ORDER BY CF.SortNumber   
	   
	SET @C = CURSOR FAST_FORWARD FOR SELECT [ColumnName] FROM [#CFValue]    
	OPEN @C FETCH NEXT FROM @C INTO @ColumnName     
	   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		if (substring(@ColumnName,1,4)='Date')  
		BEGIN  
			SET @Sql = 'UPDATE #CFValue  SET ColumnValue = (SELECT convert (NVARCHAR(50), ' + @ColumnName + ' ,105) FROM '+  @TableName + ' WHERE Orginal_Guid = ''' +   
				    Convert (NVARCHAR(36),@entGUID)+''') WHERE ColumnName = ''' + @ColumnName + '''' 	  
		END  
		ELSE  
		BEGIN  
			SET @Sql = 'UPDATE #CFValue  SET ColumnValue = (SELECT ' + @ColumnName + ' FROM '+  @TableName + ' WHERE Orginal_Guid = ''' +   
				    Convert (NVARCHAR(36),@entGUID)+''') WHERE ColumnName = ''' + @ColumnName + ''''   
		END  
		EXEC(@Sql)   
		   
		FETCH NEXT FROM @C INTO @ColumnName   
	END    
	CLOSE @C DEALLOCATE @C   
 
	SELECT * FROM #CFValue 
###################################################################################
CREATE PROCEDURE prcCopyCFsValueTablesItems
	@SrcDb NVARCHAR(250), 
	@DestDb NVARCHAR(250)
	 
AS  
	SET NOCOUNT ON  
	 
	DECLARE @c CURSOR, @o CURSOR 
	DECLARE @q NVARCHAR(250), @st NVARCHAR(250), @dt NVARCHAR(250) 
	DECLARE @tblName NVARCHAR(250)
	 
	CREATE TABLE #CFs_OrginalTable_Guids (OrginalTable NVARCHAR(250), Guid UNIQUEIDENTIFIER) 
	CREATE TABLE #CFs_OrginalTables (Orginal_Table NVARCHAR(250)) 
		 
	SET @c = CURSOR FOR	SELECT TableName FROM CFGroup000 
	OPEN @c 
	FETCH FROM @c INTO @tblName 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		DELETE FROM #CFs_OrginalTable_Guids 
		DELETE FROM #CFs_OrginalTables 
		 
		SET @st = @SrcDb + '..' + @tblName 
		SET @dt = @DestDb + '..' + @tblName 
		 
		SET @q = ' SELECT DISTINCT Orginal_Table FROM ' + @st 
		INSERT INTO #CFs_OrginalTables EXEC(@q) 
		SET @o = CURSOR FOR	SELECT Orginal_Table FROM #CFs_OrginalTables 
		OPEN @o 
		FETCH FROM @o INTO @tblName 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			INSERT INTO [#CFs_OrginalTable_Guids]  
				EXEC (' SELECT ''__tbl__'' AS OrginalTable, Guid FROM ' + @DestDb + '..' + @tblName) 
			UPDATE #CFs_OrginalTable_Guids SET OrginalTable = @tblName WHERE OrginalTable = '__tbl__' 
			 
			FETCH FROM @o INTO @tblName 
		END 
		CLOSE @o
		DEALLOCATE @o
		 
		SET @q = ' IF EXISTS (SELECT * FROM ' + @DestDb + '..sysobjects WHERE id = object_id(''' + @dt + '''))' + ' DROP TABLE ' + @dt 
		--PRINT(@q) 
		EXEC(@q) 
		 
		SET @q = ' SELECT * INTO ' + @dt + ' FROM ' + @st 
		SET @q = @q + ' WHERE Orginal_Guid IN ( SELECT Guid FROM [#CFs_OrginalTable_Guids] WHERE OrginalTable COLLATE DATABASE_DEFAULT = Orginal_Table COLLATE DATABASE_DEFAULT ) ' 
		 
		EXEC(@q)
		FETCH FROM @c INTO @tblName 
	END
	
	CLOSE @c
	DEALLOCATE @c
###################################################################################
CREATE PROCEDURE prcCopyCFsValueTables_Constraints 
	@SrcDb NVARCHAR(250), 
	@DestDb NVARCHAR(250) 
	 
AS  
	SET NOCOUNT ON  
	 
	DECLARE @c CURSOR
	DECLARE @q NVARCHAR(250), @st NVARCHAR(250), @dt NVARCHAR(250) 
	DECLARE @tblName NVARCHAR(250)
	DECLARE @CF_Value_tbl NVARCHAR(250)
	 
	CREATE TABLE #CFs_OrginalTables (Orginal_Table NVARCHAR(250)) 
		 
	SET @c = CURSOR FOR	SELECT TableName FROM CFGroup000 
	OPEN @c 
	FETCH FROM @c INTO @tblName 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		DELETE FROM #CFs_OrginalTables 
		 
		SET @dt = @DestDb + '..' + @tblName 
		SET @CF_Value_tbl = @tblName
		
		SET @q = ' ALTER TABLE ' + @dt + ' ADD CONSTRAINT [DF_' + @CF_Value_tbl + '_Guid] DEFAULT (newid()) FOR Guid'
		--PRINT(@q)
		EXEC (@q)
		 
		FETCH FROM @c INTO @tblName 
	END
	CLOSE @c
	DEALLOCATE @c
###################################################################################
CREATE PROCEDURE prcCopyCFsValueTables
	@SrcDb NVARCHAR(250), 
	@DestDb NVARCHAR(250)	 
AS  
	SET NOCOUNT ON  
	
	EXEC prcCopyCFsValueTablesItems @SrcDb, @DestDb
	EXEC prcCopyCFsValueTables_Constraints @SrcDb, @DestDb
###################################################################################
#END 
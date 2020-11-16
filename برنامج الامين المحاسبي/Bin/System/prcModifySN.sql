###########################################
CREATE PROCEDURE prcGetSns
	@buGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	CREATE TABLE #BI
	(
		NUMBER INT IDENTITY(0,1),
		[GUID] [UNIQUEIDENTIFIER]
	)
	CREATE TABLE #sn ([parentGuid] [UNIQUEIDENTIFIER], [biguid] [UNIQUEIDENTIFIER], [item] FLOAT)
	INSERT INTO [#BI] ([GUID]) SELECT  [GUID] FROM BI000 WHERE [ParentGuid] = @buGuid ORDER BY [number],[guid]
	CREATE CLUSTERED INDEX [sdfs] on [#BI](NUMBER,[GUID])
	INSERT INTO #sn SELECT [parentGuid],[biguid],[item] from [snt000] WHERE buguid = @buGuid
	CREATE CLUSTERED INDEX [snt] on [#sn]([parentGuid],[item])
	SELECT [sn],[sn].[Guid],biguid,biNumber
	FROM
	(SELECT parentGuid,biguid, Number as biNumber,item
	FROM
	#sn snt
	INNER JOIN  #BI  bi ON BI.gUID = BIgUID) s
	INNER JOIN SNC000 SN ON SN.GUID = S.parentGuid 
	ORDER BY [biNumber],[item]
###########################################
CREATE PROCEDURE prcInsertIntoSN
	@buGuid UNIQUEIDENTIFIER,
	--@bTGuid UNIQUEIDENTIFIER,
	@Guid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	CREATE TABLE #TEMPSN (ID INT, [GUID] [UNIQUEIDENTIFIER], SN NVARCHAR(100)  COLLATE ARABIC_CI_AI, MatGUID [UNIQUEIDENTIFIER], stGuid [UNIQUEIDENTIFIER], biGuid [UNIQUEIDENTIFIER])
	CREATE TABLE #Sn (ID INT, [GUID] [UNIQUEIDENTIFIER], SN NVARCHAR(100) COLLATE ARABIC_CI_AI , MatGUID [UNIQUEIDENTIFIER], stGuid [UNIQUEIDENTIFIER], biGuid [UNIQUEIDENTIFIER],
						SNguid [UNIQUEIDENTIFIER], FLAG NVARCHAR(100) COLLATE ARABIC_CI_AI)
	CREATE TABLE #V (G [UNIQUEIDENTIFIER], MATGUID [UNIQUEIDENTIFIER], SN NVARCHAR(100)  COLLATE ARABIC_CI_AI)
	CREATE TABLE #W ([guid] [UNIQUEIDENTIFIER], biGuid [UNIQUEIDENTIFIER])
	CREATE TABLE #Q (BIGUID [UNIQUEIDENTIFIER], [stGuid] [UNIQUEIDENTIFIER], SNguid [UNIQUEIDENTIFIER], ID INT)
			 
	INSERT INTO #TEMPSN SELECT ID, [GUID], SN, MatGUID, stGuid, biGuid FROM TEMPSN [t] WHERE [t].[Guid] = @Guid  ORDER BY [SN],[MatGuid]
	INSERT INTO #sn SELECT t.ID, t.[GUID], t.SN, t.MatGUID, t.stGuid, t.biGuid, ISNULL(c.guid,0X00) AS [SNguid],isnull( C.sn,N'') AS FLAG 
	FROM #TEMPSN [t] LEFT JOIN SNC000 C ON [c].[SN] = [t].[SN] and [c].[MatGuid] = [t].[MatGuid]
	INSERT INTO #V SELECT NEWID() G,MATGUID,SN FROM (SELECT MATGUID,SN FROM #Sn WHERE  FLAG = '' GROUP BY MATGUID,SN)E
	UPDATE sn SET [SNguid] = G FROM #Sn SN INNER JOIN 
	 #V V
	ON V.MATGUID = sn.matguid AND v.SN = SN.SN 
	--WHERE [t].[Guid] = @Guid
	IF EXISTS(SELECT * FROM #TEMPSN A LEFT JOIN (select k.Guid from  BI000 k inner join mt000 km on k.MatGuid = km.Guid where ParentGuid = @buGuid AND km.SNFlag > 0 )b ON A.biGuid = b.Guid WHERE  b.Guid IS NULL)
	BEGIN
			
		INSERT INTO #W 
		SELECT a.guid,biGuid 
		FROM
		(SELECT v.guid,V.MatGuid, Qnt,storeGuid  FROM (select k.guid,k.MatGuid,(k.qty + k.BonusQnt) Qnt,storeGuid from  BI000 k inner join mt000 km on k.MatGuid = km.Guid where ParentGuid = @buGuid AND km.SNFlag > 0) v LEFT JOIN #TEMPSN w ON  biGuid = v.Guid WHERE biGuid IS NULL ) a
		INNER JOIN 
		(SELECT biGuid,v.MatGuid,StGuid,COUNT(*) cnt
		 FROM #TEMPSN v LEFT JOIN (select k.guid from  BI000 k inner join mt000 km on k.MatGuid = km.Guid where ParentGuid = @buGuid AND km.SNFlag > 0) w ON v.biGuid = w.Guid WHERE  w.Guid IS NULL
		 GROUP BY biGuid,v.MatGuid,StGuid ) AS b
		 ON a.MatGuid = b.MatGuid AND StoreGuid = StGuid AND Qnt = cnt
		IF NOT EXISTS (SELECT GUID FROM #W GROUP BY GUID HAVING COUNT(*) > 1)
			UPDATE A SET biGuid = w.Guid FROM #TEMPSN A INNER JOIN #w w ON w.biGuid = a.biguid
		ELSE
			INSERT INTO [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0144: Error in inserting SN.'
	END  
	INSERT INTO [dbo].[SNC000]([GUID],[SN],[MatGUID]) SELECT DISTINCT [SNguid],[SN],MatGUID FROM #Sn WHERE FLAG = ''
	INSERT INTO #Q SELECT BIGUID,[stGuid],SNguid,MIN(ID) ID FROM #Sn GROUP BY BIGUID,[stGuid],SNguid
	
	INSERT INTO SNT000(GUID,Item,biGUID,stGUID,ParentGUID,buguid) SELECT NEWID(),ID,BIGUID,[stGuid],[T].SNguid,@buGuid FROM #Q [T] 
	DELETE [tempsn] WHERE [Guid] = @Guid
###########################################
CREATE TRIGGER trg_snt_CheckConstraints 
	ON [snt000] FOR  DELETE, UPDATE 
	NOT FOR REPLICATION
AS
	IF EXISTS(SELECT * FROM DELETED A INNER JOIN [bu000] b ON b.Guid = a.buGuid WHERE b.isposted > 0)
		INSERT INTO [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0002: Can''t delete SN truns in posted bills' 
###########################################
CREATE PROCEDURE prcModifySN
	@OldSn 		[NVARCHAR](256), 
	@NewSn 		[NVARCHAR](256), 
	@MatGUID 	[UNIQUEIDENTIFIER] 
AS 
	SET NOCOUNT ON 
	
	CREATE TABLE [#NSN] ([MatGuid] [UNIQUEIDENTIFIER], [snGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#OSN] ([MatGuid] [UNIQUEIDENTIFIER] ,[snGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE #sn ([SnGuid] [UNIQUEIDENTIFIER], [NEWSNGUID] [UNIQUEIDENTIFIER], [MatGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#R] ([Cnt] INT)
						  
	INSERT INTO [#NSN] SELECT  [MatGuid],[s].[Guid] [snGuid] 
	FROM [snc000] [s] 
		WHERE [SN] = @NewSn  AND ( @MatGUID = 0x0 	OR 		@MatGUID = [MatGUID])  	 
	GROUP BY [MatGuid],[s].[Guid] 
	 
	INSERT INTO [#OSN] SELECT  [MatGuid],[s].[Guid] [snGuid] 
	FROM [snc000] [s] 
		WHERE [SN] = @OldSn  AND ( @MatGUID = 0x0 	OR 		@MatGUID = [MatGUID])  	 
	GROUP BY [MatGuid],[s].[Guid] 
	
	INSERT INTO #sn SELECT [o].[SnGuid],ISNULL([N].[SnGuid],0x00) AS [NEWSNGUID] ,[O].[MatGuid]
	FROM [#oSN] [O] LEFT JOIN  [#NSN] [N] ON  [O].[MatGuid] = [n].[MatGuid] 

	--@CNT duplicate flag, @CNT2 count flag
	DECLARE @CNT [INT] = 0
			,@CNT2 [INT]

	IF EXISTS(SELECT * FROM #sn AS [sn] WHERE [NEWSNGUID] <> 0X00) 
	BEGIN
		SET @CNT = 1
		DELETE FROM  #sn WHERE [NEWSNGUID] <> 0X00
	END
		
	BEGIN TRAN 
	IF EXISTS(SELECT * FROM #sn AS [sn] WHERE [NEWSNGUID] = 0X00) 
	BEGIN  
		INSERT INTO snc000(sn,matguid) SELECT @NewSn,MATGUID 
			FROM  #sn
		WHERE [NEWSNGUID] = 0X00 
		IF @@ERROR <> 0 
		BEGIN 
			ROLLBACK TRAN 
			RETURN 
		END 
		UPDATE S SET [NEWSNGUID] = B.GUID
			FROM #sn S INNER JOIN (SELECT [GUID],MATGUID FROM snc000 WHERE SN = @NewSn) B ON B.MATGUID = S.MATGUID 
		IF @@ERROR <> 0 
		BEGIN 
			ROLLBACK TRAN 
			RETURN 
		END 
	END 
	 EXEC prcDisableTriggers 'SNT000'
	
		UPDATE [SNT] set [parentGuid] = [NEWSNGUID] 
			FROM [SNT000] [SNT] INNER JOIN  [#SN] [SN] on [SN].[SnGuid] = [SNT].[parentGuid]  
		WHERE [NEWSNGUID] <> 0X00  
		
		IF @@ERROR <> 0 
		BEGIN 
			ROLLBACK TRAN 
			RETURN 
		END 
	
		DELETE [SNc]
			FROM [SNc000] [SNc] INNER JOIN  [#SN] [SN] on [SN].[SnGuid] = [SNc].[Guid]  
		WHERE [NEWSNGUID] <> 0X00  
		
		SET @CNT2 = @@ROWCOUNT
	
		UPDATE [SNc] set sn = @NewSn 
			FROM [SNc000] [SNc] INNER JOIN  [#SN] [SN] on [SN].[SnGuid] = [SNc].[Guid]  
		WHERE [NEWSNGUID] = 0x00
			AND NOT EXISTS(SELECT * FROM snc000 V WHERE [SNc].MatGUID = V.MatGUID AND V.SN = @NewSn) 
	    UPDATE [ad000] set [SN] = @NewSn WHERE [SN] = @OldSn AND ([ParentGUID] = (SELECT [GUID] FROM [as000] where [ParentGUID]= @MatGUID)) 
		UPDATE [ad000] set [SnGuid] = [NEWSNGUID] from [#SN] [SN] where [SN].[SnGuid] = [ad000].[SnGuid]
		SET @CNT2 = @CNT2 + @@ROWCOUNT 
		
		INSERT INTO [#R]  SELECT @CNT2
		
		IF @CNT > 0 
			INSERT INTO [#R] VALUES (-1) 
		
		SELECT * FROM [#R] ORDER BY [Cnt] DESC 
	ALTER TABLE SNT000 ENABLE TRIGGER ALL 
	
	IF @@ERROR <> 0 
		ROLLBACK TRAN 
	ELSE 
		COMMIT TRAN 
/* 
  [prcModifySN] '#34343434', '##34343434', '00000000-0000-0000-0000-000000000000' 
*/ 
		
###############################################################
#END
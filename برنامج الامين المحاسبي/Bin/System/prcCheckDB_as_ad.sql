###########################################################################
CREATE PROCEDURE prcCheckDB_as_ad
	@Correct [INT] = 0
AS
	-- check ad, ad not found in sn000
	IF @Correct <> 1 
			INSERT INTO [ErrorLog]([Type], [c1], [g1])
			SELECT 0xe, [ad].[SN], [ad].[ParentGuid]
			FROM
				[ad000] AS [ad] LEFT JOIN [snc000] AS [sn] ON [ad].[SnGuid] = [sn].[Guid] 
			WHERE
				 ( ISNULL( [sn].[Guid], 0x0) = 0x0 OR [Sn].[Qty] = 0 )
				  AND [ad].[Guid] NOT IN (
						SELECT ad.Guid FROM ad000 ad
						LEFT JOIN assetexcludedetails000 aed ON aed.adGuid = ad.Guid
						LEFT JOIN ax000 ax ON ax.adGuid = ad.guid
						LEFT JOIN dd000 dd ON dd.adGuid = ad.guid
						LEFT JOIN assTransferDetails000 atd ON atd.adGuid = ad.guid
						WHERE   ISNULL(aed.Guid, 0x0) <> 0x0
								OR ISNULL(ax.Guid, 0x0) <> 0x0
								OR ISNULL(dd.Guid, 0x0) <> 0x0
								OR ISNULL(atd.Guid, 0x0) <> 0x0
					)

			INSERT INTO [ErrorLog]([Type], [c1], [g1]) 
			SELECT 0x00e0, [ad].[SN], [ad].[Guid] 
			FROM 
				[ad000] AS [ad] LEFT JOIN [snc000] AS [sn] ON [ad].[SnGuid] = [sn].[Guid]  
			WHERE 
			  ( ISNULL( [sn].[Guid], 0x0) = 0x0 OR [Sn].[Qty] = 0 )
			  AND [ad].[Guid]  IN (
					SELECT ad.Guid FROM ad000 ad
					LEFT JOIN assetexcludedetails000 aed ON aed.adGuid = ad.Guid
					LEFT JOIN ax000 ax ON ax.adGuid = ad.guid
					LEFT JOIN dd000 dd ON dd.adGuid = ad.guid
					LEFT JOIN assTransferDetails000 atd ON atd.adGuid = ad.guid
					WHERE     (ISNULL(aed.Guid, 0x0) = 0x0  AND ISNULL(ax.Guid, 0x0) <> 0x0)
							OR (ISNULL(aed.Guid, 0x0) = 0x0  AND ISNULL(dd.Guid, 0x0) <> 0x0)
							OR (ISNULL(aed.Guid, 0x0) = 0x0  AND ISNULL(atd.Guid, 0x0) <> 0x0)
				)

			INSERT INTO [ErrorLog]([Type], [c1], [g1]) 
			SELECT 0x00e1, [ad].[SN], [ad].[Guid] 
			FROM 
				[ad000] AS [ad] LEFT JOIN [snc000] AS [sn] ON [ad].[SnGuid] = [sn].[Guid]  
			WHERE 
			 [Sn].[Qty] < 0 

	-- correct by deleting 
	IF @Correct <> 0 
	BEGIN  
		--EXEC prcBill_Repost 
		DELETE [ad000]  
		FROM [ad000] [ad] LEFT JOIN [snc000] AS [sn] ON [ad].[SNGuid] = [sn].[Guid] 
		WHERE ( ISNULL( [sn].[Guid], 0x0) = 0x0 OR [Sn].[Qty] = 0 )
			  AND [ad].[Guid] NOT IN (
					SELECT ad.Guid FROM ad000 ad
					LEFT JOIN assetexcludedetails000 aed ON aed.adGuid = ad.Guid
					LEFT JOIN ax000 ax ON ax.adGuid = ad.guid
					LEFT JOIN dd000 dd ON dd.adGuid = ad.guid
					LEFT JOIN assTransferDetails000 atd ON atd.adGuid = ad.guid
					WHERE   ISNULL(aed.Guid, 0x0) <> 0x0
							OR ISNULL(ax.Guid, 0x0) <> 0x0
							OR ISNULL(dd.Guid, 0x0) <> 0x0
							OR ISNULL(atd.Guid, 0x0) <> 0x0
				)
	END
###########################################################################
#END
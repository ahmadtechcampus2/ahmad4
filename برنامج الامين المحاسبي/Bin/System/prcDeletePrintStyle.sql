CREATE PROCEDURE prcDeletePrintStyle( @StyleGuid uniqueidentifier)
AS
	-- Delete fonts
	BEGIN TRANSACTION
		DELETE 
			[fn000]
		WHERE 
			[fn000].[Guid] IN (
				SELECT 
					[FontGuid] 
				FROM 
					[prh000] AS [prh] 
				INNER JOIN 
					[prs000] AS [prs] ON [prh].[ParentGUID] = [prs].[GUID]
				WHERE
					[prs].[GUID] = @StyleGuid)
		-- Delete prh
		DELETE 
			[prh000]
		WHERE
			[prh000].[ParentGUID] = @StyleGuid

		-- Delete prs
		DELETE 
			[prs000] 
		WHERE
			[prs000].[Guid] = @StyleGuid
	COMMIT TRANSACTION
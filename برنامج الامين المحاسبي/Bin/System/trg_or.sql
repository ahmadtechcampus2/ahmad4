#########################################################
CREATE TRIGGER trg_or000_delete
	ON [or000] FOR DELETE 
	NOT FOR REPLICATION 
AS  
/*  
This trigger:  
	- deletes or000 related records: oi, och, ocur, billRel, er
*/  
	IF @@ROWCOUNT = 0  
		RETURN  

	-- deleting related data:  
	DELETE [oi000] FROM [oi000] [x] INNER JOIN [deleted] [d] ON [x].[Parent] = [d].[GUID]

	-- delete related checks:
	DELETE [och000] FROM [och000] [x] inner join [deleted] [d] on [x].[parentGuid] = [d].[guid]

	-- deleting related currencies records:
	DELETE [ocur000] FROM [ocur000] [x] inner join [deleted] [d] on [x].[parentGuid] = [d].[guid]

	-- delete bills generated of or and del relation Between or and bu	 	 
	delete [billRel000] from [billRel000] [x] inner join [deleted] [d] on [x].[parentGuid] = [d].[guid]

	-- delete related Discount Card:
	DELETE [DiscRel000] FROM [DiscRel000] [x] inner join [deleted] [d] on [x].[BillGuid] = [d].[guid]

	-- delete related direct entries: 
	delete [er000] from [er000] [x] inner join [deleted] [d] on [x].[parentGuid] = [d].[guid]

	-- delete related checks
	delete [ch000] from [ch000] [ch] inner join [deleted] [d] on [ch].[ParentGuid] = [d].[guid]

#########################################################
#END
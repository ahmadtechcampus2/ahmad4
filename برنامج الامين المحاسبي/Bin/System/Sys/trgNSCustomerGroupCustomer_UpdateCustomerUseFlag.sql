################################################################################
CREATE TRIGGER trg_NSCustomerGroupCustomer000_UpdateCustomerUseFlag
	ON [dbo].[NSCustomerGroupCustomer000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS

	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON
	
		IF EXISTS(SELECT * FROM [deleted])
		BEGIN
			UPDATE [cu000] SET [NSEmailUse] = [NSEmailUse] - 1 FROM [cu000] AS [c] INNER JOIN [deleted] AS [d] ON [c].[GUID] = [d].[CustomerGuid] INNER JOIN [NSCustomerGroup000] cu ON [cu].[GUID] = [d].[CustomerGroupGuid]
			UPDATE [cu000] SET [NSSmsUse] = [NSSmsUse] - 1 FROM [cu000] AS [c] INNER JOIN [deleted] AS [d] ON [c].[GUID] = [d].[CustomerGuid] INNER JOIN [NSCustomerGroup000] cu ON [cu].[GUID] = [d].[CustomerGroupGuid]
		END

		IF EXISTS(SELECT * FROM [inserted])
		BEGIN
			UPDATE [cu000] SET [NSEmailUse] = [NSEmailUse] + 1 FROM [cu000] AS [c] INNER JOIN [inserted] AS [i] ON [c].[GUID] = [i].[CustomerGuid] INNER JOIN [NSCustomerGroup000] cu ON [cu].[GUID] = [i].[CustomerGroupGuid]
			UPDATE [cu000] SET [NSSmsUse] = [NSSmsUse] + 1 FROM [cu000] AS [c] INNER JOIN [inserted] AS [i] ON [c].[GUID] = [i].[CustomerGuid] INNER JOIN [NSCustomerGroup000] cu ON [cu].[GUID] = [i].[CustomerGroupGuid]
		END
################################################################################
#END

##########################################################
CREATE VIEW vwReceivedUserMessageDetails
AS
	SELECT
		[MessageReceiver].[GUID] AS [MessageGUID],
		[ReceiverGUID],
		[SenderGuid],
		[MessageSender].[GUID] AS [ParentGUID],
		[Subject],
		[Body],
		[SendTime],
		[Priority],
		[MessageSender].[Status] AS [SenderStatus],
		[ContentType],
		[MessageSender].[Flag] AS [SenderFlag],
		[MessageReceiver].[Flag] AS [ReceiverFlag],
		[IsReplied],
		[ReplyTime],
		[MessageReceiver].[State] AS [RecieverState],
		[IsForwarded],
		[ForwardTime],
		[IsDeleted],
		[DeleteTime],
		[IsCompleted],
		[CompletionTime],
		[us].[LoginName]
	FROM
		[sentUserMessage000] [MessageSender]
		INNER JOIN [ReceivedUserMessage000] [MessageReceiver] ON [MessageSender].[GUID] = [MessageReceiver].[ParentGUID]
		INNER JOIN [us000] [us] ON [MessageSender].[SenderGuid] = [us].[GUID]
	WHERE
		[MessageReceiver].[ReceiverGUID] =  [dbo].fnGetCurrentUserGUID()
##############################
#END

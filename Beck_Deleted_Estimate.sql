SELECT [Estimates].[Key] AS 'EstimateKey', [Estimates].[EstimateName], [EstimateContainers].[LastUpdateDatetime] AS 'DeletedDateTime', [EstimateContainers].[LastUpdatedBy] AS 'DeletedBy'
FROM [EstimateContainers] INNER JOIN [Estimates] ON [EstimateContainers].[EstimateKey] = [Estimates].[Key]
WHERE [EstimateContainers].[IsDeleted] = 1

DECLARE @EstimateName VARCHAR(100)= 'Demo_Conceptual';
UPDATE dbo.EstimateContainers
SET
IsDeleted = 0
WHERE [Key] IN
(SELECT ec.[Key]
FROM dbo.EstimateContainers ec
JOIN dbo.estimates e ON e.[key] = ec.EstimateKey
WHERE estimatename = @EstimateName
AND ec.IsDeleted = 1)

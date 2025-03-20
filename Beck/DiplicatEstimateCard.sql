SELECT EstimateContainers.[Key]
      ,Estimates.EstimateName
      ,EstimateVersions.VersionName
      ,[EstimateKey]
      ,[VersionKey]
      ,[ParentEstimateContainer]
      ,[RootEstimateContainer]
      ,[QTOManagerKey]
  FROM [EstimateContainers]
  INNER JOIN EstimateVersions ON EstimateContainers.VersionKey = EstimateVersions.[Key]
  INNER JOIN Estimates ON EstimateContainers.EstimateKey = Estimates.[Key]
  WHERE ParentEstimateContainer is NULL
  and RootEstimateContainer is not NULL

Update EstimateContainers
Set ParentEstimateContainer = RootEstimateContainer
WHERE ParentEstimateContainer is NULL
AND
RootEstimateContainer is NOT NULL
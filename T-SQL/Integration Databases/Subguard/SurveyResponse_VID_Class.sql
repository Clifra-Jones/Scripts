/* Replacement Views */

With SurveyResponse as (
    SELECT     
        COALESCE(P.P_ParentVID, R.JDEVendorID) AS JDEVendorID,
        CAST(V.Response AS INT) AS Response,
        V.Class 
    FROM     
        dbo.ProjectSurveyResponse AS R 
    INNER JOIN     
        dbo.ProjectSurveyQuestions AS Q    
    ON Q.QuestionVersion = R.QuestionVersion 
    CROSS APPLY     
        (VALUES
            (Ans01, Q01Class),
            (Ans02, Q02Class),        
            (Ans03, Q03Class),        
            (Ans04, Q04Class),        
            (Ans05, Q05Class),        
            (Ans06, Q06Class),        
            (Ans07, Q07Class),        
            (Ans08, Q08Class),        
            (Ans09, Q09Class),        
            (Ans10, Q10Class)
        ) AS V(Response, Class)
    LEFT JOIN     
        dbo.ParentVendorID AS P   
        ON R.JDEVendorID = P.P_VID 
        WHERE     ISNULL(V.Response, 0) > 0 
),
SurveyResponseAggregate AS (
    SELECT JDEVendorID,
        Class,
        AVG(CAST(Response as DECIMAL(4,2))) as AVGResponse,
        COUNT(*) as ClassCount
    FROM SurveyResponse
    GROUP By JDEVendorID, Class
)
SELECT 
    JDEVendorID,
    COALESCE(MAX(CASE WHEN Class = 'Q' THEN AvgResponse END), 0) AS Quality,
    COALESCE(MAX(CASE WHEN Class = 'C' THEN AvgResponse END), 0) AS Contract,
    COALESCE(MAX(CASE WHEN Class = 'H' THEN AvgResponse END), 0) AS Schedule,
    COALESCE(MAX(CASE WHEN Class = 'S' THEN AvgResponse END), 0) AS Safety,
    COALESCE(AVG(ISNULL(AvgResponse,0)), 0) AS Overall,
    SUM(ISNULL(ClassCount,0)) AS CNT
FROM SurveyResponseAggregate
GROUP BY JDEVendorID
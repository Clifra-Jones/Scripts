select TransferID from PRDocs Where Doctype != 'CostEvent' 
    and (
            DocNumber + '|' + ProjectNumber  + '|' + DocType  + '|' + IsNull(ContractNumber,'') ) 
            = Concat(" + Quote(DocNumber) + " ,'|'," + Quote(ProjectNumber) + ",'|'," + Quote(DocType) + ",'|'," +   Quote(If(IsNull(ContractNumber),"",ContractNumber)) + "
        ) 
 and TransactionStatus Not in ('FAIL','FAILALL','POSTED','DUPLICATE')  
 and TransferID != " + Quote(TransferID) "

 SELECT TransferID
 FROM PRDOCS
 WHERE DocType != 'CostEvent'
    AND (
            DocNumber = " + Quote(DocNumber) + "
            AND
            ProjectNumber = " + Quote(ProjectNumber) + "
            AND
            DocType = " + Quote(DocType) + "
            AND 
            (
                ContractNumber = " + Quote(ContractNumber)"
                OR
                (
                    ContractNumber IS NULL AND " + Quote(ContractNumber) + " IS NULL
                )
            )
    )
    AND TransactionStatus NOT IN ('FAIL','FAILALL','POSTED','DUPLICATE') 
    AND TransferID != " + Quote(TransferID) "

    
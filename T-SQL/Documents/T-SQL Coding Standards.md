# T-SQL Coding Standards

The following coding standards should be used for all T-SQL Scripts in Balfour Beatty US.

## Keywords
Keywords should be in all upper case.
Example:

```SQL
SELECT
    Name,
    Address,
    City,
    State.
    ZIP
FROM Customers
```

## Data Definition Names

Data definition names such as table names and column names should match the case of the original definition.

Schema identifiers are only required if the schema is not 'dbo'.

## Formatting

Indentation should be used with all statements. The indent can be 2 or 4 characters.

Column names should be indented under SELECT placed 1 per line with the comma after the column name, The 1st column should be on the line below SELECT. Optionally the first column can be on the same line as SELECT, but this is not preferred.

### Conditional Statements

***IF...ELSE***
The boolean expression for the IF keyword should be on the same line as the IF keyword. Complex logical conditions can be placed on additional lines and indented for readability.

Statements for the TRUE state should be indented below the IF Keyword.

The ELSE keyword should be on a line by itself.
Statements fot the ELSE condition should be indented.

***CASE***
The CASE keyword should be on a line by itself. Each WHEN keyword should in indented once with the conditional expression on the same line. The THEN keyword indented on the line under WHEN. The END keyword should line up with the CASE keyword.

There are conditions when this can be different. For example if the CASE keyword is part of a function.

Example:

```sql


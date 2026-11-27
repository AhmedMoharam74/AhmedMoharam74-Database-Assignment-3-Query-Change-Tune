/*
DATABASE ASSIGNMENT 3 — QUERY, CHANGE & TUNE DATA
LmsTrainingLab | Ahmed Moharam

IMPORTANT:
1) The PDF says: NO JOIN anywhere in your answers.
2) Task 5 also forbids subqueries and requires one table per query.
3) Table/column names not explicitly specified in the PDF are assumptions.
   Verify them against your own LmsTrainingLab before execution.
4) Tasks 6–9 require actual execution plans, STATISTICS IO/TIME and screenshots.
   No measurements or screenshots are fabricated in this script.
*/

USE LmsTrainingLab;
GO

/* TASK 1 — Finance meeting: session-only overdue invoice list */
IF OBJECT_ID('tempdb..#OverdueInvoices') IS NOT NULL DROP TABLE #OverdueInvoices;
SELECT Id AS InvoiceId, InvoiceNumber, StudentId, TotalAmount, PaidAmount,
       TotalAmount-PaidAmount AS RemainingAmount,
       DATEDIFF(DAY, DueAtUtc, SYSUTCDATETIME()) AS DaysLate,
       CASE WHEN DATEDIFF(DAY, DueAtUtc, SYSUTCDATETIME()) > 60
                  OR TotalAmount-PaidAmount > 10000 THEN 'Urgent'
            WHEN DATEDIFF(DAY, DueAtUtc, SYSUTCDATETIME()) > 30 THEN 'Medium'
            ELSE 'Low' END AS Priority
INTO #OverdueInvoices
FROM finance.Invoices
WHERE DueAtUtc < SYSUTCDATETIME() AND PaidAmount < TotalAmount;
SELECT * FROM #OverdueInvoices
ORDER BY CASE Priority WHEN 'Urgent' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END,
         RemainingAmount DESC;
GO

/* TASK 2 — New department */
IF NOT EXISTS (SELECT 1 FROM academics.Departments WHERE DepartmentCode='DSAI')
    INSERT academics.Departments(DepartmentCode,DepartmentName)
    VALUES('DSAI',N'Data Science & Artificial Intelligence');
GO
IF NOT EXISTS (SELECT 1 FROM academics.Courses WHERE CourseCode='DSAI-101')
    INSERT academics.Courses(DepartmentId,CourseCode,CourseTitle,CreditHours,PassMark,IsActive)
    SELECT Id,'DSAI-101',N'Introduction to Data Analysis',3,60,1
    FROM academics.Departments WHERE DepartmentCode='DSAI';
GO
IF NOT EXISTS (SELECT 1 FROM academics.Terms WHERE TermName='Summer 2027')
    INSERT academics.Terms(TermName,ClassStartDate,ClassEndDate,RegistrationStartDate,RegistrationEndDate)
    VALUES('Summer 2027','2027-06-15','2027-08-31','2027-05-01','2027-06-10');
GO
INSERT communications.Announcements(Title,Body,Audience,CreatedAtUtc,IsPublished)
VALUES(N'Summer 2027 Registration',N'Registration opens on 1 May 2027.','All Students',SYSUTCDATETIME(),1);
GO
IF NOT EXISTS (SELECT 1 FROM identity.Roles WHERE RoleName='Teaching Assistant')
    INSERT identity.Roles(RoleName) VALUES('Teaching Assistant');
GO

/* TASK 3 — Sequence-based invoice numbers */
IF OBJECT_ID('finance.InvoiceNumberSequence','SO') IS NULL
    EXEC('CREATE SEQUENCE finance.InvoiceNumberSequence AS BIGINT START WITH 1 INCREMENT BY 1;');
GO
DECLARE @StudentId BIGINT, @InvoiceNo NVARCHAR(40);
SELECT TOP(1) @StudentId=Id FROM identity.StudentProfiles ORDER BY Id;
IF @StudentId IS NULL THROW 50001,'No existing student profile found.',1;
SET @InvoiceNo='LAB-INV-2026-'+RIGHT('000000'+CONVERT(VARCHAR(20),NEXT VALUE FOR finance.InvoiceNumberSequence),6);
INSERT finance.Invoices(InvoiceNumber,StudentId,TotalAmount,PaidAmount,Currency,DueAtUtc)
VALUES(@InvoiceNo,@StudentId,4500,0,'EGP',DATEADD(DAY,30,SYSUTCDATETIME()));
SELECT @InvoiceNo AS CreatedInvoiceNumber;
GO
BEGIN TRANSACTION;
SELECT NEXT VALUE FOR finance.InvoiceNumberSequence AS ConsumedNumber;
ROLLBACK TRANSACTION;
SELECT NEXT VALUE FOR finance.InvoiceNumberSequence AS NextNumber;
GO

/* TASK 4 — Copy sections from the latest term to Summer 2027 */
DECLARE @SummerId BIGINT,@LatestId BIGINT;
SELECT @SummerId=Id FROM academics.Terms WHERE TermName='Summer 2027';
SELECT TOP(1) @LatestId=Id FROM academics.Terms WHERE Id<>@SummerId ORDER BY ClassEndDate DESC;
INSERT academics.Sections(TermId,CourseId,SectionNumber,InstructorId,Capacity,Location)
SELECT @SummerId,CourseId,SectionNumber,InstructorId,Capacity,Location
FROM academics.Sections WHERE TermId=@LatestId;
SELECT * FROM academics.Sections WHERE TermId=@SummerId;
GO

/* TASK 5 — Management reports (one table per query; no subqueries) */
-- 5.1
SELECT CourseCode AS [Course Code],CourseTitle AS [Course Title],CreditHours AS [Credit Hours]
FROM academics.Courses ORDER BY CreditHours DESC,CourseTitle;
GO
-- 5.2
SELECT TOP(5) Id,FirstName,LastName,Email FROM identity.Users ORDER BY NEWID();
GO
-- 5.3 DATALENGTH detects trailing spaces that LEN ignores.
SELECT Id,Email FROM identity.Users
WHERE DATALENGTH(Email)<>DATALENGTH(LTRIM(RTRIM(Email)));
GO
-- 5.4
SELECT Id,Email FROM identity.Users
WHERE Email COLLATE Latin1_General_100_BIN2<>LOWER(Email) COLLATE Latin1_General_100_BIN2;
GO
-- 5.5
SELECT Id,Email FROM identity.Users
WHERE Email NOT LIKE '%@%' OR Email LIKE '@%' OR Email NOT LIKE '%@%.%';
GO
-- 5.6
SELECT DISTINCT SUBSTRING(Email,CHARINDEX('@',Email)+1,320) AS EmailProvider
FROM identity.Users WHERE Email LIKE '%@%' ORDER BY EmailProvider;
GO
-- 5.7
SELECT Id,FirstName,LastName,Email,LastLoginAtUtc FROM identity.Users
ORDER BY CASE WHEN LastLoginAtUtc IS NULL THEN 1 ELSE 0 END,LastLoginAtUtc DESC;
GO
-- 5.8
SELECT Id,InvoiceId,Amount,PaidAtUtc FROM finance.Payments
WHERE PaidAtUtc>='2026-10-01' AND PaidAtUtc<'2026-11-01';
GO
-- 5.9 Assumes PaidAtUtc is UTC.
SELECT Id,PaidAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Egypt Standard Time' AS CairoPaymentTime
FROM finance.Payments
WHERE DATEPART(HOUR,PaidAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Egypt Standard Time')<5;
GO
-- 5.10 Friday, independent of SET DATEFIRST.
SELECT Id,SessionDate FROM academics.AttendanceSessions
WHERE DATEDIFF(DAY,CONVERT(date,'19000105'),CONVERT(date,SessionDate))%7=0;
GO
-- 5.11 Egyptian mobile prefixes.
SELECT Id,Phone FROM identity.Users
WHERE REPLACE(REPLACE(Phone,' ',''),'+20','0') LIKE '010%'
   OR REPLACE(REPLACE(Phone,' ',''),'+20','0') LIKE '011%'
   OR REPLACE(REPLACE(Phone,' ',''),'+20','0') LIKE '012%'
   OR REPLACE(REPLACE(Phone,' ',''),'+20','0') LIKE '015%';
GO
-- 5.12
SELECT Id,CASE WHEN Phone IS NULL OR LEN(Phone)<5 THEN NULL
               ELSE LEFT(Phone,3)+REPLICATE('*',LEN(Phone)-5)+RIGHT(Phone,2) END AS MaskedPhone
FROM identity.Users;
GO
-- 5.13
SELECT Id,InvoiceNumber,
       TRY_CONVERT(BIGINT,RIGHT(InvoiceNumber,CHARINDEX('-',REVERSE(InvoiceNumber))-1)) AS RunningNumber
FROM finance.Invoices;
GO
-- 5.14
SELECT Id,CASE WHEN EstimatedDurationMinutes IS NULL THEN 'Not set'
               ELSE CONCAT(EstimatedDurationMinutes/60,' h ',EstimatedDurationMinutes%60,' min') END AS LessonLength
FROM learning.Lessons;
GO
-- 5.15
SELECT Id,Title,Body FROM communications.Announcements
WHERE Title LIKE '%[%]%' OR Body LIKE '%[%]%';
GO
-- 5.16
SELECT TOP(5) WITH TIES Id,InvoiceNumber,TotalAmount FROM finance.Invoices ORDER BY TotalAmount DESC;
GO
-- 5.17
SELECT TOP(10) PERCENT Id,InvoiceId,Amount,PaidAtUtc FROM finance.Payments ORDER BY Amount DESC;
GO
-- 5.18
SELECT Id,TermId,CourseId,SectionNumber,Location FROM academics.Sections
WHERE Location<>'Hall A' OR Location IS NULL;
GO
-- 5.19
SELECT Id,InvoiceNumber,TotalAmount,PaidAmount,TotalAmount-PaidAmount AS Remaining,
       CASE WHEN PaidAmount>0 THEN 'Partially paid' ELSE 'Not paid' END AS PaymentState,
       CASE WHEN DueAtUtc<SYSUTCDATETIME() THEN 'Overdue' ELSE 'Not overdue' END AS DueState,
       CAST(CASE WHEN TotalAmount=0 THEN 0 ELSE PaidAmount*100.0/NULLIF(TotalAmount,0) END AS DECIMAL(6,1)) AS PercentagePaid
FROM finance.Invoices WHERE PaidAmount<TotalAmount ORDER BY TotalAmount-PaidAmount DESC;
GO
-- 5.20
SELECT Id,Email,FirstName,LastName,CreatedAtUtc FROM identity.Users
ORDER BY CreatedAtUtc DESC,Id DESC OFFSET 40 ROWS FETCH NEXT 20 ROWS ONLY;
GO
-- 5.21 Replace 0 with the last displayed audit Id.
DECLARE @LastSeenId BIGINT=0;
SELECT TOP(50) Id FROM operations.AuditLogs WHERE Id>@LastSeenId ORDER BY Id;
GO
-- 5.22
SELECT TOP(10) Id,InvoiceId,Amount,PaidAtUtc FROM finance.Payments ORDER BY PaidAtUtc DESC,Id DESC;
GO
-- 5.23
SELECT TOP(10) UPPER(LTRIM(RTRIM(Title))) AS LessonTitle,
       MAX(LEN(LTRIM(RTRIM(Title)))) AS TitleLength,
       CASE WHEN MAX(EstimatedDurationMinutes) IS NULL THEN 'Not set'
            WHEN MAX(EstimatedDurationMinutes)<=15 THEN 'Quick'
            WHEN MAX(EstimatedDurationMinutes)<=45 THEN 'Standard' ELSE 'Long' END AS DurationCategory
FROM learning.Lessons
WHERE IsPublished=1 AND LEN(LTRIM(RTRIM(Title)))>40
GROUP BY UPPER(LTRIM(RTRIM(Title)))
ORDER BY MAX(LEN(LTRIM(RTRIM(Title)))) DESC;
GO
-- 5.24
SELECT TOP(12) CONVERT(CHAR(7),DueAtUtc,120) AS DueMonth,Currency,
       CASE WHEN PaidAmount>0 THEN 'Partially paid' ELSE 'Not paid' END AS PaymentState,
       COUNT(*) AS InvoiceCount,SUM(TotalAmount-PaidAmount) AS Outstanding
FROM finance.Invoices
WHERE DueAtUtc<SYSUTCDATETIME() AND PaidAmount<TotalAmount
GROUP BY CONVERT(CHAR(7),DueAtUtc,120),Currency,
         CASE WHEN PaidAmount>0 THEN 'Partially paid' ELSE 'Not paid' END
ORDER BY DueMonth DESC,Currency,PaymentState;
GO

/* TASK 6 — Actual execution plan + IO/TIME (capture screenshots yourself) */
-- Expected operators depend on existing indexes, statistics and row counts.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT TOP(15) i.InvoiceNumber,sp.StudentNumber,i.TotalAmount-i.PaidAmount AS Remaining,
       CASE WHEN i.DueAtUtc<DATEADD(DAY,-60,SYSUTCDATETIME()) THEN 'Urgent' ELSE 'Normal' END AS Urgency
FROM finance.Invoices AS i
INNER JOIN identity.StudentProfiles AS sp ON sp.Id=i.StudentId
WHERE i.PaidAmount<i.TotalAmount AND i.DueAtUtc<SYSUTCDATETIME()
ORDER BY Remaining DESC;
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

/* TASK 7 — Production indexes from the assignment (create only if absent) */
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Users_Email' AND object_id=OBJECT_ID('identity.Users'))
    CREATE INDEX IX_Users_Email ON identity.Users(Email) INCLUDE(FirstName,LastName);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Users_LastName' AND object_id=OBJECT_ID('identity.Users'))
    CREATE INDEX IX_Users_LastName ON identity.Users(LastName) INCLUDE(FirstName,Email);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Users_CreatedAtUtc' AND object_id=OBJECT_ID('identity.Users'))
    CREATE INDEX IX_Users_CreatedAtUtc ON identity.Users(CreatedAtUtc) INCLUDE(Email);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Payments_PaidAtUtc' AND object_id=OBJECT_ID('finance.Payments'))
    CREATE INDEX IX_Payments_PaidAtUtc ON finance.Payments(PaidAtUtc) INCLUDE(InvoiceId,Amount);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Invoices_Number' AND object_id=OBJECT_ID('finance.Invoices'))
    CREATE INDEX IX_Invoices_Number ON finance.Invoices(InvoiceNumber);
GO
-- 7.1
SELECT Id,Email FROM identity.Users WHERE CreatedAtUtc>='2026-03-01' AND CreatedAtUtc<'2026-04-01';
GO
-- 7.2
SELECT Id,InvoiceId,Amount FROM finance.Payments WHERE PaidAtUtc>=DATEADD(DAY,-30,SYSUTCDATETIME());
GO
-- 7.3
SELECT Id,FirstName,LastName FROM identity.Users WHERE LastName LIKE N'Abd%';
GO
-- 7.4
SELECT * FROM operations.AuditLogs WHERE Id=50000;
GO
-- 7.5 Match the literal type to InvoiceNumber (assumed varchar).
SELECT Id,TotalAmount,PaidAmount FROM finance.Invoices WHERE InvoiceNumber='LAB-INV-2026-000001';
GO
-- 7.6 If the column/database collation is case-insensitive, UPPER is unnecessary.
DECLARE @Email NVARCHAR(320)=N'example@email.com';
SELECT Id,FirstName,LastName FROM identity.Users WHERE Email=@Email;
GO
-- 7.7
DECLARE @LastName NVARCHAR(100)=N'Hassan';
SELECT Id,FirstName,Email FROM identity.Users
WHERE (@LastName IS NULL OR LastName=@LastName) OPTION(RECOMPILE);
GO
-- 7.8
-- Slow form:
SELECT Id,Email FROM identity.Users WHERE ISNULL(Email,'')='example@email.com';
GO
-- SARGable equivalent:
SELECT Id,Email FROM identity.Users WHERE Email='example@email.com';
GO

/* TASK 8 — Sort spill practice.
   A spill is data/statistics/plan dependent. Capture the actual warning if it occurs;
   do not claim it occurred unless the actual plan shows it. */
IF OBJECT_ID('dbo.SortSpillPractice','U') IS NOT NULL DROP TABLE dbo.SortSpillPractice;
CREATE TABLE dbo.SortSpillPractice
(Id BIGINT IDENTITY PRIMARY KEY,GroupValue INT NOT NULL,SortValue NVARCHAR(200) NOT NULL);
GO
DECLARE @n INT=1;
WHILE @n<=100000
BEGIN
    INSERT dbo.SortSpillPractice(GroupValue,SortValue)
    VALUES(CASE WHEN @n<=99000 THEN 1 ELSE @n END,
           REPLICATE(CHAR(65+(@n%26)),100)+RIGHT('000000'+CONVERT(VARCHAR(6),@n),6));
    SET @n+=1;
END;
GO
SELECT GroupValue,SortValue FROM dbo.SortSpillPractice ORDER BY SortValue DESC;
GO
UPDATE STATISTICS dbo.SortSpillPractice WITH FULLSCAN;
GO
SELECT GroupValue,SortValue FROM dbo.SortSpillPractice ORDER BY SortValue DESC;
GO

/* TASK 9 — DISTINCT */
SELECT DISTINCT SortValue FROM dbo.SortSpillPractice;
GO
SELECT DISTINCT Id FROM dbo.SortSpillPractice;
GO

/* TASK 10 — Numbers vs GUIDs (include in NOTES.md)
INT/BIGINT: compact, efficient indexes/comparisons, sequential and readable;
but may expose approximate counts and need central coordination across systems.
GUID: independently generated across services and useful offline; but 16 bytes,
larger indexes and random inserts can fragment indexes. Choose based on scale,
distribution, privacy, and where IDs are generated.
*/

/* TASK 11 — End of semester changes */
-- 11.1
UPDATE academics.Courses SET PassMark=65
WHERE DepartmentId=(SELECT Id FROM academics.Departments WHERE DepartmentCode='DSAI');
GO
-- 11.2
UPDATE academics.Enrollments
SET LetterGrade=CASE WHEN FinalScore>=90 THEN 'A' WHEN FinalScore>=80 THEN 'B'
                     WHEN FinalScore>=70 THEN 'C' WHEN FinalScore>=60 THEN 'D' ELSE 'F' END
WHERE Status='Finished' AND FinalScore IS NOT NULL;
GO
-- 11.3
DELETE FROM identity.Roles WHERE RoleName='Teaching Assistant';
GO
-- 11.4 Adjust InvoiceId's type to exactly match finance.Payments.InvoiceId.
IF OBJECT_ID('finance.PaymentStaging','U') IS NOT NULL DROP TABLE finance.PaymentStaging;
CREATE TABLE finance.PaymentStaging
(StagingId BIGINT IDENTITY PRIMARY KEY,InvoiceId BIGINT NOT NULL,
 Amount DECIMAL(18,2) NOT NULL,PaidAtUtc DATETIME2(7) NOT NULL);
INSERT finance.PaymentStaging(InvoiceId,Amount,PaidAtUtc)
VALUES(1,100,SYSUTCDATETIME()),(2,250,SYSUTCDATETIME()),(3,500,SYSUTCDATETIME());
TRUNCATE TABLE finance.PaymentStaging;
GO
-- 11.5 Clean up practice tables safely.
IF OBJECT_ID('dbo.SortSpillPractice','U') IS NOT NULL DROP TABLE dbo.SortSpillPractice;
IF OBJECT_ID('finance.PaymentStaging','U') IS NOT NULL DROP TABLE finance.PaymentStaging;
GO

/* TASK 12 — Auditors */
-- 12.1
IF OBJECT_ID('academics.CoursePassMarkHistory','U') IS NULL
CREATE TABLE academics.CoursePassMarkHistory
(HistoryId BIGINT IDENTITY PRIMARY KEY,CourseId BIGINT NOT NULL,
 OldPassMark DECIMAL(5,2),NewPassMark DECIMAL(5,2) NOT NULL,
 ChangedAtUtc DATETIME2(7) NOT NULL,ChangedBy SYSNAME NOT NULL);
GO
DECLARE @ChangedBy SYSNAME=SUSER_SNAME();
UPDATE academics.Courses
SET PassMark=66
OUTPUT inserted.Id,deleted.PassMark,inserted.PassMark,SYSUTCDATETIME(),@ChangedBy
INTO academics.CoursePassMarkHistory(CourseId,OldPassMark,NewPassMark,ChangedAtUtc,ChangedBy)
WHERE DepartmentId=(SELECT Id FROM academics.Departments WHERE DepartmentCode='DSAI');
GO
-- 12.2 DELETE...OUTPUT archives deleted rows in one statement.
IF OBJECT_ID('communications.AnnouncementsArchive','U') IS NULL
    SELECT TOP(0) * INTO communications.AnnouncementsArchive FROM communications.Announcements;
GO
DELETE FROM communications.Announcements
OUTPUT deleted.* INTO communications.AnnouncementsArchive
WHERE ExpiresAtUtc<DATEADD(MONTH,-6,SYSUTCDATETIME());
GO

/* TASK 13 — Nightly website catalog sync */
IF SCHEMA_ID('website') IS NULL EXEC('CREATE SCHEMA website');
GO
IF OBJECT_ID('website.CourseCatalog','U') IS NULL
CREATE TABLE website.CourseCatalog
(CourseId BIGINT PRIMARY KEY,CourseCode NVARCHAR(50) NOT NULL,
 CourseTitle NVARCHAR(250) NOT NULL,CreditHours INT NOT NULL,
 IsVisible BIT NOT NULL,LastSyncedAtUtc DATETIME2(7) NOT NULL);
GO
MERGE website.CourseCatalog AS target
USING (SELECT Id,CourseCode,CourseTitle,CreditHours,IsActive FROM academics.Courses) AS source
ON target.CourseId=source.Id
WHEN MATCHED AND
 (target.CourseCode<>source.CourseCode OR target.CourseTitle<>source.CourseTitle
  OR target.CreditHours<>source.CreditHours OR target.IsVisible<>source.IsActive)
THEN UPDATE SET CourseCode=source.CourseCode,CourseTitle=source.CourseTitle,
                CreditHours=source.CreditHours,IsVisible=source.IsActive,
                LastSyncedAtUtc=SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET AND source.IsActive=1
THEN INSERT(CourseId,CourseCode,CourseTitle,CreditHours,IsVisible,LastSyncedAtUtc)
     VALUES(source.Id,source.CourseCode,source.CourseTitle,source.CreditHours,1,SYSUTCDATETIME())
WHEN NOT MATCHED BY SOURCE AND target.IsVisible=1
THEN UPDATE SET IsVisible=0,LastSyncedAtUtc=SYSUTCDATETIME()
OUTPUT $action AS SyncAction,inserted.CourseId,deleted.CourseCode AS OldCode,
       inserted.CourseCode AS NewCode;
GO
-- Test: rename one source course and deactivate another, then rerun MERGE.
-- Run it a third time without source changes; OUTPUT should return zero rows.
-- Use test data or a transaction and restore the original values afterwards.

/*
NOTES / EVIDENCE STILL REQUIRED:
- Verify all assumed schema and column names against your database.
- Task 6: expected vs actual operators, every operator property, STATISTICS IO/TIME,
  actual plan screenshot, and what differed from your prediction.
- Task 7: before/after actual plans and logical reads for 7.1–7.8.
- Task 8: screenshot an actual sort spill warning and its properties. This sample
  does not guarantee a spill; a genuine cardinality-estimation mismatch is required.
- Task 9: explain actual DISTINCT plan operators and Stream Aggregate alternative.
- Task 13: record outputs for the first sync, test changes, second sync, and no-op third sync.
*/

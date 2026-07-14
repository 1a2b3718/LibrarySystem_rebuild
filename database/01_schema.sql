IF DB_ID(N'LibrarySystemDb') IS NULL
BEGIN
    CREATE DATABASE LibrarySystemDb;
END
GO

USE LibrarySystemDb;
GO

IF OBJECT_ID(N'dbo.sp_PayReaderFine', N'P') IS NOT NULL DROP PROCEDURE dbo.sp_PayReaderFine;
IF OBJECT_ID(N'dbo.sp_ReturnBook', N'P') IS NOT NULL DROP PROCEDURE dbo.sp_ReturnBook;
IF OBJECT_ID(N'dbo.sp_BorrowBook', N'P') IS NOT NULL DROP PROCEDURE dbo.sp_BorrowBook;
IF OBJECT_ID(N'dbo.vw_OverdueBorrowRecords', N'V') IS NOT NULL DROP VIEW dbo.vw_OverdueBorrowRecords;
IF OBJECT_ID(N'dbo.BorrowRecords', N'U') IS NOT NULL DROP TABLE dbo.BorrowRecords;
IF OBJECT_ID(N'dbo.Accounts', N'U') IS NOT NULL DROP TABLE dbo.Accounts;
IF OBJECT_ID(N'dbo.Readers', N'U') IS NOT NULL DROP TABLE dbo.Readers;
IF OBJECT_ID(N'dbo.Books', N'U') IS NOT NULL DROP TABLE dbo.Books;
GO

CREATE TABLE dbo.Books
(
    Isbn NVARCHAR(20) NOT NULL,
    Title NVARCHAR(100) NOT NULL,
    Publisher NVARCHAR(100) NOT NULL,
    Author NVARCHAR(100) NOT NULL,
    TotalCopies INT NOT NULL CONSTRAINT DF_Books_TotalCopies DEFAULT 1,
    AvailableCopies INT NOT NULL CONSTRAINT DF_Books_AvailableCopies DEFAULT 1,
    IsBorrowable BIT NOT NULL CONSTRAINT DF_Books_IsBorrowable DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Books_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_Books_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Books PRIMARY KEY (Isbn),
    CONSTRAINT CK_Books_TotalCopies CHECK (TotalCopies >= 0),
    CONSTRAINT CK_Books_AvailableCopies CHECK (AvailableCopies >= 0 AND AvailableCopies <= TotalCopies),
    CONSTRAINT CK_Books_IsBorrowable_Available CHECK (IsBorrowable = 0 OR AvailableCopies > 0),
    CONSTRAINT CK_Books_Isbn_NotBlank CHECK (LEN(LTRIM(RTRIM(Isbn))) > 0),
    CONSTRAINT CK_Books_Title_NotBlank CHECK (LEN(LTRIM(RTRIM(Title))) > 0),
    CONSTRAINT CK_Books_Publisher_NotBlank CHECK (LEN(LTRIM(RTRIM(Publisher))) > 0),
    CONSTRAINT CK_Books_Author_NotBlank CHECK (LEN(LTRIM(RTRIM(Author))) > 0),
    CONSTRAINT CK_Books_UpdatedAt CHECK (UpdatedAt >= CreatedAt)
);
GO

CREATE TABLE dbo.Readers
(
    ReaderCardNo NVARCHAR(30) NOT NULL,
    Name NVARCHAR(50) NOT NULL,
    Gender NVARCHAR(10) NOT NULL CONSTRAINT DF_Readers_Gender DEFAULT N'男',
    Title NVARCHAR(50) NOT NULL CONSTRAINT DF_Readers_Title DEFAULT N'学生',
    MaxBorrowCount INT NOT NULL CONSTRAINT DF_Readers_MaxBorrowCount DEFAULT 5,
    BorrowedCount INT NOT NULL CONSTRAINT DF_Readers_BorrowedCount DEFAULT 0,
    Department NVARCHAR(100) NOT NULL,
    Phone NVARCHAR(30) NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Readers_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_Readers_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Readers PRIMARY KEY (ReaderCardNo),
    CONSTRAINT CK_Readers_Gender CHECK (Gender IN (N'男', N'女', N'其他')),
    CONSTRAINT CK_Readers_MaxBorrowCount CHECK (MaxBorrowCount BETWEEN 0 AND 20),
    CONSTRAINT CK_Readers_BorrowedCount CHECK (BorrowedCount >= 0 AND BorrowedCount <= MaxBorrowCount),
    CONSTRAINT CK_Readers_CardNo_NotBlank CHECK (LEN(LTRIM(RTRIM(ReaderCardNo))) > 0),
    CONSTRAINT CK_Readers_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(Name))) > 0),
    CONSTRAINT CK_Readers_Title_NotBlank CHECK (LEN(LTRIM(RTRIM(Title))) > 0),
    CONSTRAINT CK_Readers_Department_NotBlank CHECK (LEN(LTRIM(RTRIM(Department))) > 0),
    CONSTRAINT CK_Readers_Phone_NotBlank CHECK (Phone IS NULL OR LEN(LTRIM(RTRIM(Phone))) > 0),
    CONSTRAINT CK_Readers_UpdatedAt CHECK (UpdatedAt >= CreatedAt)
);
GO

CREATE TABLE dbo.Accounts
(
    AccountId INT IDENTITY(1,1) NOT NULL,
    Username NVARCHAR(50) NOT NULL,
    PasswordHash CHAR(64) NOT NULL,
    PasswordSalt NVARCHAR(64) NOT NULL CONSTRAINT DF_Accounts_PasswordSalt DEFAULT N'LIBRARY_SYSTEM_2026',
    Role NVARCHAR(20) NOT NULL,
    ReaderCardNo NVARCHAR(30) NULL,
    IsEnabled BIT NOT NULL CONSTRAINT DF_Accounts_IsEnabled DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Accounts_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Accounts PRIMARY KEY (AccountId),
    CONSTRAINT UQ_Accounts_Username UNIQUE (Username),
    CONSTRAINT CK_Accounts_Role CHECK (Role IN (N'Admin', N'Reader')),
    CONSTRAINT FK_Accounts_Readers FOREIGN KEY (ReaderCardNo) REFERENCES dbo.Readers(ReaderCardNo),
    CONSTRAINT CK_Accounts_ReaderRole CHECK ((Role = N'Reader' AND ReaderCardNo IS NOT NULL) OR (Role = N'Admin' AND ReaderCardNo IS NULL)),
    CONSTRAINT CK_Accounts_Username_NotBlank CHECK (LEN(LTRIM(RTRIM(Username))) > 0),
    CONSTRAINT CK_Accounts_PasswordHash_Format CHECK (LEN(PasswordHash) = 64 AND PasswordHash NOT LIKE '%[^0-9A-Fa-f]%'),
    CONSTRAINT CK_Accounts_PasswordSalt_NotBlank CHECK (LEN(LTRIM(RTRIM(PasswordSalt))) > 0)
);
GO

CREATE TABLE dbo.BorrowRecords
(
    LoanId INT IDENTITY(1,1) NOT NULL,
    ReaderCardNo NVARCHAR(30) NOT NULL,
    Isbn NVARCHAR(20) NOT NULL,
    BorrowDate DATE NOT NULL CONSTRAINT DF_BorrowRecords_BorrowDate DEFAULT CAST(GETDATE() AS DATE),
    LoanDays INT NOT NULL CONSTRAINT DF_BorrowRecords_LoanDays DEFAULT 30,
    ReturnDate DATE NULL,
    Fine DECIMAL(10,2) NOT NULL CONSTRAINT DF_BorrowRecords_Fine DEFAULT 0,
    FinePaid BIT NOT NULL CONSTRAINT DF_BorrowRecords_FinePaid DEFAULT 1,
    Remark NVARCHAR(200) NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_BorrowRecords_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_BorrowRecords PRIMARY KEY (LoanId),
    CONSTRAINT FK_BorrowRecords_Readers FOREIGN KEY (ReaderCardNo) REFERENCES dbo.Readers(ReaderCardNo),
    CONSTRAINT FK_BorrowRecords_Books FOREIGN KEY (Isbn) REFERENCES dbo.Books(Isbn),
    CONSTRAINT CK_BorrowRecords_LoanDays CHECK (LoanDays BETWEEN 1 AND 180),
    CONSTRAINT CK_BorrowRecords_Fine CHECK (Fine >= 0),
    CONSTRAINT CK_BorrowRecords_ReturnDate CHECK (ReturnDate IS NULL OR ReturnDate >= BorrowDate),
    CONSTRAINT CK_BorrowRecords_OpenLoanState CHECK (ReturnDate IS NOT NULL OR (Fine = 0 AND FinePaid = 1)),
    CONSTRAINT CK_BorrowRecords_FinePaidConsistency CHECK (Fine > 0 OR FinePaid = 1),
    CONSTRAINT CK_BorrowRecords_ReaderCardNo_NotBlank CHECK (LEN(LTRIM(RTRIM(ReaderCardNo))) > 0),
    CONSTRAINT CK_BorrowRecords_Isbn_NotBlank CHECK (LEN(LTRIM(RTRIM(Isbn))) > 0)
);
GO

CREATE INDEX IX_Books_TitleAuthor ON dbo.Books(Title, Author);
CREATE INDEX IX_Readers_Name ON dbo.Readers(Name);
CREATE UNIQUE INDEX UQ_Accounts_ReaderCardNo ON dbo.Accounts(ReaderCardNo) WHERE ReaderCardNo IS NOT NULL;
CREATE INDEX IX_BorrowRecords_Reader_ReturnDate ON dbo.BorrowRecords(ReaderCardNo, ReturnDate);
CREATE INDEX IX_BorrowRecords_Isbn_ReturnDate ON dbo.BorrowRecords(Isbn, ReturnDate);
GO

CREATE VIEW dbo.vw_OverdueBorrowRecords
AS
SELECT
    br.LoanId,
    br.Isbn,
    b.Title,
    r.Name AS ReaderName,
    r.ReaderCardNo,
    br.BorrowDate,
    DATEADD(DAY, br.LoanDays, br.BorrowDate) AS DueDate,
    DATEDIFF(DAY, DATEADD(DAY, br.LoanDays, br.BorrowDate), CAST(GETDATE() AS DATE)) AS OverdueDays,
    CAST(DATEDIFF(DAY, DATEADD(DAY, br.LoanDays, br.BorrowDate), CAST(GETDATE() AS DATE)) * 0.50 AS DECIMAL(10,2)) AS EstimatedFine
FROM dbo.BorrowRecords br
JOIN dbo.Books b ON b.Isbn = br.Isbn
JOIN dbo.Readers r ON r.ReaderCardNo = br.ReaderCardNo
WHERE br.ReturnDate IS NULL
  AND DATEADD(DAY, br.LoanDays, br.BorrowDate) < CAST(GETDATE() AS DATE);
GO

CREATE PROCEDURE dbo.sp_BorrowBook
    @ReaderCardNo NVARCHAR(30),
    @Isbn NVARCHAR(20),
    @BorrowDate DATE = NULL,
    @LoanDays INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @BorrowDate IS NULL SET @BorrowDate = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.Readers WITH (UPDLOCK, HOLDLOCK) WHERE ReaderCardNo = @ReaderCardNo)
        THROW 51001, N'读者不存在。', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Books WITH (UPDLOCK, HOLDLOCK) WHERE Isbn = @Isbn)
        THROW 51002, N'图书不存在。', 1;

    IF EXISTS (SELECT 1 FROM dbo.BorrowRecords WHERE ReaderCardNo = @ReaderCardNo AND ReturnDate IS NOT NULL AND Fine > 0 AND FinePaid = 0)
        THROW 51003, N'读者存在未缴罚款，不能借书。', 1;

    IF EXISTS (SELECT 1 FROM dbo.Readers WHERE ReaderCardNo = @ReaderCardNo AND BorrowedCount >= MaxBorrowCount)
        THROW 51004, N'读者已达到可借数量上限。', 1;

    IF EXISTS (SELECT 1 FROM dbo.Books WHERE Isbn = @Isbn AND (IsBorrowable = 0 OR AvailableCopies <= 0))
        THROW 51005, N'该图书当前不可借。', 1;

    UPDATE dbo.Books
       SET AvailableCopies = AvailableCopies - 1,
           IsBorrowable = CASE WHEN AvailableCopies - 1 <= 0 THEN 0 ELSE IsBorrowable END,
           UpdatedAt = SYSUTCDATETIME()
     WHERE Isbn = @Isbn;

    UPDATE dbo.Readers
       SET BorrowedCount = BorrowedCount + 1,
           UpdatedAt = SYSUTCDATETIME()
     WHERE ReaderCardNo = @ReaderCardNo;

    INSERT INTO dbo.BorrowRecords (ReaderCardNo, Isbn, BorrowDate, LoanDays, FinePaid)
    VALUES (@ReaderCardNo, @Isbn, @BorrowDate, @LoanDays, 1);

    SELECT SCOPE_IDENTITY() AS LoanId;

    COMMIT TRANSACTION;
END;
GO

CREATE PROCEDURE dbo.sp_ReturnBook
    @LoanId INT,
    @ReturnDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ReturnDate IS NULL SET @ReturnDate = CAST(GETDATE() AS DATE);

    DECLARE @ReaderCardNo NVARCHAR(30);
    DECLARE @Isbn NVARCHAR(20);
    DECLARE @BorrowDate DATE;
    DECLARE @LoanDays INT;
    DECLARE @Fine DECIMAL(10,2);

    BEGIN TRANSACTION;

    SELECT
        @ReaderCardNo = ReaderCardNo,
        @Isbn = Isbn,
        @BorrowDate = BorrowDate,
        @LoanDays = LoanDays
    FROM dbo.BorrowRecords WITH (UPDLOCK, HOLDLOCK)
    WHERE LoanId = @LoanId AND ReturnDate IS NULL;

    IF @ReaderCardNo IS NULL
        THROW 51006, N'借阅记录不存在或已归还。', 1;

    SET @Fine = CASE
        WHEN @ReturnDate > DATEADD(DAY, @LoanDays, @BorrowDate)
        THEN DATEDIFF(DAY, DATEADD(DAY, @LoanDays, @BorrowDate), @ReturnDate) * 0.50
        ELSE 0
    END;

    UPDATE dbo.BorrowRecords
       SET ReturnDate = @ReturnDate,
           Fine = @Fine,
           FinePaid = CASE WHEN @Fine = 0 THEN 1 ELSE 0 END
     WHERE LoanId = @LoanId;

    UPDATE dbo.Books
       SET AvailableCopies = AvailableCopies + 1,
           IsBorrowable = 1,
           UpdatedAt = SYSUTCDATETIME()
     WHERE Isbn = @Isbn;

    UPDATE dbo.Readers
       SET BorrowedCount = CASE WHEN BorrowedCount > 0 THEN BorrowedCount - 1 ELSE 0 END,
           UpdatedAt = SYSUTCDATETIME()
     WHERE ReaderCardNo = @ReaderCardNo;

    SELECT @Fine AS Fine;

    COMMIT TRANSACTION;
END;
GO

CREATE PROCEDURE dbo.sp_PayReaderFine
    @ReaderCardNo NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.BorrowRecords
       SET FinePaid = 1
     WHERE ReaderCardNo = @ReaderCardNo
       AND ReturnDate IS NOT NULL
       AND Fine > 0
       AND FinePaid = 0;

    SELECT @@ROWCOUNT AS PaidRecords;
END;
GO

CREATE TRIGGER trg_CheckOverdueOnBorrow
ON BorrowRecords
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReaderCardNo NVARCHAR(50);
    SELECT @ReaderCardNo = ReaderCardNo FROM inserted;
    DECLARE @OverdueCount INT;
    
    SELECT @OverdueCount = COUNT(1) 
    FROM BorrowRecords 
    WHERE ReaderCardNo = @ReaderCardNo 
      AND ReturnDate IS NULL 
      AND DATEADD(day, LoanDays, BorrowDate) < GETDATE();

    IF (@OverdueCount > 0)
    BEGIN
        RAISERROR ('借阅失败：该读者当前有超期未还的图书，禁止借阅！', 16, 1);
        ROLLBACK TRANSACTION; 
    END
    ELSE
    BEGIN
        INSERT INTO BorrowRecords (ReaderCardNo, Isbn, BorrowDate, LoanDays, ReturnDate, Fine, FinePaid, Remark, CreatedAt)
        SELECT ReaderCardNo, Isbn, BorrowDate, LoanDays, ReturnDate, Fine, FinePaid, Remark, CreatedAt 
        FROM inserted;
    END
END;

--Task0
CREATE DATABASE test_task_db;
GO

USE test_task_db;

CREATE TABLE SocialStatuses(
	SocialStatusId INT IDENTITY(1, 1) NOT NULL,
	StatusName NVARCHAR(100) NOT NULL,
	CONSTRAINT PK_SocialStatuses PRIMARY KEY CLUSTERED (SocialStatusId ASC)
 );

CREATE TABLE Cities(
	CityId INT IDENTITY(1, 1) NOT NULL,
	CityName NVARCHAR(50) NOT NULL,
	CityCode INT NOT NULL,
	CONSTRAINT PK_City PRIMARY KEY CLUSTERED (CityId ASC)
);

CREATE TABLE Banks(
	BankId INT IDENTITY(1, 1) NOT NULL,
	BankName VARCHAR(200) NOT NULL,
	CONSTRAINT PK_Banks PRIMARY KEY CLUSTERED (BankId ASC)
);

CREATE TABLE Accounts(
	AccountId	INT IDENTITY(1, 1) NOT NULL,
	Name NVARCHAR(150) NOT NULL,
	Balance INT NULL,
	BankId INT NOT NULL,
	SocialStatusId INT NOT NULL,
	CONSTRAINT PK_Accounts PRIMARY KEY CLUSTERED ( AccountId ASC),
	CONSTRAINT FK_Accounts_Banks FOREIGN KEY(BankId) REFERENCES Banks (BankId),
	CONSTRAINT FK_Accounts_SocialStatuses FOREIGN KEY(SocialStatusId) REFERENCES SocialStatuses (SocialStatusId),
 );

CREATE TABLE Cards(
	CardId INT IDENTITY(1, 1) NOT NULL,
	AccountId INT NOT NULL,
	CardNumber NVARCHAR(50) NOT NULL,
	Balance INT NULL,
	CONSTRAINT PK_Cards PRIMARY KEY CLUSTERED (CardId ASC),
	CONSTRAINT FK_Cards_Accounts FOREIGN KEY(AccountId) REFERENCES Accounts (AccountId)
 );

CREATE TABLE Branches(
	BranchId INT IDENTITY(1, 1) NOT NULL,
	BankId INT NOT NULL,
	Number INT NOT NULL,
	CityId INT NOT NULL,
	CONSTRAINT PK_Branches PRIMARY KEY CLUSTERED (BranchId ASC),
	CONSTRAINT FK_Branches_Banks FOREIGN KEY(BankId) REFERENCES Banks (BankId),
	CONSTRAINT FK_Branches_Cities FOREIGN KEY(CityId) REFERENCES Cities (CityId)
);
GO

INSERT INTO Cities (CityName, CityCode)
VALUES 
('Gomel', 3),
('Minsk', 7),
('Vitebsk', 2),
('Brest', 1),
('Grodno', 4);

INSERT INTO Banks (BankName)
VALUES
('ALFA-BANK'),
('BELGAZPROMBANK'),
('PRIORBANK'),
('BELARUSBANK'),
('VTB');

INSERT INTO SocialStatuses (StatusName)
VALUES
('PENSIONER'),
('DISABLED'),
('OFFICIAL'),
('UNEMPLOYED'),
('EMPLOYED');

INSERT INTO Accounts (Name, Balance, BankId, SocialStatusId)
VALUES
('IVAN IVANOV', 150, 1, 1),
('DMITRIY SAF', 200, 2, 2),
('ANATOLIY GOR', 300, 3, 3),
('NIKITA NIKITIN', 0, 4, 1),
('ALEX GROM', 40, 5, 5);

INSERT INTO Cards (CardNumber, Balance,  AccountId)
VALUES
('1111111111111111', 10, 1),
('2111111111111111', 15, 1),
('2222222222222222', 3, 2),
('3333333333333333', 34, 3),
('4444444444444444', 0, 4),
('5555555555555555', 3, 5);

INSERT INTO Branches (BankId, Number, CityId)
VALUES
(1, 1, 1),
(1, 2, 2),
(2, 10, 3),
(3, 1, 5),
(4, 1, 5);
GO

--Task1
--Get banks list with branches in specific city
DECLARE @cityid INT;

SET @cityid = 5;

SELECT DISTINCT Banks.*, Cities.CityName
FROM Banks
JOIN Branches ON Branches.BankId = Banks.BankId
JOIN Cities ON Cities.CityId = Branches.CityId
WHERE Cities.CityId = @cityid;
GO

--Task2
--Get cards list with owners info
SELECT Cards.CardId, Cards.CardNumber, Cards.Balance, Accounts.Name, Banks.BankName
FROM Cards
JOIN Accounts ON Accounts.AccountId = Cards.AccountId
JOIN Banks ON Banks.BankId = Accounts.BankId;
GO

--Task3
--Get list of accounts with balance that does not match with sum of balances of the account cards
SELECT Accounts.AccountId, Accounts.Name, Accounts.Balance, SUM(Cards.Balance) AS CardsBalance, Accounts.Balance - SUM(Cards.Balance) AS BalanceDifference
FROM Accounts
JOIN Cards ON Cards.AccountId = Accounts.AccountId
GROUP BY Accounts.AccountId, Accounts.Name, Accounts.Balance
HAVING Accounts.Balance - SUM(Cards.Balance) != 0;
GO

--Task4
--Get amount of cards for different social statuses by subquery
SELECT SocialStatuses.*, 
	(SELECT COUNT(CardId)
	 FROM Cards 
	 JOIN Accounts ON Accounts.AccountId = Cards.AccountId
	 WHERE Accounts.SocialStatusId = SocialStatuses.SocialStatusId) AS CardsAmount
FROM SocialStatuses;

--Get amount of cards for different social statuses by GroupBy
SELECT SocialStatuses.*, COUNT(Cards.CardId) AS CardsAmount
FROM SocialStatuses
LEFT JOIN Accounts ON Accounts.SocialStatusId = SocialStatuses.SocialStatusId
LEFT JOIN Cards ON Cards.AccountId = Accounts.AccountId
GROUP BY SocialStatuses.SocialStatusId, SocialStatuses.StatusName;
GO

--Task5
--Create procedure to Add money to the accounts of specific Social Status 
CREATE PROCEDURE AddSocialMoney
	@socialstatusid INT
AS
BEGIN TRY
	IF NOT EXISTS (SELECT * FROM SocialStatuses WHERE SocialStatusId = @socialstatusid)
		RAISERROR('Social Status with such ID do not exists', 16, 1);
	IF NOT EXISTS (SELECT * FROM Accounts WHERE SocialStatusId = @socialstatusid)
		RAISERROR('Accounts with such Social Status ID do not exists', 16, 1);
	UPDATE Accounts
	SET Balance = Balance + 10
	WHERE SocialStatusId = @socialstatusid;
END TRY
BEGIN CATCH
	PRINT 'Error ' + CONVERT(VARCHAR, ERROR_NUMBER()) + ':' + ERROR_MESSAGE();
END CATCH;
GO

DECLARE @socialstatusid INT;

SET @socialstatusid = 1;

--Check before procedure call
SELECT * FROM Accounts;

--Call procedure
EXEC AddSocialMoney @socialstatusid;

--Check after procedure call
SELECT * FROM Accounts;
GO

--Task6
--Get list of accounts available funds
SELECT Accounts.AccountId, Accounts.Name, 
	IIF(Accounts.Balance - SUM(Cards.Balance) < 0, 0, Accounts.Balance - SUM(Cards.Balance)) AS AvailableFunds
FROM Accounts
LEFT JOIN Cards ON Cards.AccountId = Accounts.AccountId
GROUP BY Accounts.AccountId, Accounts.Name, Accounts.Balance;
GO

--Task7
--Create function to get Account Available Funds
CREATE FUNCTION AccountAvailableFunds(@accountid INT)
RETURNS INT
AS
BEGIN
	DECLARE @availablefunds INT;
	
	SET @availablefunds = 
		(SELECT Accounts.Balance - (SELECT SUM(Balance) FROM Cards WHERE AccountId = @accountid)
		 FROM Accounts
		 WHERE AccountId = @accountid);
	
	IF @availablefunds < 0
		SET @availablefunds = 0;
	
	RETURN (@availablefunds);
END;
GO

--Create procedure to Transfer Money From Account To Card
CREATE PROCEDURE TransferMoneyFromAccountToCard
	@accountid INT,
	@cardid INT,
	@amounttotransfer INT
AS
BEGIN TRY
	DECLARE @availablefunds INT;

	IF NOT EXISTS (SELECT * FROM Accounts WHERE AccountId = @accountid)
		RAISERROR('Account with such ID do not exists', 16, 1);
	IF NOT EXISTS (SELECT * FROM Cards WHERE CardId = @cardid AND AccountId = @accountid)
		RAISERROR('Card with such ID do not exists for that Account', 16, 1);
	IF @amounttotransfer <= 0
		RAISERROR('Amount to transfer cannot be less or equals 0', 16, 1);
	
	SET @availablefunds = dbo.AccountAvailableFunds(@accountid);

	IF @amounttotransfer > @availablefunds
		RAISERROR('Amount to transfer cannot be more than available funds', 16, 1);

	BEGIN TRANSACTION
		UPDATE Cards
		SET Balance = Balance + @amounttotransfer
		WHERE CardId = @cardid;
	COMMIT TRANSACTION
END TRY
BEGIN CATCH
	PRINT 'Error ' + CONVERT(VARCHAR, ERROR_NUMBER()) + ':' + ERROR_MESSAGE();
END CATCH;
GO

--Check before procedure call
SELECT Accounts.AccountId, Accounts.Name, Accounts.Balance, dbo.AccountAvailableFunds(Accounts.AccountId) AS AvailableFunds, Cards.CardId, Cards.Balance
FROM Accounts
JOIN Cards ON Cards.AccountId = Accounts.AccountId;

DECLARE @accountid INT, @cardid INT, @amount INT;

SET @accountid = 1;
SET @cardid = 1;
SET @amount = 33;

--Call procedure
EXEC TransferMoneyFromAccountToCard @accountid, @cardid, @amount;

--Check after procedure call
SELECT Accounts.AccountId, Accounts.Name, Accounts.Balance, dbo.AccountAvailableFunds(Accounts.AccountId) AS AvailableFunds, Cards.CardId, Cards.Balance
FROM Accounts
JOIN Cards ON Cards.AccountId = Accounts.AccountId;
GO

--Task8
--Create trigger that check Account Balance to be more than total cards balance
CREATE TRIGGER AccountBalance_UPDATE 
ON Accounts 
AFTER UPDATE
As
BEGIN
DECLARE @index INT, @accountbalance_inserted INT, @accountcardstotalbalance INT;
SET @index = 1;
WHILE @index <= @@ROWCOUNT
	BEGIN
	SET @accountbalance_inserted = (SELECT Balance FROM INSERTED ORDER BY AccountId OFFSET @index - 1 ROW FETCH NEXT 1 ROWS ONLY);
	SET @accountcardstotalbalance = (SELECT SUM(Balance) FROM Cards WHERE AccountId = (SELECT AccountId FROM INSERTED ORDER BY AccountId OFFSET @index - 1 ROW FETCH NEXT 1 ROWS ONLY))
	IF @accountbalance_inserted < @accountcardstotalbalance
		BEGIN
		RAISERROR('Balance cannot be less than total cards balance', 16, 1);
		ROLLBACK TRANSACTION; 
		END;
	SET @index = @index + 1;
	END;
END
GO

--Create trigger that check Card Balance to be less than Account Balance
CREATE TRIGGER CardBalance_UPDATE 
ON Cards 
AFTER UPDATE
AS
IF (SELECT SUM(Balance) FROM Cards WHERE AccountId = (SELECT AccountId FROM INSERTED)) > (SELECT Balance FROM Accounts WHERE AccountId = (SELECT AccountId FROM INSERTED))
	BEGIN
	RAISERROR('Balance cannot be more than account balance', 16, 1);
	ROLLBACK TRANSACTION; 
	END;
GO

--Check before card balance update
SELECT Accounts.AccountId, Accounts.Name, Accounts.Balance, dbo.AccountAvailableFunds(Accounts.AccountId) AS AvailableFunds, Cards.CardId, Cards.Balance
FROM Accounts
JOIN Cards ON Cards.AccountId = Accounts.AccountId;
GO

DECLARE @cardbalance_update INT, @cardid_update INT;

SET @cardbalance_update = 15;
SET @cardid_update = 1;

--Update card balance
UPDATE Cards 
SET Balance = @cardbalance_update 
WHERE CardId = @cardid_update;
GO

--Check after card balance update
SELECT Accounts.AccountId, Accounts.Name, Accounts.Balance, dbo.AccountAvailableFunds(Accounts.AccountId) AS AvailableFunds, Cards.CardId, Cards.Balance
FROM Accounts
JOIN Cards ON Cards.AccountId = Accounts.AccountId;
GO

DECLARE @accountbalance_update INT, @accountid_update INT;

SET @accountbalance_update = 90;
SET @accountid_update = 1;

--Update Account balance
UPDATE Accounts
SET Balance = @accountbalance_update
WHERE AccountId = @accountid_update;
GO

--Check after Account update
SELECT Accounts.AccountId, Accounts.Name, Accounts.Balance, dbo.AccountAvailableFunds(Accounts.AccountId) AS AvailableFunds, Cards.CardId, Cards.Balance
FROM Accounts
JOIN Cards ON Cards.AccountId = Accounts.AccountId;
GO

-- =======================================================================================
-- Author:		ebp Global
-- Create date: 13/9/2017
-- Description:	This procedure loads the dim_date table and calculates the VFA fiscal calendar
-- =======================================================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_dim_date]
	@FiscalCalendarStart datetime ,
	@FiscalCalendarEnd datetime ,
	@FiscalStartingMonth int ,
	@MonthExtraWeekAdded int
   /*   This script is meant for a 4-4-5 calendar, Sun-Sat week.  Every leap year introduces an
            extra week, which we add in June.

    *  User Variables =

            FiscalCalendarStart = The date on which a fiscal year starts.  This is used as the base
                  date for all calculations

            FiscalCalendarEnd = The date on which the calendar should end.  This does not have to be
                  the end of a fiscal year, but if it's not, you might have to run the script again
                  to get to the end of teh fiscal year.


            FiscalStartingMonth = Usually 1, the number of fiscal months since the original calendar began

            FiscalYearSeed = The starting fiscal year
    */

AS
BEGIN

		-- The temp variable table use to store each line of the loop
	DECLARE @NewCalendar as table (
	    id INT,
		full_date DATE,
        season_buy NVARCHAR(45),
		season_year_short_buy NVARCHAR(45),
		season_crd NVARCHAR(45),
		season_year_short_crd NVARCHAR(45),
		season_intro NVARCHAR(45),
		season_year_short_intro NVARCHAR(45),
		year_accounting INT,
        year_cw_accounting NVARCHAR(45),
		year_month_accounting NVARCHAR(45),
		month_name_accounting NVARCHAR(45),
		day_of_week INT,
		day_name_of_week NVARCHAR(45),
		is_last_day_of_month INT,
		is_weekend_day INT
	)


	-- Iteration variables used for internal procedure
	DECLARE
		@WorkPeriodSeed INT = 1 ,
		@WorkSeasonSeedBuy NVARCHAR(2),
		@WorkSeasonSeedCRD NVARCHAR(2),
		@WorkSeasonSeedIntro NVARCHAR(2),
		@WorkWeekSeed INT = 1 ,
		@WeekOfMonth INT = 1 ,
		@IsLeapYear  INT = 0 ,
		@FiscalYearSeed INT = 0,
		@CountMissingDays INT = 0,
		@CurrentDate datetime,
		@Fiscal datetime = CASE
								WHEN @FiscalStartingMonth < 10 THEN convert(date,'1900/0'+ CONVERT(VARCHAR(1),@FiscalStartingMonth)+'/01')
								ELSE convert(date,'1900/'+ CONVERT(VARCHAR(2),@FiscalStartingMonth)+'/01')
						   END

	-- Set the real starting date by choosing previous year if the month of the input date is before first fiscal month, else choose current year
	SELECT @CurrentDate = CASE WHEN MONTH(@FiscalCalendarStart) - @FiscalStartingMonth >=0 THEN DateAdd(year, datediff(year, IsNull(@Fiscal,'1/1/1900'), @FiscalCalendarStart) , IsNull(@Fiscal,'1/1/1900'))
								ELSE DateAdd(year, datediff(year, IsNull(@Fiscal,'1/1/1900'), DATEADD(YEAR,-1,@FiscalCalendarStart)) , IsNull(@Fiscal,'1/1/1900'))
						  END

	IF DATEPART(DW,@CurrentDate) <> 1
		BEGIN
			DECLARE @CurrentDateTmp datetime = Dateadd(week, -1,@CurrentDate)
			WHILE DATEPART(DW,@CurrentDateTmp) <> 1
				BEGIN
					SET @CurrentDateTmp = @CurrentDateTmp + 1
				END
				-- The distance found between the calculated date and the 1st day of fiscal month should always been less than 4 days
			IF abs(DATEDIFF(DAY,@CurrentDate,@CurrentDateTmp)) > 4
				BEGIN
					SET @CurrentDate = DATEADD(WEEK, 1,@CurrentDateTmp)
				END
			ELSE
				SET @CurrentDate = @CurrentDateTmp
		END
			/*
			 This FiscalYearSeed initialization depends of the company fiscal calendar
			*/
	SELECT @FiscalYearSeed = YEAR(@CurrentDate),

		-- Set the counter for the remaining days, 2 if year is leap year, 1 else
		@CountMissingDays = CASE
								WHEN (@FiscalYearSeed % 4 = 0 AND @FiscalYearSeed % 100 <> 0) OR @FiscalYearSeed % 400 = 0 THEN 2
								ELSE 1
							 END,
		@WorkSeasonSeedBuy = CASE
							WHEN MONTH(@CurrentDate) IN (9, 10, 11, 12, 1) THEN 'SP'
							WHEN MONTH(@CurrentDate) IN (2, 3, 4, 5) THEN 'FA'
							ELSE 'HO'
						  END,
		@WorkSeasonSeedCRD = CASE
							WHEN MONTH(@CurrentDate) IN (11, 12, 1, 2, 3) THEN 'SP'
							WHEN MONTH(@CurrentDate) IN (4, 5, 6, 7) THEN 'FA'
							ELSE 'HO'
						  END,
		@WorkSeasonSeedIntro = CASE
							WHEN MONTH(@CurrentDate) IN (1, 2, 3, 4, 5) THEN 'SP'
							WHEN MONTH(@CurrentDate) IN (6, 7 ,8, 9) THEN 'FA'
							ELSE 'HO'
						  END

	-- The loop is iterated once for each day
	WHILE @CurrentDate <= @FiscalCalendarEnd
		BEGIN

			INSERT INTO @NewCalendar (id, full_date, season_buy, season_year_short_buy, season_crd, season_year_short_crd, season_intro, season_year_short_intro, year_accounting, year_cw_accounting, year_month_accounting, month_name_accounting, day_of_week, day_name_of_week, is_last_day_of_month, is_weekend_day)
				SELECT
					CAST(CONVERT(VARCHAR(8),@CurrentDate,112) AS INT) as id,
					FORMAT(@CurrentDate,'yyyy-MM-dd') as full_date,
					@WorkSeasonSeedBuy as season_buy,
					CASE
						WHEN @WorkPeriodSeed IN (9, 10, 11, 12) THEN @WorkSeasonSeedBuy + SUBSTRING(CONVERT(VARCHAR(4),@FiscalYearSeed + 1),3,2)
						ELSE @WorkSeasonSeedBuy + SUBSTRING(CONVERT(VARCHAR(4),@FiscalYearSeed),3,2)
					END AS season_year_short_buy,
					@WorkSeasonSeedCRD as season_crd,
					CASE
						WHEN @WorkPeriodSeed IN (11, 12) THEN @WorkSeasonSeedCRD + SUBSTRING(CONVERT(VARCHAR(4),@FiscalYearSeed + 1),3,2)
						ELSE @WorkSeasonSeedCRD + SUBSTRING(CONVERT(VARCHAR(4),@FiscalYearSeed),3,2)
					END AS season_year_short_crd,
					@WorkSeasonSeedIntro as season_intro,
					@WorkSeasonSeedIntro + SUBSTRING(CONVERT(VARCHAR(4),@FiscalYearSeed),3,2) AS season_year_short_intro,
				    @FiscalYearSeed as year_accounting,
					CONVERT(VARCHAR(4),@FiscalYearSeed) + 'CW' + RIGHT('00'+CAST(@WorkWeekSeed AS VARCHAR(2)),2) as year_cw_accounting,
					CONVERT(VARCHAR(4),@FiscalYearSeed) + '-' + RIGHT('00'+CAST(@WorkPeriodSeed AS VARCHAR(2)),2) as year_month_accounting,
					CASE @WorkPeriodSeed
						WHEN 1 THEN 'January'
						WHEN 2 THEN 'February'
						WHEN 3 THEN 'March'
						WHEN 4 THEN 'April'
						WHEN 5 THEN 'May'
						WHEN 6 THEN 'June'
						WHEN 7 THEN 'July'
						WHEN 8 THEN 'August'
						WHEN 9 THEN 'September'
						WHEN 10 THEN 'October'
						WHEN 11 THEN 'November'
						ELSE 'December'
					END as month_name_accounting,
					DATEPART(DW,@CurrentDate) as day_of_week,
					DATENAME(DW,@CurrentDate) as day_name_of_week,
					CASE
						WHEN @CurrentDate = EOMONTH(@CurrentDate) THEN 1
						ELSE 0
					END as is_last_day_of_month,
					CASE
						WHEN DATEPART(DW ,@CurrentDate) in (7,1) THEN 1
						ELSE 0
					END as is_weekend_day

				--Iterate the current date
			SET @CurrentDate = DATEADD ( D , 1 , @CurrentDate )

				--Every Sunday (start of new fiscal week), increment fiscal counters
			IF DATEPART(DW,@CurrentDate) = 1
				BEGIN
					  --These months have 5 weeks in the 4-4-5 calendar (IF @WorkPeriodSeed % 3 = 1)
					IF @WorkPeriodSeed IN (3, 6, 9, 12)
						BEGIN

							--Iterate the RunningWeek and WeekOfMonth (roll WeekOfMonth if necessary)
							SELECT
								@WeekOfMonth = CASE @WeekOfMonth
														WHEN 5 THEN 1
														ELSE @WeekOfMonth + 1
											   END ,
								@WorkWeekSeed = @WorkWeekSeed + 1


							--First week of the month we need to update the WorkPeriod and FiscalStartingMonth
							IF @WeekOfMonth = 1
								   SELECT
										@WorkPeriodSeed = @WorkPeriodSeed + 1,
										@FiscalStartingMonth = CASE @FiscalStartingMonth
																	WHEN 12 THEN 1
																	ELSE @FiscalStartingMonth + 1
															   END

						END
					ELSE
						BEGIN

					   /*
							October in leap years get 5 weeks also, so 4th quarter is 5-4-5
							Change @WorkPeriodSeed to the month you want to add the extra week into
					  */
							IF @CountMissingDays > 6 AND @WorkPeriodSeed = @MonthExtraWeekAdded
								BEGIN

								 -- Iterate the RunningWeek and WeekOfMonth (roll WeekOfMonth if necessary)
									SELECT
										@WeekOfMonth = CASE @WeekOfMonth
															WHEN 5 THEN 1
															ELSE @WeekOfMonth + 1
													   END,
										@WorkWeekSeed = @WorkWeekSeed + 1


								 --  First week of the month we need to update the WorkPeriod and FiscalStartingMonth
									IF @WeekOfMonth = 1
										 SELECT
											@WorkPeriodSeed = @WorkPeriodSeed + 1,
											@FiscalStartingMonth = CASE @FiscalStartingMonth
																		WHEN 12 THEN 1
																		ELSE @FiscalStartingMonth + 1
																   END
								END
							ELSE
								BEGIN

								 	-- Iterate the RunningWeek and WeekOfMonth (roll WeekOfMonth if necessary)
									SELECT
										@WeekOfMonth = CASE @WeekOfMonth
															WHEN 4 THEN 1
															ELSE @WeekOfMonth + 1
													   END,
										@WorkWeekSeed = @WorkWeekSeed + 1


								 	--  First week of the month we need to update the WorkPeriod and FiscalStartingMonth
									IF @WeekOfMonth = 1
										 SELECT
											@WorkPeriodSeed = @WorkPeriodSeed + 1,
											@FiscalStartingMonth = CASE @FiscalStartingMonth
																		WHEN 12 THEN 1
																		ELSE @FiscalStartingMonth + 1
																   END
							 END

					   END

					 /*
						 Detect if we have a year change
						 Then we reset or increment some iteration variables
					*/


					   IF @WorkPeriodSeed = 13 AND @WeekOfMonth = 1
							 SELECT
									@FiscalYearSeed = @FiscalYearSeed + 1,
									@WorkPeriodSeed = 1,
									@WorkWeekSeed = 1,
									@IsLeapYear = CASE
													WHEN (@FiscalYearSeed % 4 = 0 AND @FiscalYearSeed % 100 <> 0) OR @FiscalYearSeed % 400 = 0 THEN 1
													ELSE 0
												  END,
									@CountMissingDays = CASE
															WHEN @CountMissingDays >= 7 THEN CASE @IsLeapYear
																				WHEN 1 THEN 2
																				ELSE 1
																			END
															ELSE CASE @IsLeapYear
																	WHEN 1 THEN @CountMissingDays + 2
																	ELSE @CountMissingDays + 1
																 END
														END
				/*
			  	Fill the season variable
			  	*/
				-- Buy season
				IF @WorkPeriodSeed IN (9, 10, 11, 12, 1)
				SELECT @WorkSeasonSeedBuy = 'SP'
				IF @WorkPeriodSeed IN (2, 3, 4, 5)
				SELECT @WorkSeasonSeedBuy = 'FA'
				IF @WorkPeriodSeed IN (6, 7, 8)
		   		SELECT @WorkSeasonSeedBuy = 'HO'

				-- CRD season
				IF @WorkPeriodSeed IN (11, 12, 1, 2, 3)
				SELECT @WorkSeasonSeedCRD = 'SP'
				IF @WorkPeriodSeed IN (4, 5, 6, 7)
				SELECT @WorkSeasonSeedCRD = 'FA'
				IF @WorkPeriodSeed IN (8, 9, 10)
		   		SELECT @WorkSeasonSeedCRD = 'HO'

				-- Intro season
				IF @WorkPeriodSeed IN (1, 2, 3, 4, 5)
				SELECT @WorkSeasonSeedIntro = 'SP'
				IF @WorkPeriodSeed IN (6, 7 ,8, 9)
				SELECT @WorkSeasonSeedIntro = 'FA'
				IF @WorkPeriodSeed IN (10, 11, 12)
		   		SELECT @WorkSeasonSeedIntro = 'HO'

			END
	END
			-- TO BE USED FOR DEBUG
	----------------------------------------
		/*	IF OBJECT_ID('new_calendar','U') IS NOT NULL
			BEGIN
				DROP TABLE [dbo].[new_calendar]
			END

			SELECT * INTO [dbo].[new_calendar] FROM @NewCalendar*/
	-----------------------------------------

	/*
		Finally we insert the new calendar in the dim_date table
	*/

	INSERT INTO [dbo].[dim_date] (id, full_date, season_buy, season_year_buy, season_year_short_buy, season_crd, season_year_crd, season_year_short_crd, season_intro, season_year_intro, season_year_short_intro, year_accounting, year_cw_accounting, year_month_accounting, month_name_accounting, month_name_short_accounting, day_of_week, day_name_of_week, is_last_day_of_month, is_weekend_day)
	SELECT
		id,
		full_date,
		season_buy,
		CASE season_buy
			WHEN 'SP' THEN 'Spring ' + CONVERT(VARCHAR(4), year_accounting)
			WHEN 'FA' THEN 'Fall ' + CONVERT(VARCHAR(4), year_accounting)
			ELSE 'Holiday ' + CONVERT(VARCHAR(4), year_accounting)
		END as season_year_buy,
		season_year_short_buy,
		season_crd,
		CASE season_crd
			WHEN 'SP' THEN 'Spring ' + CONVERT(VARCHAR(4), year_accounting)
			WHEN 'FA' THEN 'Fall ' + CONVERT(VARCHAR(4), year_accounting)
			ELSE 'Holiday ' + CONVERT(VARCHAR(4), year_accounting)
		END as season_year_crd,
		season_year_short_crd,
		season_intro,
		CASE season_intro
			WHEN 'SP' THEN 'Spring ' + CONVERT(VARCHAR(4), year_accounting)
			WHEN 'FA' THEN 'Fall ' + CONVERT(VARCHAR(4), year_accounting)
			ELSE 'Holiday ' + CONVERT(VARCHAR(4), year_accounting)
		END as season_year_intro,
		season_year_short_intro,
		year_accounting,
		year_cw_accounting,
		year_month_accounting,
		month_name_accounting,
		SUBSTRING(month_name_accounting, 1, 3) as month_name_short_accounting,
		day_of_week,
		day_name_of_week,
		is_last_day_of_month,
		is_weekend_day
	FROM @NewCalendar
	WHERE id NOT IN (SELECT id from [dbo].[dim_date])



	/*
		And update when id already exists
	*/

	UPDATE dt
	SET
		dt.full_date = new.full_date,
		dt.season_buy = new.season_buy,
		dt.season_year_buy = CASE
										WHEN new.season_buy = 'SP' AND month_name_short_accounting IN ('Sep', 'Oct', 'Nov', 'Dec') THEN 'Spring ' + CONVERT(VARCHAR(4), CONVERT(INT, new.year_accounting)+1)
										WHEN new.season_buy = 'SP' AND month_name_short_accounting NOT IN ('Sep', 'Oct', 'Nov', 'Dec') THEN 'Spring ' + CONVERT(VARCHAR(4), new.year_accounting)
										WHEN new.season_buy = 'FA' THEN 'Fall ' + CONVERT(VARCHAR(4), new.year_accounting)
										ELSE 'Holiday ' + CONVERT(VARCHAR(4), new.year_accounting)
									END,
		dt.season_year_short_buy = new.season_year_short_buy,
		dt.season_crd = new.season_crd,
		dt.season_year_crd = CASE
										WHEN new.season_crd = 'SP' AND month_name_short_accounting IN ('Nov', 'Dec') THEN 'Spring ' + CONVERT(VARCHAR(4), CONVERT(INT, new.year_accounting)+1)
										WHEN new.season_crd = 'SP' AND month_name_short_accounting NOT IN ('Nov', 'Dec') THEN 'Spring ' + CONVERT(VARCHAR(4), new.year_accounting)
										WHEN new.season_crd = 'FA' THEN 'Fall ' + CONVERT(VARCHAR(4), new.year_accounting)
										ELSE 'Holiday ' + CONVERT(VARCHAR(4), new.year_accounting)
									END,
		dt.season_year_short_crd = new.season_year_short_crd,
		dt.season_intro = new.season_intro,
		dt.season_year_intro = CASE new.season_intro
										WHEN 'SP' THEN 'Spring ' + CONVERT(VARCHAR(4), new.year_accounting)
										WHEN 'FA' THEN 'Fall ' + CONVERT(VARCHAR(4), new.year_accounting)
										ELSE 'Holiday ' + CONVERT(VARCHAR(4), new.year_accounting)
									END,
		dt.season_year_short_intro = new.season_year_short_intro,
		dt.year_accounting = new.year_accounting,
		dt.year_cw_accounting = new.year_cw_accounting,
		dt.year_month_accounting = new.year_month_accounting,
		dt.month_name_accounting = new.month_name_accounting,
		dt.month_name_short_accounting = SUBSTRING(new.month_name_accounting, 1, 3),
		dt.day_of_week = new.day_of_week,
		dt.day_name_of_week = new.day_name_of_week,
		dt.is_last_day_of_month = new.is_last_day_of_month,
		dt.is_weekend_day = new.is_weekend_day
	FROM [dbo].[dim_date] dt
	INNER JOIN @NewCalendar new on new.id = dt.id
END


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
   /*   This script is meant for a 5-4-4 calendar, Sun-Sat week.  Every leap year introduces an
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
        season_accounting NVARCHAR(45),
        season_year_accounting NVARCHAR(45),
        year_accounting INT,
        year_cw_accounting NVARCHAR(45),
		year_month_accounting NVARCHAR(45),
		day_of_week INT,
		day_name_of_week NVARCHAR(45),
		is_last_day_of_month INT,
		is_weekend_day INT
	)

		-- Iteration variables used for internal procedure

	DECLARE
		@WorkPeriodSeed INT = 1 ,
		@WorkSeasonSeed NVARCHAR(2),
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
		@WorkSeasonSeed = CASE
							WHEN MONTH(@CurrentDate) IN (9, 10, 11, 12, 1) THEN 'SP'
							WHEN MONTH(@CurrentDate) IN (2, 3, 4, 5) THEN 'FA'
							ELSE 'HO'
						  END

		-- The loop is iterated once for each day

	WHILE @CurrentDate <= @FiscalCalendarEnd
		BEGIN

			INSERT INTO @NewCalendar (id, full_date, season_accounting, season_year_accounting, year_accounting, year_cw_accounting, year_month_accounting, day_of_week, day_name_of_week, is_last_day_of_month, is_weekend_day)
				SELECT
					CAST(CONVERT(VARCHAR(8),@CurrentDate,112) AS INT) as id,
					FORMAT(@CurrentDate,'yyyy-MM-dd') as full_date,
					@WorkSeasonSeed as season_accounting,
					@WorkSeasonSeed + SUBSTRING(CONVERT(VARCHAR(4),@FiscalYearSeed),3,2) season_year_accounting,
				    @FiscalYearSeed as year_accounting,
					CONVERT(VARCHAR(4),@FiscalYearSeed) + 'CW' + CONVERT(VARCHAR(2),@WorkWeekSeed) as year_cw_accounting,
					CONVERT(VARCHAR(4),@FiscalYearSeed) + '-' + RIGHT('00'+CAST(@WorkPeriodSeed AS VARCHAR(2)),2) as year_month_accounting,
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
					  --These months have 5 weeks in the 5-4-4 calendar
					IF @WorkPeriodSeed % 3 = 1
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
							December in leap years get 5 weeks also, so 4th quarter is 5-4-5
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
				  IF @WorkPeriodSeed IN (9, 10, 11, 12, 1)
				  	SELECT @WorkSeasonSeed = 'SP'
				  IF @WorkPeriodSeed IN (2, 3, 4, 5)
				  	SELECT @WorkSeasonSeed = 'FA'
				  IF @WorkPeriodSeed IN (6, 7, 8)
		   		   SELECT @WorkSeasonSeed = 'HO'
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

	INSERT INTO [dbo].[dim_date] (id, full_date, season_accounting, season_year_accounting, year_accounting, year_cw_accounting, year_month_accounting, day_of_week, day_name_of_week, is_last_day_of_month, is_weekend_day)
	SELECT
		id,
		full_date,
		season_accounting,
		season_year_accounting,
		year_accounting,
		year_cw_accounting,
		year_month_accounting,
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
		dt.season_accounting = new.season_accounting,
		dt.season_year_accounting = new.season_year_accounting,
		dt.year_accounting = new.year_accounting,
		dt.year_cw_accounting = new.year_cw_accounting,
		dt.year_month_accounting = new.year_month_accounting,
		dt.day_of_week = new.day_of_week,
		dt.day_name_of_week = new.day_name_of_week,
		dt.is_last_day_of_month = new.is_last_day_of_month,
		dt.is_weekend_day = new.is_weekend_day
	FROM [dbo].[dim_date] dt
	INNER JOIN @NewCalendar new on new.id = dt.id
END

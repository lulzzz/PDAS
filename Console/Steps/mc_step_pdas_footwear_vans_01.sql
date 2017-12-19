USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 01.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_01]
AS
BEGIN
	SET NOCOUNT ON;

	WAITFOR DELAY '00:00:05'

	-- Start new PDAS release
	-- EXEC [proc_pdas_footwear_vans_create_system_key] @mc_user_name = @mc_user_name

	-- Copy previous release as current release
	-- EXEC [proc_pdas_footwear_vans_create_copy_previous_release]

END

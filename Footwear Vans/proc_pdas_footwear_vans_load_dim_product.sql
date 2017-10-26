USE [VCDWH]
GO

-- =======================================================================================
-- Author:		ebp Global
-- Create date: 13/9/2017
-- Description:	This procedure loads the dim_product table
-- =======================================================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_dim_product]
    @businessid INT
AS
BEGIN

	/*

		Incremental loading
		First we map the keys between staging table and dimension.
		If the key matched then we set the action flag to Update, otherwise flag equals Insert
		Then we insert
		Then we update

	*/

    -- Deduplicate the key pair (material_id, size)
    IF OBJECT_ID('tempdb..#material_size') IS NOT NULL
    BEGIN
        DROP TABLE #material_size;
    END

    SELECT
        dim_product_material_id,
        dim_product_size
    INTO #material_size
    FROM [dbo].[staging_pdas_footwear_vans_size_master]
    ;

	DELETE x FROM (
		SELECT *, rn=row_number() OVER (PARTITION BY dim_product_material_id, dim_product_size ORDER BY dim_product_material_id asc)
		FROM #material_size
	) x
	WHERE rn > 1;


    -- Prepare Insert / Update Keys
    IF OBJECT_ID('tempdb..#split_ins_upd') IS NOT NULL
	 BEGIN
		DROP TABLE #split_ins_upd;
	 END

    SELECT
        ms.dim_product_material_id,
        ms.dim_product_size,
        CASE ISNULL(flag, 0) WHEN 0 THEN 'Insert' ELSE 'Update' END as mode
    INTO #split_ins_upd
    FROM #material_size ms
    LEFT OUTER JOIN (SELECT material_id, size, 1 as flag FROM [dbo].[dim_product]) dp
        ON  ms.dim_product_material_id = dp.material_id
            AND ms.dim_product_size = dp.size
    WHERE dim_product_material_id NOT IN (SELECT DISTINCT material_id FROM [dbo].[dim_product])
    ;

    /*
        INSERT
    */

    INSERT INTO [dbo].[dim_product]
    (
        dim_business_id,
        material_id,
        size,
        style_id,
        color_description,
        style_name,
        material_description,
        type,
        gender,
        lifecycle,
        style_complexity,
        dim_construction_type_id,
        is_placeholder,
        placeholder_level
    )
    SELECT
        @businessid,
        mat.dim_product_material_id  as material_id,
        siz.dim_product_size as size,
        mat.dim_product_style_id as style_id,
        dim_product_color_description as color_description,
        NULL as style_name,
        mat.dim_product_material_description as material_description,
        mat.dim_product_material_type as type,
        dim_product_gender as gender,
        'Active' as lifecycle,
        'N/A' as style_complexity,
        1 as dim_construction_type_id,
        0 as is_placeholder,
        NULL as placeholder_level
    FROM
        [dbo].[staging_pdas_footwear_vans_material_master] mat
        INNER JOIN #material_size siz
            ON mat.dim_product_material_id = siz.dim_product_material_id
        INNER JOIN #split_ins_upd siu
            ON  siz.dim_product_material_id = siu.dim_product_material_id
                AND siz.dim_product_size = siu.dim_product_size
                AND siu.mode = 'Insert'
    UNION
    SELECT
        @businessid,
        ngc.dim_product_style_id as material_id,
        ngc.dim_product_size as size,
        ngc.dim_product_style_id as style_id,
        ngc.dim_product_color_description as color_description,
        NULL as style_name,
        NULL as material_description,
        NULL as type,
        NULL as gender,
        'Active' as lifecycle,
        'N/A' as style_complexity,
        1 as dim_construction_type_id,
        0 as is_placeholder,
        NULL as placeholder_level
    FROM
        (
            SELECT
                REPLACE([dim_product_style_id], ' ', '') as [dim_product_style_id],
                LTRIM(RTRIM([dim_product_size])) as [dim_product_size],
                MAX([dim_product_sbu]) as [dim_product_sbu],
                MAX([dim_product_color_description]) as [dim_product_color_description],
                MAX([dimension]) as [dimension]
            FROM [dbo].[staging_pdas_footwear_vans_ngc_po]
            GROUP BY
                [dim_product_style_id],
                [dim_product_size]
        ) AS ngc
        LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product]) dp
            ON  ngc.[dim_product_style_id] = dp.[material_id]
                AND ngc.[dim_product_size] = dp.[size]
    WHERE
        dp.[id] IS NULL

    -- Priority list data (at MTL level)
    UNION
    SELECT
        @businessid,
        CONVERT(NVARCHAR(45), prio.[dim_product_material_id])  as material_id,
        CONVERT(NVARCHAR(45), prio.[dim_product_material_id]) as size,
        CONVERT(NVARCHAR(45), prio.[dim_product_material_id]) as style_id, -- Not in priority list
        CONVERT(NVARCHAR(100), prio.[dim_product_color_description]) as color_description,
        CONVERT(NVARCHAR(100), prio.[dim_product_style_name]) as style_name,
        CONVERT(NVARCHAR(100), prio.[dim_product_material_description]) as material_description,
        CONVERT(NVARCHAR(45), prio.[sub_catprod_type]) as type,
        CONVERT(NVARCHAR(45), prio.[dim_product_gender]) as gender,
        CONVERT(NVARCHAR(45), prio.[dim_product_lifecycle]) as lifecycle, -- Update in next step
        CONVERT(NVARCHAR(45), prio.[dim_product_style_complexity]) as style_complexity, -- Update in next step
        1 as dim_construction_type_id, -- Update in next step
        1 as is_placeholder,
        'material_id' as placeholder_level
    FROM
        [dbo].[staging_pdas_footwear_vans_priority_list] prio
        LEFT OUTER JOIN (SELECT DISTINCT [material_id] FROM [dbo].[dim_product]) dp
            ON  prio.[dim_product_material_id] = dp.[material_id]
    WHERE
        dp.[material_id] IS NULL

    /*
    Insert missing sizes from NTB files (assuming data from regions correct) and get MTL attributes from priority list
    */
    -- APAC
    UNION
    SELECT
        @businessid,
        dp_m.[material_id] as material_id,
        staging.[dim_product_size] as size,
        dp_m.[style_id] as style_id, -- Not in priority list
        dp_m.[color_description] as color_description,
        dp_m.[style_name] as style_name,
        dp_m.[material_description] as material_description,
        dp_m.[type] as type,
        dp_m.[gender] as gender,
        dp_m.[lifecycle] as lifecycle, -- Update in next step
        dp_m.[style_complexity] as style_complexity, -- Update in next step
        1 as dim_construction_type_id, -- Update in next step
        0 as is_placeholder,
        NULL as placeholder_level
    FROM
        (SELECT DISTINCT [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_apac_ntb_bulk]) staging
        INNER JOIN (SELECT * FROM [dbo].[dim_product] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'material_id') dp_m
            ON  staging.[dim_product_material_id] = dp_m.[material_id]
        LEFT OUTER JOIN
        (
            SELECT [id], [material_id], [size]
            FROM [dbo].[dim_product]
        ) dp_s
            ON  staging.[dim_product_material_id] = dp_s.[material_id]
                AND staging.[dim_product_size] = dp_s.[size]
    WHERE
        dp_s.[id] IS NULL

    -- NORA
    UNION
    SELECT
        @businessid,
        dp_m.[material_id] as material_id,
        staging.[dim_product_size] as size,
        dp_m.[style_id] as style_id, -- Not in priority list
        dp_m.[color_description] as color_description,
        dp_m.[style_name] as style_name,
        dp_m.[material_description] as material_description,
        dp_m.[type] as type,
        dp_m.[gender] as gender,
        dp_m.[lifecycle] as lifecycle, -- Update in next step
        dp_m.[style_complexity] as style_complexity, -- Update in next step
        1 as dim_construction_type_id, -- Update in next step
        0 as is_placeholder,
        NULL as placeholder_level
    FROM
        (SELECT DISTINCT [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_nora_ntb_bulk]) staging
        INNER JOIN (SELECT * FROM [dbo].[dim_product] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'material_id') dp_m
            ON  staging.[dim_product_material_id] = dp_m.[material_id]
        LEFT OUTER JOIN
        (
            SELECT [id], [material_id], [size]
            FROM [dbo].[dim_product]
        ) dp_s
            ON  staging.[dim_product_material_id] = dp_s.[material_id]
                AND staging.[dim_product_size] = dp_s.[size]
    WHERE
        dp_s.[id] IS NULL

    -- CASA
    UNION
    SELECT
        @businessid,
        dp_m.[material_id] as material_id,
        staging.[dim_product_size] as size,
        dp_m.[style_id] as style_id, -- Not in priority list
        dp_m.[color_description] as color_description,
        dp_m.[style_name] as style_name,
        dp_m.[material_description] as material_description,
        dp_m.[type] as type,
        dp_m.[gender] as gender,
        dp_m.[lifecycle] as lifecycle, -- Update in next step
        dp_m.[style_complexity] as style_complexity, -- Update in next step
        1 as dim_construction_type_id, -- Update in next step
        0 as is_placeholder,
        NULL as placeholder_level
    FROM
        (SELECT DISTINCT [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_casa_ntb_bulk]) staging
        INNER JOIN (SELECT * FROM [dbo].[dim_product] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'material_id') dp_m
            ON  staging.[dim_product_material_id] = dp_m.[material_id]
        LEFT OUTER JOIN
        (
            SELECT [id], [material_id], [size]
            FROM [dbo].[dim_product]
        ) dp_s
            ON  staging.[dim_product_material_id] = dp_s.[material_id]
                AND staging.[dim_product_size] = dp_s.[size]
    WHERE
        dp_s.[id] IS NULL

    -- EMEA
    UNION
    SELECT
        @businessid,
        dp_m.[material_id] as material_id,
        staging.[dim_product_size] as size,
        dp_m.[style_id] as style_id, -- Not in priority list
        dp_m.[color_description] as color_description,
        dp_m.[style_name] as style_name,
        dp_m.[material_description] as material_description,
        dp_m.[type] as type,
        dp_m.[gender] as gender,
        dp_m.[lifecycle] as lifecycle, -- Update in next step
        dp_m.[style_complexity] as style_complexity, -- Update in next step
        1 as dim_construction_type_id, -- Update in next step
        0 as is_placeholder,
        NULL as placeholder_level
    FROM
        (SELECT DISTINCT [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_emea_ntb_bulk]) staging
        INNER JOIN (SELECT * FROM [dbo].[dim_product] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'material_id') dp_m
            ON  staging.[dim_product_material_id] = dp_m.[material_id]
        LEFT OUTER JOIN
        (
            SELECT [id], [material_id], [size]
            FROM [dbo].[dim_product]
        ) dp_s
            ON  staging.[dim_product_material_id] = dp_s.[material_id]
                AND staging.[dim_product_size] = dp_s.[size]
    WHERE
        dp_s.[id] IS NULL

    /*
      UPDATE
    */

    UPDATE dp
    SET
        dp.style_id = mat.dim_product_style_id,
        dp.color_description = mat.dim_product_color_description,
        dp.material_description = mat.dim_product_material_description,
        dp.type = mat.dim_product_material_type,
        dp.gender = mat.dim_product_gender
    FROM
        [dbo].[dim_product] dp
        INNER JOIN [dbo].[staging_pdas_footwear_vans_material_master] mat
            ON dp.material_id = mat.dim_product_material_id
        INNER JOIN #material_size siz
            ON mat.dim_product_material_id = siz.dim_product_material_id
        INNER JOIN #split_ins_upd siu
            ON  siz.dim_product_material_id = siu.dim_product_material_id
                AND siz.dim_product_size = siu.dim_product_size
                AND siu.mode = 'Update'
    WHERE dim_business_id = @businessid
    ;
    /*
        Update attributes with Priority List data
    */
    UPDATE dp
    SET
        dp.lifecycle = prio.dim_product_lifecycle,
        dp.dim_construction_type_id = cons.id,
        dp.style_complexity = prio.dim_product_style_complexity,
        dp.color_description = CONVERT(NVARCHAR(100), prio.[dim_product_color_description]),
        dp.style_name = CONVERT(NVARCHAR(100), prio.[dim_product_style_name]),
        dp.material_description = CONVERT(NVARCHAR(100), prio.[dim_product_material_description])
    FROM [dbo].[dim_product] dp
    INNER JOIN [dbo].[staging_pdas_footwear_vans_priority_list] prio ON dp.material_id = prio.dim_product_material_id
    INNER JOIN [dbo].[dim_construction_type] cons ON prio.dim_construction_type_name = cons.name
    ;


    /*
        Set Placeholders chain
    */

    -- Level Material
    INSERT INTO [dbo].[dim_product] (dim_business_id, material_id, size, style_id, color_description, style_name, material_description, type, gender, lifecycle, style_complexity, dim_construction_type_id, is_placeholder, placeholder_level)
    SELECT DISTINCT
        @businessid as dim_business_id,
        dp.material_id  as material_id,
        dp.material_id as size,
        dp.style_id as style_id,
        dp.color_description as color_description,
        dp.style_name as style_name,
        dp.material_description as material_description,
        dp.type as type,
        dp.gender as gender,
        lifecycle as lifecycle,
        style_complexity as style_complexity,
        dim_construction_type_id as dim_construction_type_id,
        1 as is_placeholder,
        'material_id' as placeholder_level
      FROM [dbo].[dim_product] dp
      LEFT OUTER JOIN (SELECT DISTINCT material_id, 1 as flag FROM [dbo].[dim_product] WHERE is_placeholder = 1 AND placeholder_level = 'material_id') pla
        ON dp.material_id = pla.material_id
      WHERE ISNULL(pla.flag, 0) = 0 AND dp.is_placeholder = 0
      ;

      UPDATE dp
      SET
          dp.style_id = mat.dim_product_style_id,
          dp.style_name = prio.dim_product_style_name,
          dp.color_description = mat.dim_product_color_description,
          dp.material_description = mat.dim_product_material_description,
          dp.type = mat.dim_product_material_type,
          dp.gender = mat.dim_product_gender,
          dp.style_complexity = prio.dim_product_style_complexity,
          dp.dim_construction_type_id = cons.id,
          dp.lifecycle = prio.dim_product_lifecycle
      FROM [dbo].[dim_product] dp
      INNER JOIN [dbo].[staging_pdas_footwear_vans_material_master] mat ON dp.material_id = mat.dim_product_material_id
      INNER JOIN [dbo].[staging_pdas_footwear_vans_priority_list] prio ON dp.material_id = prio.dim_product_material_id
      INNER JOIN [dbo].[dim_construction_type] cons ON prio.dim_construction_type_name = cons.name
      WHERE dp.is_placeholder = 1 AND dp.placeholder_level = 'material_id'
      ;

    -- Level Style

    INSERT INTO [dbo].[dim_product] (dim_business_id, material_id, size, style_id, color_description, style_name, material_description, type, gender, lifecycle, style_complexity, dim_construction_type_id, is_placeholder, placeholder_level)
    SELECT DISTINCT
        @businessid as dim_business_id,
        dp.style_id  as material_id,
        dp.style_id as size,
        dp.style_id as style_id,
        dp.style_id as color_description,
        dp.style_id as style_name,
        dp.style_id as material_description,
        dp.style_id as type,
        dp.style_id as gender,
        dp.style_id as lifecycle,
        dp.style_id as style_complexity,
        1 as dim_construction_type_id,
        1 as is_placeholder,
        'style_id' as placeholder_level
      FROM
		[dbo].[dim_product] dp
		LEFT OUTER JOIN (SELECT DISTINCT style_id, 1 as flag FROM [dbo].[dim_product] WHERE is_placeholder = 1 AND placeholder_level = 'style_id') pla
			ON dp.style_id = pla.style_id
		LEFT OUTER JOIN (SELECT id, material_id, size FROM [dbo].[dim_product]) dp_test
			ON	dp.material_id = dp_test.material_id
				AND dp.size = dp_test.size
      WHERE
		ISNULL(pla.flag, 0) = 0 AND
		ISNULL(dp_test.id, 0) = 0 AND
		dp.is_placeholder = 0
      ;

      -- Level Style Complexity

      INSERT INTO [dbo].[dim_product] (dim_business_id, material_id, size, style_id, color_description, style_name, material_description, type, gender, lifecycle, style_complexity, dim_construction_type_id, is_placeholder, placeholder_level)
      SELECT DISTINCT
          @businessid as dim_business_id,
          dp.style_complexity  as material_id,
          dp.style_complexity as size,
          dp.style_complexity as style_id,
          dp.style_complexity as color_description,
          dp.style_complexity as style_name,
          dp.style_complexity as material_description,
          dp.style_complexity as type,
          dp.style_complexity as gender,
          dp.style_complexity as lifecyle,
          dp.style_complexity as style_complexity,
          1 as dim_construction_type_id,
          1 as is_placeholder,
          'style_complexity' as placeholder_level
        FROM
			[dbo].[dim_product] dp
			LEFT OUTER JOIN (SELECT DISTINCT style_complexity, 1 as flag FROM [dbo].[dim_product] WHERE is_placeholder = 1 AND placeholder_level = 'style_complexity') pla
				ON dp.style_complexity = pla.style_complexity
        WHERE ISNULL(pla.flag, 0) = 0 AND dp.is_placeholder = 0
        ;


        -- Level Construction Type

        INSERT INTO [dbo].[dim_product] (dim_business_id, material_id, size, style_id, color_description, style_name, material_description, type, gender, lifecycle, style_complexity, dim_construction_type_id, is_placeholder, placeholder_level)
        SELECT DISTINCT
            @businessid as dim_business_id,
            cons.name as material_id,
            cons.name as size,
            cons.name as style_id,
            cons.name as color_description,
            cons.name as style_name,
            cons.name as material_description,
            cons.name as type,
            cons.name as gender,
            cons.name as lifecyle,
            cons.name as style_complexity,
            dp.dim_construction_type_id as dim_construction_type_id,
            1 as is_placeholder,
            'dim_construction_type_id' as placeholder_level
          FROM
			[dbo].[dim_product] dp
			  INNER JOIN [dbo].[dim_construction_type] cons ON dp.dim_construction_type_id = cons.id
			  LEFT OUTER JOIN (SELECT DISTINCT dim_construction_type_id, 1 as flag FROM [dbo].[dim_product] WHERE is_placeholder = 1 AND placeholder_level = 'dim_construction_type_id') pla
				ON dp.dim_construction_type_id = pla.dim_construction_type_id
          WHERE
			ISNULL(pla.flag, 0) = 0 AND dp.is_placeholder = 0
          ;

    -- Level Gender

    INSERT INTO [dbo].[dim_product] (dim_business_id, material_id, size, style_id, color_description, style_name, material_description, type, gender, lifecycle, style_complexity, dim_construction_type_id, is_placeholder, placeholder_level)
    SELECT DISTINCT
        @businessid as dim_business_id,
        dp.gender  as material_id,
        dp.gender as size,
        dp.gender as style_id,
        dp.gender as color_description,
        dp.gender as style_name,
        dp.gender as material_description,
        dp.gender as type,
        dp.gender as gender,
        dp.gender as lifecyle,
        dp.gender as style_complexity,
        1 as dim_construction_type_id,
        1 as is_placeholder,
        'gender' as placeholder_level
    FROM
        [dbo].[dim_product] dp
        LEFT OUTER JOIN (SELECT DISTINCT gender, 1 as flag FROM [dbo].[dim_product] WHERE is_placeholder = 1 AND placeholder_level = 'gender') pla
        ON dp.gender = pla.gender
    WHERE
        ISNULL(pla.flag, 0) = 0 AND dp.is_placeholder = 0
        and dp.gender IS NOT NULL


END

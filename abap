REPORT yn3151367_mmr_matrep NO STANDARD PAGE HEADING.

" Step 1: Create program in SE38
" Name: YN3151367_MMR_MATREP (Y<SAP ID>_MMR_MATREP)
" Title: Material Master Report - Batch View
" Type: Executable Program
" Package: $tmp (local object)

TABLES: mara,
        mcha.

************************************************************************
* TEXT ELEMENTS TO MAINTAIN IN SE38
************************************************************************
* TEXT-T01 = Criteria:
* TEXT-T02 = Select a View:
*
* TEXT-E01 = Invalid Material
* TEXT-E02 = Date specified is in the future, enter a valid date
* TEXT-E03 = Invalid Plant
* TEXT-E04 = No data found
*
* TEXT-H01 = Material Master Report
* TEXT-H02 = Material Batch View
*
* TEXT-C01 = Material
* TEXT-C02 = Plant
* TEXT-C03 = Plant Name
* TEXT-C04 = Batch
* TEXT-C05 = Created On
* TEXT-C06 = Created By
* TEXT-C07 = Changed On
* TEXT-C08 = Changed By
* TEXT-C09 = Material Type
* TEXT-C10 = Material Group
* TEXT-C11 = Industry Sector
* TEXT-C12 = Vendor
*
* SELECTION TEXTS:
* S_MATNR = (Dictionary Reference checked - auto)
* S_ERSDA = (Dictionary Reference checked - auto)
* P_WERKS = (Dictionary Reference checked - auto)
* RB_WRITE = Display report with WRITE
* RB_ALV   = Display report as ALV
* CB_HOTSP = Enable Hotspot on Material

************************************************************************
* NOTE ON MISSING FIELDS
************************************************************************
* The doc (Step 5b) specifies retrieving these fields from MCHA:
*   CHARG, ERSDA, ERNAM, LAEDA, AENAM, BWTAR, BRGEW, NTGEW, GEWEI,
*   VOLUM, VOLEH, LIFNR, LWEDT, HERKL
*
* However, this SAP training system's MCHA table only contains:
*   MANDT, MATNR, WERKS, CHARG, LVORM, ERSDA, ERNAM, AENAM, LAEDA,
*   VERAB, VFDAT, ZUSCH, ZUSTD, ZAEDT, LIFNR, LICHA, VLCHA, VLWRK
*
* The following fields do NOT exist in MCHA or MARA in this system:
*   - BWTAR  (Valuation Type)       -> Column 10: Not available
*   - BRGEW  (Gross Weight)         -> Column 13: Not available
*   - NTGEW  (Net Weight)           -> Column 14: Not available
*   - GEWEI  (Weight Unit)          -> Column 15: Not available
*   - VOLUM  (Volume)               -> Column 16: Not available
*   - VOLEH  (Volume Unit)          -> Column 17: Not available
*   - LWEDT  (Last Goods Receipt)   -> Column 19: Not available
*   - HERKL  (Country of Origin)    -> Column 20: Not available
*
* Therefore the report displays 12 of 20 columns using available fields.
* The doc was likely written for a different SAP system configuration.

************************************************************************
* TYPES
************************************************************************
TYPES: gty_r_matnr TYPE RANGE OF matnr,
       gty_r_ersda TYPE RANGE OF ersda.

" Structure for Step 5b result (JOIN of MARA + MCHA)
" MARA fields: MATNR, MTART, MATKL, MBRSH
" MCHA fields: WERKS, CHARG, ERSDA, ERNAM, LAEDA, AENAM, LIFNR
TYPES: BEGIN OF gty_mara_mcha,
         matnr TYPE mara-matnr,
         mtart TYPE mara-mtart,
         matkl TYPE mara-matkl,
         mbrsh TYPE mara-mbrsh,
         werks TYPE mcha-werks,
         charg TYPE mcha-charg,
         ersda TYPE mcha-ersda,
         ernam TYPE mcha-ernam,
         laeda TYPE mcha-laeda,
         aenam TYPE mcha-aenam,
         lifnr TYPE mcha-lifnr,
       END OF gty_mara_mcha.

" Structure for Step 5d result (MAKT - Material Description)
TYPES: BEGIN OF gty_makt,
         matnr TYPE makt-matnr,
         maktx TYPE makt-maktx,
       END OF gty_makt.

" Structure for Step 5e result (T001W - Plant Name)
TYPES: BEGIN OF gty_t001w,
         werks TYPE t001w-werks,
         name1 TYPE t001w-name1,
       END OF gty_t001w.

" Structure for Step 5f final output (all available columns)
" Column sequence per Report Fields table:
"   Col 1:  Material (MATNR concatenated with MAKTX from MAKT)
"   Col 2:  Plant (WERKS from MCHA)
"   Col 3:  Plant Name (NAME1 from T001W)
"   Col 4:  Batch (CHARG from MCHA)
"   Col 5:  Created On (ERSDA from MCHA) - MM/DD/YYYY format
"   Col 6:  Created By (ERNAM from MCHA)
"   Col 7:  Changed On (LAEDA from MCHA) - MM/DD/YYYY format
"   Col 8:  Changed By (AENAM from MCHA)
"   Col 9:  Material Type (MTART from MARA)
"   Col 10: Valuation Type - NOT AVAILABLE in system (BWTAR)
"   Col 11: Material Group (MATKL from MARA)
"   Col 12: Industry Sector (MBRSH from MARA)
"   Col 13-17: Weight/Volume fields - NOT AVAILABLE in system
"   Col 18: Vendor (LIFNR from MCHA)
"   Col 19-20: LWEDT/HERKL - NOT AVAILABLE in system
TYPES: BEGIN OF gty_final,
         matnr TYPE string,
         werks TYPE mcha-werks,
         name1 TYPE t001w-name1,
         charg TYPE mcha-charg,
         ersda TYPE mcha-ersda,
         ernam TYPE mcha-ernam,
         laeda TYPE mcha-laeda,
         aenam TYPE mcha-aenam,
         mtart TYPE mara-mtart,
         matkl TYPE mara-matkl,
         mbrsh TYPE mara-mbrsh,
         lifnr TYPE mcha-lifnr,
       END OF gty_final.

TYPES: gty_t_final TYPE STANDARD TABLE OF gty_final WITH DEFAULT KEY.

************************************************************************
* Step 2: Selection Screen
************************************************************************
" Block 1: Criteria (TEXT-T01)
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-t01.
  SELECT-OPTIONS:
    s_matnr FOR mara-matnr,          " Select-option: Material
    s_ersda FOR mcha-ersda.           " Select-option: Created On

  PARAMETERS:
    p_werks TYPE mcha-werks.          " Parameter: Plant
SELECTION-SCREEN END OF BLOCK b01.

" Block 2: Select a View (TEXT-T02)
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-t02.
  PARAMETERS:
    rb_write RADIOBUTTON GROUP rb1,            " Display report with WRITE
    rb_alv   RADIOBUTTON GROUP rb1 DEFAULT 'X'," Display report as ALV (default)
    cb_hotsp AS CHECKBOX DEFAULT 'X'.          " Enable Hotspot on Material (default true)
SELECTION-SCREEN END OF BLOCK b02.

************************************************************************
* Global Data for Event Handler (Step 9c)
* Must be declared before lcl_event_handler so the class can access it
************************************************************************
DATA gt_final_ref TYPE gty_t_final.

************************************************************************
* Event Handler Class (Step 9c - Hotspot on Material column)
* When Material is clicked, SET PARAMETER ID 'MAT' and
* CALL TRANSACTION 'MM03' WITH AUTHORITY-CHECK AND SKIP FIRST SCREEN
************************************************************************
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_link_click FOR EVENT link_click OF cl_salv_events_table
        IMPORTING row column.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD on_link_click.
    IF column = 'MATNR'.
      DATA lv_matnr TYPE mara-matnr.
      READ TABLE gt_final_ref INTO DATA(ls_final) INDEX row.
      IF sy-subrc = 0.
        " Extract pure MATNR before the dash (since we concatenated Material - Description)
        DATA(lv_mat_str) = ls_final-matnr.
        SPLIT lv_mat_str AT ' - ' INTO lv_matnr DATA(lv_rest).
        CONDENSE lv_matnr NO-GAPS.
        SET PARAMETER ID 'MAT' FIELD lv_matnr.
        CALL TRANSACTION 'MM03' WITH AUTHORITY-CHECK AND SKIP FIRST SCREEN.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

************************************************************************
* Step 3: Model Class - Definition
* Define STATIC method for each validation in PUBLIC SECTION.
* Use method parameter to import the select-option or parameter.
*
* Step 5: INSTANCE method to retrieve and process data from database.
************************************************************************
CLASS lcl_model DEFINITION.
  PUBLIC SECTION.
    " Step 3: Static validation methods
    CLASS-METHODS:
      validate_material
        IMPORTING
          it_matnr TYPE gty_r_matnr,

      validate_created_on
        IMPORTING
          it_ersda TYPE gty_r_ersda,

      validate_plant
        IMPORTING
          iv_werks TYPE werks_d.

    " Step 5: Instance method to retrieve data
    METHODS:
      retrieve_data
        IMPORTING
          it_matnr TYPE gty_r_matnr
          it_ersda TYPE gty_r_ersda
          iv_werks TYPE werks_d
        EXPORTING
          et_final TYPE gty_t_final.

    " Hint from doc: declare internal tables in class definition
    " so they are accessible to every method inside the class
    DATA: gt_mara_mcha TYPE STANDARD TABLE OF gty_mara_mcha,
          gt_makt      TYPE STANDARD TABLE OF gty_makt,
          gt_t001w     TYPE STANDARD TABLE OF gty_t001w,
          gt_final     TYPE gty_t_final.
ENDCLASS.

************************************************************************
* Step 7: View Class - Definition
* Create INSTANCE method to display report using WRITE.
* Create another INSTANCE method to display report using SALV.
* Import the final internal table from previous method.
************************************************************************
CLASS lcl_view DEFINITION.
  PUBLIC SECTION.
    METHODS:
      display_write
        IMPORTING
          it_final TYPE gty_t_final,
      display_alv
        IMPORTING
          iv_hotspot TYPE abap_bool
        CHANGING
          ct_final TYPE gty_t_final.
ENDCLASS.

************************************************************************
* Model Class - Implementation
************************************************************************
CLASS lcl_model IMPLEMENTATION.

  " Step 3a: Validate Material Input
  " (i) When value entered, check if value exists in MARA.
  "     If not, display error 'Invalid Material' on status bar.
  "     Selection screen must still be visible. (MESSAGE TYPE 'E')
  " (ii) When no value entered, no validation needed.
  METHOD validate_material.
    IF it_matnr IS NOT INITIAL.
      SELECT SINGLE matnr
        FROM mara
        INTO @DATA(lv_matnr)
        WHERE matnr IN @it_matnr.
      IF sy-subrc <> 0.
        MESSAGE TEXT-e01 TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  " Step 3b: Validate Created On Input
  " (i) When value entered is greater than current date (sy-datum),
  "     display error 'Date specified is in the future, enter a valid date'.
  " (ii) When no value entered, no validation needed.
  METHOD validate_created_on.
    IF it_ersda IS NOT INITIAL.
      DATA(lv_date) = it_ersda[ 1 ]-low.
      IF lv_date > sy-datum.
        MESSAGE TEXT-e02 TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  " Step 3c: Validate Plant Input
  " (i) When value entered, check if value exists in T001W.
  "     If not, display error 'Invalid Plant' on status bar.
  "     Selection screen must still be visible and editable.
  " (ii) When no value entered, no validation needed.
  METHOD validate_plant.
    IF iv_werks IS NOT INITIAL.
      SELECT SINGLE werks
        FROM t001w
        INTO @DATA(lv_werks)
        WHERE werks = @iv_werks.
      IF sy-subrc <> 0.
        MESSAGE TEXT-e03 TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  " Step 5: Retrieve and process data from database
  METHOD retrieve_data.

    " Step 5a: Create internal table with data dictionary type RSELOPTION.
    " Use ABAP 740 syntax, append one entry where
    " SIGN = 'I', OPTION = 'EQ', LOW = screen criteria plant.
    DATA lt_werks TYPE rseloption.
    IF iv_werks IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = iv_werks ) TO lt_werks.
    ENDIF.

    " Step 5b: Get fields from MARA and MCHA using JOIN.
    " Join on MATNR (primary key = foreign key).
    " Filter with screen criteria material and created on (if user entered values).
    " Filter with internal table from 5a for plant (if user entered values).
    "
    " MARA fields: MATNR, MTART, MATKL, MBRSH
    " MCHA fields: WERKS, CHARG, ERSDA, ERNAM, LAEDA, AENAM, LIFNR
    "
    " NOTE: Doc also specifies BWTAR, BRGEW, NTGEW, GEWEI, VOLUM, VOLEH,
    " LWEDT, HERKL from MCHA but these fields do not exist in this
    " system's MCHA or MARA tables. See note at top of program.
    SELECT mara~matnr, mara~mtart, mara~matkl, mara~mbrsh,
           mcha~werks, mcha~charg, mcha~ersda, mcha~ernam,
           mcha~laeda, mcha~aenam, mcha~lifnr
      FROM mara
      INNER JOIN mcha ON mara~matnr = mcha~matnr
      INTO TABLE @gt_mara_mcha
      WHERE mara~matnr IN @it_matnr
        AND mcha~ersda IN @it_ersda
        AND mcha~werks IN @lt_werks.

    " Sort internal table based on its primary keys
    SORT gt_mara_mcha BY matnr werks charg.

    " If there is no data returned, issue error message 'No data found.'
    " Sample syntax: MESSAGE TEXT-xxx TYPE 'S' DISPLAY LIKE 'E'
    " LEAVE LIST-PROCESSING
    IF gt_mara_mcha IS INITIAL.
      MESSAGE TEXT-e04 TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
      RETURN.
    ENDIF.

    " Step 5c: Check if internal table from previous step has entries
    " before proceeding to next steps.
    CHECK gt_mara_mcha IS NOT INITIAL.

    " Step 5d: Get MATNR, MAKTX from MAKT using FOR ALL ENTRIES
    " in internal table retrieved from 5b.
    " Similar field for FOR ALL ENTRIES: MATNR
    " Filter field SPRAS with SY-LANGU. Default system language is 'EN'.
    " Sort the internal table based on primary keys.
    SELECT matnr, maktx
      FROM makt
      INTO TABLE @gt_makt
      FOR ALL ENTRIES IN @gt_mara_mcha
      WHERE matnr = @gt_mara_mcha-matnr
        AND spras = @sy-langu.

    SORT gt_makt BY matnr.

    " Step 5e: Get WERKS, NAME1 from T001W using FOR ALL ENTRIES
    " in internal table retrieved from 5b.
    " Similar field for FOR ALL ENTRIES: WERKS
    " Doc says filter SPRAS with SY-LANGU, but T001W does not have
    " a SPRAS field in this system. Filter omitted.
    " Sort the internal table based on primary keys.
    SELECT werks, name1
      FROM t001w
      INTO TABLE @gt_t001w
      FOR ALL ENTRIES IN @gt_mara_mcha
      WHERE werks = @gt_mara_mcha-werks.

    SORT gt_t001w BY werks.

    " Step 5f: Use LOOP and READ to transfer all field values retrieved
    " from multiple database tables from previous steps into a final
    " internal table. In Material field/column, concatenate the Material
    " and Material Description separated with dash.
    DATA ls_final TYPE gty_final.

    LOOP AT gt_mara_mcha INTO DATA(ls_mara_mcha).
      CLEAR ls_final.

      " READ material description from MAKT
      READ TABLE gt_makt INTO DATA(ls_makt)
        WITH KEY matnr = ls_mara_mcha-matnr BINARY SEARCH.

      " Concatenate: Material - Description
      IF sy-subrc = 0.
        ls_final-matnr = ls_mara_mcha-matnr && ' - ' && ls_makt-maktx.
      ELSE.
        ls_final-matnr = ls_mara_mcha-matnr.
      ENDIF.

      " READ plant name from T001W
      READ TABLE gt_t001w INTO DATA(ls_t001w)
        WITH KEY werks = ls_mara_mcha-werks BINARY SEARCH.

      IF sy-subrc = 0.
        ls_final-name1 = ls_t001w-name1.
      ENDIF.

      " Transfer remaining fields
      ls_final-werks = ls_mara_mcha-werks.
      ls_final-charg = ls_mara_mcha-charg.
      ls_final-ersda = ls_mara_mcha-ersda.
      ls_final-ernam = ls_mara_mcha-ernam.
      ls_final-laeda = ls_mara_mcha-laeda.
      ls_final-aenam = ls_mara_mcha-aenam.
      ls_final-mtart = ls_mara_mcha-mtart.
      ls_final-matkl = ls_mara_mcha-matkl.
      ls_final-mbrsh = ls_mara_mcha-mbrsh.
      ls_final-lifnr = ls_mara_mcha-lifnr.

      APPEND ls_final TO gt_final.
    ENDLOOP.

    " Step 5g: Export the final internal table.
    et_final = gt_final.

  ENDMETHOD.

ENDCLASS.

************************************************************************
* View Class - Implementation (Steps 7, 8, 9)
************************************************************************
CLASS lcl_view IMPLEMENTATION.

  " Step 7: WRITE display method
  " 7a: Follow column label/description from Report Fields table
  " 7b: Follow column sequence
  " 7c: Write the column headers/descriptions first before writing data
  METHOD display_write.
    " Date in MM/DD/YYYY format, Time in military format (HH:MM:SS)
    DATA(lv_exec_date) = |{ sy-datum+4(2) }/{ sy-datum+6(2) }/{ sy-datum(4) }|.
    DATA(lv_exec_time) = |{ sy-uzeit(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }|.

    " Header (matching ALV subheading format)
    WRITE: / TEXT-h01.
    WRITE: / TEXT-h02.
    WRITE: / |Executed by: { sy-uname }|.
    WRITE: / |Executed on: { lv_exec_date } - { lv_exec_time }|.
    SKIP.

    " 7c: Column headers first (9i: text elements, not hardcoded)
    WRITE: / TEXT-c01, 55 TEXT-c02, 65 TEXT-c03, 95 TEXT-c04,
             110 TEXT-c05, 125 TEXT-c06, 140 TEXT-c07, 155 TEXT-c08,
             170 TEXT-c09, 185 TEXT-c10, 200 TEXT-c11, 215 TEXT-c12.
    ULINE.

    " Write data rows
    LOOP AT it_final INTO DATA(ls_final).

      DATA: lv_ersda TYPE string,
            lv_laeda TYPE string.

      " Format dates to MM/DD/YYYY (doc requirement for cols 5, 7)
      IF ls_final-ersda IS NOT INITIAL.
        lv_ersda = |{ ls_final-ersda+4(2) }/{ ls_final-ersda+6(2) }/{ ls_final-ersda(4) }|.
      ELSE.
        CLEAR lv_ersda.
      ENDIF.

      IF ls_final-laeda IS NOT INITIAL.
        lv_laeda = |{ ls_final-laeda+4(2) }/{ ls_final-laeda+6(2) }/{ ls_final-laeda(4) }|.
      ELSE.
        CLEAR lv_laeda.
      ENDIF.

      WRITE: / ls_final-matnr, 55 ls_final-werks, 65 ls_final-name1,
               95 ls_final-charg, 110 lv_ersda, 125 ls_final-ernam,
               140 lv_laeda, 155 ls_final-aenam, 170 ls_final-mtart,
               185 ls_final-matkl, 200 ls_final-mbrsh, 215 ls_final-lifnr.
    ENDLOOP.
  ENDMETHOD.

  " Step 7 + Step 9: ALV display method
  " 7d: For ALV, use SALV. See YSAMPLE_OO_SALV for sample syntax.
  " Note: TRY CATCH ENDTRY is important to prevent runtime errors.
  METHOD display_alv.

    DATA lo_alv TYPE REF TO cl_salv_table.

    TRY.
        " Basic SALV Syntax (from doc page 15):
        " cl_salv_table=>factory(
        "   IMPORTING r_salv_table = DATA(lo_alv)
        "   CHANGING  t_table      = lt_final_output ).
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = lo_alv
          CHANGING
            t_table = ct_final ).

        " 9a: Set main heading: Material Master Report
        DATA(lo_display) = lo_alv->get_display_settings( ).
        lo_display->set_list_header( TEXT-h01 ).

        " 9g: Set zebra stripes layout
        lo_display->set_striped_pattern( abap_true ).

        " 9d: Enable default ALV toolbar functions
        DATA(lo_functions) = lo_alv->get_functions( ).
        lo_functions->set_all( abap_true ).

        DATA(lo_columns) = lo_alv->get_columns( ).

        " 9f: Optimize column width
        lo_columns->set_optimize( abap_true ).

        " 9i: Field/Column descriptions should be in text elements
        "     and not hardcoded.
        DATA lo_column TYPE REF TO cl_salv_column_table.

        " Col 1: Material (MATNR - MAKTX concatenated)
        " 9e: Set GREEN colour for Material column
        " 9c: Add hotspot on Material column (when checkbox is marked)
        lo_column ?= lo_columns->get_column( 'MATNR' ).
        lo_column->set_long_text( TEXT-c01 ).
        lo_column->set_medium_text( TEXT-c01 ).
        lo_column->set_short_text( TEXT-c01 ).
        lo_column->set_color( VALUE lvc_s_colo( col = 5 ) ).
        IF iv_hotspot = abap_true.
          lo_column->set_cell_type( if_salv_c_cell_type=>hotspot ).
        ENDIF.

        " Col 2: Plant
        lo_column ?= lo_columns->get_column( 'WERKS' ).
        lo_column->set_long_text( TEXT-c02 ).
        lo_column->set_medium_text( TEXT-c02 ).
        lo_column->set_short_text( TEXT-c02 ).

        " Col 3: Plant Name
        lo_column ?= lo_columns->get_column( 'NAME1' ).
        lo_column->set_long_text( TEXT-c03 ).
        lo_column->set_medium_text( TEXT-c03 ).
        lo_column->set_short_text( TEXT-c03 ).

        " Col 4: Batch
        lo_column ?= lo_columns->get_column( 'CHARG' ).
        lo_column->set_long_text( TEXT-c04 ).
        lo_column->set_medium_text( TEXT-c04 ).
        lo_column->set_short_text( TEXT-c04 ).

        " Col 5: Created On (MM/DD/YYYY format)
        lo_column ?= lo_columns->get_column( 'ERSDA' ).
        lo_column->set_long_text( TEXT-c05 ).
        lo_column->set_medium_text( TEXT-c05 ).
        lo_column->set_short_text( TEXT-c05 ).

        " Col 6: Created By
        lo_column ?= lo_columns->get_column( 'ERNAM' ).
        lo_column->set_long_text( TEXT-c06 ).
        lo_column->set_medium_text( TEXT-c06 ).
        lo_column->set_short_text( TEXT-c06 ).

        " Col 7: Changed On (MM/DD/YYYY format)
        lo_column ?= lo_columns->get_column( 'LAEDA' ).
        lo_column->set_long_text( TEXT-c07 ).
        lo_column->set_medium_text( TEXT-c07 ).
        lo_column->set_short_text( TEXT-c07 ).

        " Col 8: Changed By
        lo_column ?= lo_columns->get_column( 'AENAM' ).
        lo_column->set_long_text( TEXT-c08 ).
        lo_column->set_medium_text( TEXT-c08 ).
        lo_column->set_short_text( TEXT-c08 ).

        " Col 9: Material Type
        lo_column ?= lo_columns->get_column( 'MTART' ).
        lo_column->set_long_text( TEXT-c09 ).
        lo_column->set_medium_text( TEXT-c09 ).
        lo_column->set_short_text( TEXT-c09 ).

        " Col 10: Material Group
        " (Skipped Col 10 Valuation Type - BWTAR not in system MCHA)
        lo_column ?= lo_columns->get_column( 'MATKL' ).
        lo_column->set_long_text( TEXT-c10 ).
        lo_column->set_medium_text( TEXT-c10 ).
        lo_column->set_short_text( TEXT-c10 ).

        " Col 11: Industry Sector
        lo_column ?= lo_columns->get_column( 'MBRSH' ).
        lo_column->set_long_text( TEXT-c11 ).
        lo_column->set_medium_text( TEXT-c11 ).
        lo_column->set_short_text( TEXT-c11 ).

        " Col 12: Vendor
        " (Skipped Cols 13-17: BRGEW, NTGEW, GEWEI, VOLUM, VOLEH
        "  not in system MCHA)
        lo_column ?= lo_columns->get_column( 'LIFNR' ).
        lo_column->set_long_text( TEXT-c12 ).
        lo_column->set_medium_text( TEXT-c12 ).
        lo_column->set_short_text( TEXT-c12 ).

        " (Skipped Cols 19-20: LWEDT, HERKL not in system MCHA)

        " 9h: Add ALV sorting. Follow sorting criteria from Report Fields.
        " ASC = Ascending, DESC = Descending.
        " MATNR: 1 ASC, WERKS: 2 ASC, CHARG: 3 ASC, ERSDA: 4 DESC
        DATA(lo_sorts) = lo_alv->get_sorts( ).
        lo_sorts->add_sort( columnname = 'MATNR' position = 1 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'WERKS' position = 2 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'CHARG' position = 3 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'ERSDA' position = 4 sequence = if_salv_c_sort=>sort_down ).

        " 9b: Add subheading below:
        "   Material Batch View
        "   Executed by: <sy-uname>
        "   Executed on: <sy-datum> - <sy-uzeit>
        " Date in MM/DD/YYYY format. Time in military format (HH:MM:SS).
        " (e.g., 04/28/2023 - 14:00:01)
        DATA(lo_header) = NEW cl_salv_form_layout_grid( ).
        DATA(lv_date) = |{ sy-datum+4(2) }/{ sy-datum+6(2) }/{ sy-datum(4) }|.
        DATA(lv_time) = |{ sy-uzeit(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }|.
        lo_header->create_label( row = 1 column = 1 )->set_text( TEXT-h02 ).
        lo_header->create_label( row = 2 column = 1 )->set_text( |Executed by: { sy-uname }| ).
        lo_header->create_label( row = 3 column = 1 )->set_text( |Executed on: { lv_date } - { lv_time }| ).
        lo_alv->set_top_of_list( lo_header ).

        " 9c: Register hotspot event handler
        " Enable hotspot when checkbox is marked.
        IF iv_hotspot = abap_true.
          SET HANDLER lcl_event_handler=>on_link_click FOR lo_alv->get_event( ).
        ENDIF.

        " lo_alv->display( ). "Display the ALV Grid
        lo_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg TYPE 'E'.
      CATCH cx_salv_not_found INTO DATA(lx_not_found).
        MESSAGE lx_not_found TYPE 'E'.
      CATCH cx_salv_data_error INTO DATA(lx_data).
        MESSAGE lx_data TYPE 'E'.
      CATCH cx_salv_existing INTO DATA(lx_existing).
        MESSAGE lx_existing TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

************************************************************************
* Step 4: AT SELECTION-SCREEN
* After SELECTION-SCREEN blocks, add event block AT SELECTION-SCREEN.
* Call the STATIC methods created earlier to validate screen inputs.
************************************************************************
AT SELECTION-SCREEN.
  lcl_model=>validate_material( it_matnr = s_matnr[] ).
  lcl_model=>validate_created_on( it_ersda = s_ersda[] ).
  lcl_model=>validate_plant( iv_werks = p_werks ).

************************************************************************
* Step 6: START-OF-SELECTION
* Create an object or instance of the model class.
* Call the method that retrieves data.
*
* Step 8: Create object or instance of the view class.
* Call method for WRITE when 'Display report with WRITE' is selected.
* Call method for SALV when 'Display report as ALV' is selected.
************************************************************************
START-OF-SELECTION.

  " Step 6: Create model instance and retrieve data
  DATA(lo_model) = NEW lcl_model( ).
  DATA gt_final TYPE gty_t_final.

  lo_model->retrieve_data(
    EXPORTING
      it_matnr = s_matnr[]
      it_ersda = s_ersda[]
      iv_werks = p_werks
    IMPORTING
      et_final = gt_final ).

  " 9j: Don't display ALV output if there are no data present.
  CHECK gt_final IS NOT INITIAL.

  " Set global reference for event handler (Step 9c)
  gt_final_ref = gt_final.

  " Step 8: Create view instance and display
  DATA(lo_view) = NEW lcl_view( ).

  IF rb_write = abap_true.
    lo_view->display_write( it_final = gt_final ).
  ELSE.
    lo_view->display_alv(
      EXPORTING
        iv_hotspot = COND #( WHEN cb_hotsp = abap_true THEN abap_true ELSE abap_false )
      CHANGING
        ct_final = gt_final ).
  ENDIF.

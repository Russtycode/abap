REPORT yn3151367_mmr_matrep.

" Step 1: Program YN3151367_MMR_MATREP
" Title: Material Master Report - Batch View
" Type: Executable Program | Package: $tmp

TABLES: mara, mcha.

************************************************************************
* NOTE: Doc Step 5b says get BRGEW, NTGEW, GEWEI, VOLUM, VOLEH from
* MCHA, but in this system they exist in MARA. We retrieve them from
* MARA instead. All other fields match the doc's specified tables.
************************************************************************

************************************************************************
* TYPES
************************************************************************
TYPES: gty_r_matnr TYPE RANGE OF matnr,
       gty_r_ersda TYPE RANGE OF ersda.

" Step 5b result structure (JOIN of MARA + MCHA)
" From MARA: MATNR, MTART, MATKL, MBRSH, BRGEW, NTGEW, GEWEI, VOLUM, VOLEH
" From MCHA: WERKS, CHARG, ERSDA, ERNAM, LAEDA, AENAM, BWTAR, LIFNR, LWEDT, HERKL
TYPES: BEGIN OF gty_mara_mcha,
         matnr TYPE mara-matnr,
         mtart TYPE mara-mtart,
         matkl TYPE mara-matkl,
         mbrsh TYPE mara-mbrsh,
         brgew TYPE mara-brgew,
         ntgew TYPE mara-ntgew,
         gewei TYPE mara-gewei,
         volum TYPE mara-volum,
         voleh TYPE mara-voleh,
         werks TYPE mcha-werks,
         charg TYPE mcha-charg,
         ersda TYPE mcha-ersda,
         ernam TYPE mcha-ernam,
         laeda TYPE mcha-laeda,
         aenam TYPE mcha-aenam,
         bwtar TYPE mcha-bwtar,
         lifnr TYPE mcha-lifnr,
         lwedt TYPE mcha-lwedt,
         herkl TYPE mcha-herkl,
       END OF gty_mara_mcha.

" Step 5d result (MAKT)
TYPES: BEGIN OF gty_makt,
         matnr TYPE makt-matnr,
         maktx TYPE makt-maktx,
       END OF gty_makt.

" Step 5e result (T001W)
TYPES: BEGIN OF gty_t001w,
         werks TYPE t001w-werks,
         name1 TYPE t001w-name1,
       END OF gty_t001w.

" Step 5f final output - all 20 columns per Report Fields table
TYPES: BEGIN OF gty_final,
         matnr TYPE string,          " Col 1:  Material - Description
         werks TYPE mcha-werks,      " Col 2:  Plant
         name1 TYPE t001w-name1,     " Col 3:  Plant Name
         charg TYPE mcha-charg,      " Col 4:  Batch
         ersda TYPE mcha-ersda,      " Col 5:  Created On
         ernam TYPE mcha-ernam,      " Col 6:  Created By
         laeda TYPE mcha-laeda,      " Col 7:  Changed On
         aenam TYPE mcha-aenam,      " Col 8:  Changed By
         mtart TYPE mara-mtart,      " Col 9:  Material Type
         bwtar TYPE mcha-bwtar,      " Col 10: Valuation Type
         matkl TYPE mara-matkl,      " Col 11: Material Group
         mbrsh TYPE mara-mbrsh,      " Col 12: Industry Sector
         brgew TYPE mara-brgew,      " Col 13: Gross Weight
         ntgew TYPE mara-ntgew,      " Col 14: Net Weight
         gewei TYPE mara-gewei,      " Col 15: Weight Unit
         volum TYPE mara-volum,      " Col 16: Volume
         voleh TYPE mara-voleh,      " Col 17: Volume Unit
         lifnr TYPE mcha-lifnr,     " Col 18: Vendor
         lwedt TYPE mcha-lwedt,      " Col 19: Last Goods Receipt
         herkl TYPE mcha-herkl,      " Col 20: Country of Origin
       END OF gty_final.

TYPES: gty_t_final TYPE STANDARD TABLE OF gty_final WITH DEFAULT KEY.

************************************************************************
* Step 2: Selection Screen
************************************************************************
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-t01.
  SELECT-OPTIONS: s_matnr FOR mara-matnr,
                  s_ersda FOR mcha-ersda.
  PARAMETERS:     p_werks TYPE mcha-werks.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-t02.
  PARAMETERS: rb_write RADIOBUTTON GROUP rb1,
              rb_alv   RADIOBUTTON GROUP rb1 DEFAULT 'X'.
  PARAMETERS: cb_hotsp AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b02.

************************************************************************
* Global Data for Event Handler (Step 9c)
************************************************************************
DATA gt_final_ref TYPE gty_t_final.

************************************************************************
* Event Handler Class (Step 9c)
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
* Step 3 + 5: Model Class - Definition
************************************************************************
CLASS lcl_model DEFINITION.
  PUBLIC SECTION.
    " Step 3: Static validation methods
    CLASS-METHODS:
      validate_material
        IMPORTING it_matnr TYPE gty_r_matnr,
      validate_created_on
        IMPORTING it_ersda TYPE gty_r_ersda,
      validate_plant
        IMPORTING iv_werks TYPE werks_d.

    " Step 5: Instance method
    METHODS:
      retrieve_data
        IMPORTING it_matnr TYPE gty_r_matnr
                  it_ersda TYPE gty_r_ersda
                  iv_werks TYPE werks_d
        EXPORTING et_final TYPE gty_t_final.

    " Hint: Internal tables in class definition
    DATA: gt_mara_mcha TYPE STANDARD TABLE OF gty_mara_mcha,
          gt_makt      TYPE STANDARD TABLE OF gty_makt,
          gt_t001w     TYPE STANDARD TABLE OF gty_t001w,
          gt_final     TYPE gty_t_final.
ENDCLASS.

************************************************************************
* Step 7: View Class - Definition
************************************************************************
CLASS lcl_view DEFINITION.
  PUBLIC SECTION.
    METHODS:
      display_write
        IMPORTING it_final TYPE gty_t_final,
      display_alv
        IMPORTING iv_hotspot TYPE abap_bool
        CHANGING  ct_final   TYPE gty_t_final.
ENDCLASS.

************************************************************************
* Model Class - Implementation
************************************************************************
CLASS lcl_model IMPLEMENTATION.

  " Step 3a: Validate Material
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

  " Step 3b: Validate Created On
  METHOD validate_created_on.
    IF it_ersda IS NOT INITIAL.
      DATA(lv_date) = it_ersda[ 1 ]-low.
      IF lv_date > sy-datum.
        MESSAGE TEXT-e02 TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  " Step 3c: Validate Plant
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

  " Step 5: Retrieve and process data
  METHOD retrieve_data.

    " Step 5a: RSELOPTION for plant with ABAP 740 VALUE syntax
    DATA lt_werks TYPE rseloption.
    IF iv_werks IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = iv_werks ) TO lt_werks.
    ENDIF.

    " Step 5b: JOIN MARA and MCHA on MATNR
    SELECT mara~matnr, mara~mtart, mara~matkl, mara~mbrsh,
           mara~brgew, mara~ntgew, mara~gewei, mara~volum, mara~voleh,
           mcha~werks, mcha~charg, mcha~ersda, mcha~ernam,
           mcha~laeda, mcha~aenam, mcha~bwtar,
           mcha~lifnr, mcha~lwedt, mcha~herkl
      FROM mara
      INNER JOIN mcha ON mara~matnr = mcha~matnr
      INTO TABLE @gt_mara_mcha
      WHERE mara~matnr IN @it_matnr
        AND mcha~ersda IN @it_ersda
        AND mcha~werks IN @lt_werks.

    " Sort by primary keys
    SORT gt_mara_mcha BY matnr werks charg.

    " No data found
    IF gt_mara_mcha IS INITIAL.
      MESSAGE TEXT-e04 TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
      RETURN.
    ENDIF.

    " Step 5c: Check entries exist
    CHECK gt_mara_mcha IS NOT INITIAL.

    " Step 5d: FOR ALL ENTRIES into MAKT, SPRAS = SY-LANGU
    SELECT matnr, maktx
      FROM makt
      INTO TABLE @gt_makt
      FOR ALL ENTRIES IN @gt_mara_mcha
      WHERE matnr = @gt_mara_mcha-matnr
        AND spras = @sy-langu.

    SORT gt_makt BY matnr.

    " Step 5e: FOR ALL ENTRIES into T001W
    SELECT werks, name1
      FROM t001w
      INTO TABLE @gt_t001w
      FOR ALL ENTRIES IN @gt_mara_mcha
      WHERE werks = @gt_mara_mcha-werks.

    SORT gt_t001w BY werks.

    " Step 5f: LOOP and READ, concatenate Material - Description
    DATA ls_final TYPE gty_final.

    LOOP AT gt_mara_mcha INTO DATA(ls_mara_mcha).
      CLEAR ls_final.

      READ TABLE gt_makt INTO DATA(ls_makt)
        WITH KEY matnr = ls_mara_mcha-matnr BINARY SEARCH.

      IF sy-subrc = 0.
        ls_final-matnr = ls_mara_mcha-matnr && ' - ' && ls_makt-maktx.
      ELSE.
        ls_final-matnr = ls_mara_mcha-matnr.
      ENDIF.

      READ TABLE gt_t001w INTO DATA(ls_t001w)
        WITH KEY werks = ls_mara_mcha-werks BINARY SEARCH.

      IF sy-subrc = 0.
        ls_final-name1 = ls_t001w-name1.
      ENDIF.

      ls_final-werks = ls_mara_mcha-werks.
      ls_final-charg = ls_mara_mcha-charg.
      ls_final-ersda = ls_mara_mcha-ersda.
      ls_final-ernam = ls_mara_mcha-ernam.
      ls_final-laeda = ls_mara_mcha-laeda.
      ls_final-aenam = ls_mara_mcha-aenam.
      ls_final-mtart = ls_mara_mcha-mtart.
      ls_final-bwtar = ls_mara_mcha-bwtar.
      ls_final-matkl = ls_mara_mcha-matkl.
      ls_final-mbrsh = ls_mara_mcha-mbrsh.
      ls_final-brgew = ls_mara_mcha-brgew.
      ls_final-ntgew = ls_mara_mcha-ntgew.
      ls_final-gewei = ls_mara_mcha-gewei.
      ls_final-volum = ls_mara_mcha-volum.
      ls_final-voleh = ls_mara_mcha-voleh.
      ls_final-lifnr = ls_mara_mcha-lifnr.
      ls_final-lwedt = ls_mara_mcha-lwedt.
      ls_final-herkl = ls_mara_mcha-herkl.

      APPEND ls_final TO gt_final.
    ENDLOOP.

    " Step 5g: Export
    et_final = gt_final.

  ENDMETHOD.

ENDCLASS.

************************************************************************
* View Class - Implementation (Steps 7 + 9)
************************************************************************
CLASS lcl_view IMPLEMENTATION.

  " Step 7: WRITE display
  " 7c: Write column headers first
  METHOD display_write.
    DATA(lv_exec_date) = |{ sy-datum+4(2) }/{ sy-datum+6(2) }/{ sy-datum(4) }|.
    DATA(lv_exec_time) = |{ sy-uzeit(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }|.

    WRITE: / TEXT-h01.
    WRITE: / TEXT-h02.
    WRITE: / |Executed by: { sy-uname }|.
    WRITE: / |Executed on: { lv_exec_date } - { lv_exec_time }|.
    SKIP.

    " 7a/7b: Column headers in sequence, 9i: text elements
    WRITE: / TEXT-c01, 55 TEXT-c02, 65 TEXT-c03, 95 TEXT-c04,
             110 TEXT-c05, 125 TEXT-c06, 140 TEXT-c07, 155 TEXT-c08,
             170 TEXT-c09, 185 TEXT-c10, 200 TEXT-c11, 215 TEXT-c12,
             230 TEXT-c13, 245 TEXT-c14, 260 TEXT-c15, 275 TEXT-c16,
             290 TEXT-c17, 305 TEXT-c18, 320 TEXT-c19, 340 TEXT-c20.
    ULINE.

    LOOP AT it_final INTO DATA(ls_final).

      DATA: lv_ersda TYPE string,
            lv_laeda TYPE string,
            lv_lwedt TYPE string.

      " MM/DD/YYYY format for date columns (5, 7, 19)
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

      IF ls_final-lwedt IS NOT INITIAL.
        lv_lwedt = |{ ls_final-lwedt+4(2) }/{ ls_final-lwedt+6(2) }/{ ls_final-lwedt(4) }|.
      ELSE.
        CLEAR lv_lwedt.
      ENDIF.

      WRITE: / ls_final-matnr, 55 ls_final-werks, 65 ls_final-name1,
               95 ls_final-charg, 110 lv_ersda, 125 ls_final-ernam,
               140 lv_laeda, 155 ls_final-aenam, 170 ls_final-mtart,
               185 ls_final-bwtar, 200 ls_final-matkl, 215 ls_final-mbrsh,
               230 ls_final-brgew, 245 ls_final-ntgew, 260 ls_final-gewei,
               275 ls_final-volum, 290 ls_final-voleh, 305 ls_final-lifnr,
               320 lv_lwedt, 340 ls_final-herkl.
    ENDLOOP.
  ENDMETHOD.

  " Step 7d + Step 9: ALV display using SALV
  METHOD display_alv.

    DATA lo_alv TYPE REF TO cl_salv_table.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_alv
          CHANGING  t_table      = ct_final ).

        " 9a: Main heading
        DATA(lo_display) = lo_alv->get_display_settings( ).
        lo_display->set_list_header( TEXT-h01 ).

        " 9g: Zebra stripes
        lo_display->set_striped_pattern( abap_true ).

        " 9d: Enable toolbar functions
        DATA(lo_functions) = lo_alv->get_functions( ).
        lo_functions->set_all( abap_true ).

        DATA(lo_columns) = lo_alv->get_columns( ).

        " 9f: Optimize column width
        lo_columns->set_optimize( abap_true ).

        " 9i: Column descriptions in text elements
        DATA lo_column TYPE REF TO cl_salv_column_table.

        " Col 1: Material - 9e: GREEN, 9c: Hotspot
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

        " Col 5: Created On
        lo_column ?= lo_columns->get_column( 'ERSDA' ).
        lo_column->set_long_text( TEXT-c05 ).
        lo_column->set_medium_text( TEXT-c05 ).
        lo_column->set_short_text( TEXT-c05 ).

        " Col 6: Created By
        lo_column ?= lo_columns->get_column( 'ERNAM' ).
        lo_column->set_long_text( TEXT-c06 ).
        lo_column->set_medium_text( TEXT-c06 ).
        lo_column->set_short_text( TEXT-c06 ).

        " Col 7: Changed On
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

        " Col 10: Valuation Type
        lo_column ?= lo_columns->get_column( 'BWTAR' ).
        lo_column->set_long_text( TEXT-c10 ).
        lo_column->set_medium_text( TEXT-c10 ).
        lo_column->set_short_text( TEXT-c10 ).

        " Col 11: Material Group
        lo_column ?= lo_columns->get_column( 'MATKL' ).
        lo_column->set_long_text( TEXT-c11 ).
        lo_column->set_medium_text( TEXT-c11 ).
        lo_column->set_short_text( TEXT-c11 ).

        " Col 12: Industry Sector
        lo_column ?= lo_columns->get_column( 'MBRSH' ).
        lo_column->set_long_text( TEXT-c12 ).
        lo_column->set_medium_text( TEXT-c12 ).
        lo_column->set_short_text( TEXT-c12 ).

        " Col 13: Gross Weight
        lo_column ?= lo_columns->get_column( 'BRGEW' ).
        lo_column->set_long_text( TEXT-c13 ).
        lo_column->set_medium_text( TEXT-c13 ).
        lo_column->set_short_text( TEXT-c13 ).

        " Col 14: Net Weight
        lo_column ?= lo_columns->get_column( 'NTGEW' ).
        lo_column->set_long_text( TEXT-c14 ).
        lo_column->set_medium_text( TEXT-c14 ).
        lo_column->set_short_text( TEXT-c14 ).

        " Col 15: Weight Unit
        lo_column ?= lo_columns->get_column( 'GEWEI' ).
        lo_column->set_long_text( TEXT-c15 ).
        lo_column->set_medium_text( TEXT-c15 ).
        lo_column->set_short_text( TEXT-c15 ).

        " Col 16: Volume
        lo_column ?= lo_columns->get_column( 'VOLUM' ).
        lo_column->set_long_text( TEXT-c16 ).
        lo_column->set_medium_text( TEXT-c16 ).
        lo_column->set_short_text( TEXT-c16 ).

        " Col 17: Volume Unit
        lo_column ?= lo_columns->get_column( 'VOLEH' ).
        lo_column->set_long_text( TEXT-c17 ).
        lo_column->set_medium_text( TEXT-c17 ).
        lo_column->set_short_text( TEXT-c17 ).

        " Col 18: Vendor
        lo_column ?= lo_columns->get_column( 'LIFNR' ).
        lo_column->set_long_text( TEXT-c18 ).
        lo_column->set_medium_text( TEXT-c18 ).
        lo_column->set_short_text( TEXT-c18 ).

        " Col 19: Last Goods Receipt
        lo_column ?= lo_columns->get_column( 'LWEDT' ).
        lo_column->set_long_text( TEXT-c19 ).
        lo_column->set_medium_text( TEXT-c19 ).
        lo_column->set_short_text( TEXT-c19 ).

        " Col 20: Country of Origin
        lo_column ?= lo_columns->get_column( 'HERKL' ).
        lo_column->set_long_text( TEXT-c20 ).
        lo_column->set_medium_text( TEXT-c20 ).
        lo_column->set_short_text( TEXT-c20 ).

        " 9h: Sorting
        DATA(lo_sorts) = lo_alv->get_sorts( ).
        lo_sorts->add_sort( columnname = 'MATNR' position = 1 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'WERKS' position = 2 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'CHARG' position = 3 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'ERSDA' position = 4 sequence = if_salv_c_sort=>sort_down ).

        " 9b: Subheading (MM/DD/YYYY - HH:MM:SS)
        DATA(lo_header) = NEW cl_salv_form_layout_grid( ).
        DATA(lv_date) = |{ sy-datum+4(2) }/{ sy-datum+6(2) }/{ sy-datum(4) }|.
        DATA(lv_time) = |{ sy-uzeit(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }|.
        lo_header->create_label( row = 1 column = 1 )->set_text( TEXT-h02 ).
        lo_header->create_label( row = 2 column = 1 )->set_text( |Executed by: { sy-uname }| ).
        lo_header->create_label( row = 3 column = 1 )->set_text( |Executed on: { lv_date } - { lv_time }| ).
        lo_alv->set_top_of_list( lo_header ).

        " 9c: Hotspot event handler
        IF iv_hotspot = abap_true.
          SET HANDLER lcl_event_handler=>on_link_click FOR lo_alv->get_event( ).
        ENDIF.

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
************************************************************************
AT SELECTION-SCREEN.
  lcl_model=>validate_material( it_matnr = s_matnr[] ).
  lcl_model=>validate_created_on( it_ersda = s_ersda[] ).
  lcl_model=>validate_plant( iv_werks = p_werks ).

************************************************************************
* Steps 6 + 8: START-OF-SELECTION
************************************************************************
START-OF-SELECTION.

  DATA(lo_model) = NEW lcl_model( ).
  DATA gt_final TYPE gty_t_final.

  lo_model->retrieve_data(
    EXPORTING
      it_matnr = s_matnr[]
      it_ersda = s_ersda[]
      iv_werks = p_werks
    IMPORTING
      et_final = gt_final ).

  CHECK gt_final IS NOT INITIAL.

  gt_final_ref = gt_final.

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

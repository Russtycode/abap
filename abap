REPORT yn3151367_mmr_matrep NO STANDARD PAGE HEADING.

"----------------------------------------------------------------------
" Tables
"----------------------------------------------------------------------
TABLES: mara, mcha.

"----------------------------------------------------------------------
" Type Declarations
"----------------------------------------------------------------------
TYPES: gty_r_matnr TYPE RANGE OF matnr,
       gty_r_ersda TYPE RANGE OF ersda.

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

TYPES: BEGIN OF gty_makt,
         matnr TYPE makt-matnr,
         maktx TYPE makt-maktx,
       END OF gty_makt.

TYPES: BEGIN OF gty_t001w,
         werks TYPE t001w-werks,
         name1 TYPE t001w-name1,
       END OF gty_t001w.

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

"----------------------------------------------------------------------
" Global Data for Event Handler
"----------------------------------------------------------------------
DATA gt_final_ref TYPE gty_t_final.

"----------------------------------------------------------------------
" Event Handler Class - Definition (Step 9c)
"----------------------------------------------------------------------
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_link_click FOR EVENT link_click OF cl_salv_events_table
        IMPORTING row column.
ENDCLASS.

"----------------------------------------------------------------------
" Event Handler Class - Implementation
"----------------------------------------------------------------------
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

"----------------------------------------------------------------------
" Model Class - Definition (Steps 3 + 5)
"----------------------------------------------------------------------
CLASS lcl_model DEFINITION.
  PUBLIC SECTION.
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

    METHODS:
      retrieve_data
        IMPORTING
          it_matnr TYPE gty_r_matnr
          it_ersda TYPE gty_r_ersda
          iv_werks TYPE werks_d
        EXPORTING
          et_final TYPE gty_t_final.

    DATA: gt_mara_mcha TYPE STANDARD TABLE OF gty_mara_mcha,
          gt_makt      TYPE STANDARD TABLE OF gty_makt,
          gt_t001w     TYPE STANDARD TABLE OF gty_t001w,
          gt_final     TYPE gty_t_final.
ENDCLASS.

"----------------------------------------------------------------------
" View Class - Definition (Step 7)
"----------------------------------------------------------------------
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

"----------------------------------------------------------------------
" Model Class - Implementation
"----------------------------------------------------------------------
CLASS lcl_model IMPLEMENTATION.

  METHOD validate_material.
    IF it_matnr IS NOT INITIAL.
      SELECT matnr FROM mara
        UP TO 1 ROWS
        INTO @DATA(lv_matnr)
        WHERE matnr IN @it_matnr.
      ENDSELECT.
      IF sy-subrc <> 0.
        MESSAGE TEXT-e01 TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD validate_created_on.
    IF it_ersda IS NOT INITIAL.
      DATA(lv_date) = it_ersda[ 1 ]-low.
      IF lv_date > sy-datum.
        MESSAGE TEXT-e02 TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD validate_plant.
    IF iv_werks IS NOT INITIAL.
      SELECT werks FROM t001w
        UP TO 1 ROWS
        INTO @DATA(lv_werks)
        WHERE werks = @iv_werks.
      ENDSELECT.
      IF sy-subrc <> 0.
        MESSAGE TEXT-e03 TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD retrieve_data.

    " Step 5a - RSELOPTION for plant
    DATA lt_werks TYPE rseloption.
    IF iv_werks IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = iv_werks ) TO lt_werks.
    ENDIF.

    " Step 5b - JOIN MARA and MCHA on MATNR
    SELECT mara~matnr mara~mtart mara~matkl mara~mbrsh
           mcha~werks mcha~charg mcha~ersda mcha~ernam
           mcha~laeda mcha~aenam mcha~lifnr
      FROM mara
      INNER JOIN mcha ON mara~matnr = mcha~matnr
      INTO TABLE gt_mara_mcha
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

    " Step 5c - Check entries exist
    CHECK gt_mara_mcha IS NOT INITIAL.

    " Step 5d - FOR ALL ENTRIES into MAKT
    SELECT matnr maktx
      FROM makt
      INTO TABLE gt_makt
      FOR ALL ENTRIES IN gt_mara_mcha
      WHERE matnr = gt_mara_mcha-matnr
        AND spras = sy-langu.

    SORT gt_makt BY matnr.

    " Step 5e - FOR ALL ENTRIES into T001W
    SELECT werks name1
      FROM t001w
      INTO TABLE gt_t001w
      FOR ALL ENTRIES IN gt_mara_mcha
      WHERE werks = gt_mara_mcha-werks.

    SORT gt_t001w BY werks.

    " Step 5f - LOOP and READ to build final table
    DATA ls_final TYPE gty_final.

    LOOP AT gt_mara_mcha INTO DATA(ls_mara_mcha).
      CLEAR ls_final.

      " READ material description
      READ TABLE gt_makt INTO DATA(ls_makt)
        WITH KEY matnr = ls_mara_mcha-matnr BINARY SEARCH.

      " Concatenate Material - Description
      IF sy-subrc = 0.
        ls_final-matnr = ls_mara_mcha-matnr && ' - ' && ls_makt-maktx.
      ELSE.
        ls_final-matnr = ls_mara_mcha-matnr.
      ENDIF.

      " READ plant name
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
      ls_final-matkl = ls_mara_mcha-matkl.
      ls_final-mbrsh = ls_mara_mcha-mbrsh.
      ls_final-lifnr = ls_mara_mcha-lifnr.

      APPEND ls_final TO gt_final.
    ENDLOOP.

    " Step 5g - Export
    et_final = gt_final.

  ENDMETHOD.

ENDCLASS.

"----------------------------------------------------------------------
" View Class - Implementation (Steps 7 + 9)
"----------------------------------------------------------------------
CLASS lcl_view IMPLEMENTATION.

  METHOD display_write.
    DATA(lv_exec_date) = |{ sy-datum+4(2) }/{ sy-datum+6(2) }/{ sy-datum(4) }|.
    DATA(lv_exec_time) = |{ sy-uzeit(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }|.

    WRITE: / TEXT-h01.
    WRITE: / TEXT-h02.
    WRITE: / |Executed by: { sy-uname }|.
    WRITE: / |Executed on: { lv_exec_date } - { lv_exec_time }|.
    SKIP.

    " 7c - Headers first
    WRITE: / TEXT-c01, 55 TEXT-c02, 65 TEXT-c03, 95 TEXT-c04,
             110 TEXT-c05, 125 TEXT-c06, 140 TEXT-c07, 155 TEXT-c08,
             170 TEXT-c09, 185 TEXT-c10, 200 TEXT-c11, 215 TEXT-c12.
    ULINE.

    LOOP AT it_final INTO DATA(ls_final).

      DATA: lv_ersda TYPE string,
            lv_laeda TYPE string.

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

  METHOD display_alv.

    DATA lo_alv TYPE REF TO cl_salv_table.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = lo_alv
          CHANGING
            t_table = ct_final ).

        " 9a - Main heading
        DATA(lo_display) = lo_alv->get_display_settings( ).
        lo_display->set_list_header( TEXT-h01 ).

        " 9g - Zebra stripes
        lo_display->set_striped_pattern( abap_true ).

        " 9d - Toolbar functions
        DATA(lo_functions) = lo_alv->get_functions( ).
        lo_functions->set_all( abap_true ).

        DATA(lo_columns) = lo_alv->get_columns( ).

        " 9f - Optimize column width
        lo_columns->set_optimize( abap_true ).

        " 9i - Column descriptions in text elements
        DATA lo_column TYPE REF TO cl_salv_column_table.

        " Col 1 - Material
        lo_column ?= lo_columns->get_column( 'MATNR' ).
        lo_column->set_long_text( TEXT-c01 ).
        lo_column->set_medium_text( TEXT-c01 ).
        lo_column->set_short_text( TEXT-c01 ).
        lo_column->set_color( VALUE lvc_s_colo( col = 5 ) ).
        IF iv_hotspot = abap_true.
          lo_column->set_cell_type( if_salv_c_cell_type=>hotspot ).
        ENDIF.

        " Col 2 - Plant
        lo_column ?= lo_columns->get_column( 'WERKS' ).
        lo_column->set_long_text( TEXT-c02 ).
        lo_column->set_medium_text( TEXT-c02 ).
        lo_column->set_short_text( TEXT-c02 ).

        " Col 3 - Plant Name
        lo_column ?= lo_columns->get_column( 'NAME1' ).
        lo_column->set_long_text( TEXT-c03 ).
        lo_column->set_medium_text( TEXT-c03 ).
        lo_column->set_short_text( TEXT-c03 ).

        " Col 4 - Batch
        lo_column ?= lo_columns->get_column( 'CHARG' ).
        lo_column->set_long_text( TEXT-c04 ).
        lo_column->set_medium_text( TEXT-c04 ).
        lo_column->set_short_text( TEXT-c04 ).

        " Col 5 - Created On
        lo_column ?= lo_columns->get_column( 'ERSDA' ).
        lo_column->set_long_text( TEXT-c05 ).
        lo_column->set_medium_text( TEXT-c05 ).
        lo_column->set_short_text( TEXT-c05 ).

        " Col 6 - Created By
        lo_column ?= lo_columns->get_column( 'ERNAM' ).
        lo_column->set_long_text( TEXT-c06 ).
        lo_column->set_medium_text( TEXT-c06 ).
        lo_column->set_short_text( TEXT-c06 ).

        " Col 7 - Changed On
        lo_column ?= lo_columns->get_column( 'LAEDA' ).
        lo_column->set_long_text( TEXT-c07 ).
        lo_column->set_medium_text( TEXT-c07 ).
        lo_column->set_short_text( TEXT-c07 ).

        " Col 8 - Changed By
        lo_column ?= lo_columns->get_column( 'AENAM' ).
        lo_column->set_long_text( TEXT-c08 ).
        lo_column->set_medium_text( TEXT-c08 ).
        lo_column->set_short_text( TEXT-c08 ).

        " Col 9 - Material Type
        lo_column ?= lo_columns->get_column( 'MTART' ).
        lo_column->set_long_text( TEXT-c09 ).
        lo_column->set_medium_text( TEXT-c09 ).
        lo_column->set_short_text( TEXT-c09 ).

        " Col 10 - Material Group
        lo_column ?= lo_columns->get_column( 'MATKL' ).
        lo_column->set_long_text( TEXT-c10 ).
        lo_column->set_medium_text( TEXT-c10 ).
        lo_column->set_short_text( TEXT-c10 ).

        " Col 11 - Industry Sector
        lo_column ?= lo_columns->get_column( 'MBRSH' ).
        lo_column->set_long_text( TEXT-c11 ).
        lo_column->set_medium_text( TEXT-c11 ).
        lo_column->set_short_text( TEXT-c11 ).

        " Col 12 - Vendor
        lo_column ?= lo_columns->get_column( 'LIFNR' ).
        lo_column->set_long_text( TEXT-c12 ).
        lo_column->set_medium_text( TEXT-c12 ).
        lo_column->set_short_text( TEXT-c12 ).

        " 9h - Sorting
        DATA(lo_sorts) = lo_alv->get_sorts( ).
        lo_sorts->add_sort( columnname = 'MATNR' position = 1 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'WERKS' position = 2 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'CHARG' position = 3 sequence = if_salv_c_sort=>sort_up ).
        lo_sorts->add_sort( columnname = 'ERSDA' position = 4 sequence = if_salv_c_sort=>sort_down ).

        " 9b - Subheading
        DATA(lo_header) = NEW cl_salv_form_layout_grid( ).
        DATA(lv_date) = |{ sy-datum+4(2) }/{ sy-datum+6(2) }/{ sy-datum(4) }|.
        DATA(lv_time) = |{ sy-uzeit(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }|.
        lo_header->create_label( row = 1 column = 1 )->set_text( TEXT-h02 ).
        lo_header->create_label( row = 2 column = 1 )->set_text( |Executed by: { sy-uname }| ).
        lo_header->create_label( row = 3 column = 1 )->set_text( |Executed on: { lv_date } - { lv_time }| ).
        lo_alv->set_top_of_list( lo_header ).

        " 9c - Hotspot event handler
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

"----------------------------------------------------------------------
" Selection Screen (Step 2)
"----------------------------------------------------------------------
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

"----------------------------------------------------------------------
" AT SELECTION-SCREEN (Step 4)
"----------------------------------------------------------------------
AT SELECTION-SCREEN.
  lcl_model=>validate_material( it_matnr = s_matnr[] ).
  lcl_model=>validate_created_on( it_ersda = s_ersda[] ).
  lcl_model=>validate_plant( iv_werks = p_werks ).

"----------------------------------------------------------------------
" START-OF-SELECTION (Steps 6 + 8)
"----------------------------------------------------------------------
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
      iv_hotspot = COND #( WHEN cb_hotsp = abap_true THEN abap_true ELSE abap_false )
      CHANGING ct_final = gt_final ).
  ENDIF.

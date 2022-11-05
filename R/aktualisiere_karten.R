#' aktualisiere_karten.R


aktualisiere_karten <- function(wl_url = stimmbezirke_url) {
  # Lies Ortsteil-Daten ein und vergleiche
  neue_orts_df <- lies_gebiet(wl_url) %>% 
    aggregiere_stadtteile() %>% 
    mutate(quorum = ifelse(wahlberechtigt == 0,
                           0,
                           ja / wahlberechtigt * 100)) %>% 
    mutate(status = ifelse(meldungen_anz == 0,
                           "KEINE DATEN",
                           paste0(ifelse(meldungen_anz < meldungen_max,
                                          "TREND ",""),
                                   ifelse(ja < nein,
                                          "NEIN",
                                          ifelse(quorum < 30,
                                                 "JA",
                                                 "JA QUORUM")))
    ))
  alte_orts_df <- hole_letztes_df("daten/ortsteile")
  # Datenstand identisch? Dann brich ab. 
  if(vergleiche_stand(alte_orts_df,neue_orts_df)) {
    return(FALSE) 
  } else {
    # Zeitstempel holen
    archiviere(neue_orts_df,"daten/ortsteile")
    ts <- neue_orts_df %>% pull(zeitstempel) %>% last()
    # Datentabelle übertragen
    dw_data_to_chart(neue_orts_df,choropleth_id)
    dw_data_to_chart(neue_orts_df,symbol_id)
    dw_data_to_chart(neue_orts_df,tabelle_id)
    # Anmerkungen aktualisieren
    wahlberechtigt <- neue_orts_df %>% pull(wahlberechtigt) %>% sum()
    # Prozentsatz ausgezählte Stimmen: abgerundet auf ganze Prozent
    ausgezählt <- floor(wahlberechtigt / ffm_waehler *100)
    annotate_str <- generiere_auszählungsbalken(ausgezählt,
                                                anz = neue_orts_df %>% pull(meldungen_anz) %>% sum(),
                                                max = neue_orts_df %>% pull(meldungen_max) %>% sum(),
                                                ts = ts)
    dw_edit_chart(symbol_id,annotate=annotate_str)
    dw_edit_chart(choropleth_id,annotate=annotate_str)
    dw_edit_chart(tabelle_id,annotate=annotate_str)
    dw_publish_chart(symbol_id)
    dw_publish_chart(choropleth_id)
    dw_publish_chart(tabelle_id)
    return(TRUE)
  }
}
library(readr)
library(lubridate)
library(tidyr)
library(stringr)
library(dplyr)

rm(list=ls())


source("R/messaging.R")
source("R/lies_aktuellen_stand.R")
source("R/aktualisiere_karten.R")

#----aktualisiere_fom() ----


aktualisiere_fom <- function() {
  # Einlesen: Feldmann-o-meter-Daten so far. 
  # Wenn die Daten noch nicht existieren, generiere ein leeres df. 
  if(file.exists("daten/fom_df.rds")) {
    fom_df <- readRDS("daten/fom_df.rds")
  } else {
    # Leeres df mit einer Zeile
    fom_df <- tibble(zeitstempel = as_datetime("2022-11-02 18:00:00 CET"),
                           meldungen_anz = 0,
                           meldungen_max = 575,
                           # Ergebniszellen
                           wahlberechtigt = 0,
                           # Mehr zum Wahlschein hier: https://www.bundeswahlleiter.de/service/glossar/w/wahlscheinvermerk.html
                           waehler_regulaer = 0,
                           waehler_wahlschein = 0,
                           wahler_nv = 0,
                           stimmen = 0,
                           stimmen_wahlschein = 0, 
                           ungueltig = 0,
                           gueltig = 0,
                           ja = 0,
                           nein = 0)
    # SAVE kann man sich schenken; df ist schneller neu erzeugt
    # save(feldmann_df,"daten/feldmann_df.rda")
  }
  # Daten zur Sicherheit sortieren, dann die letzte  Zeile rausziehen
  letzte_fom_df <- fom_df %>% 
    arrange(zeitstempel) %>% 
    tail(1)
  # Neue Daten holen (mit Fehlerbehandlung)
  wahllokale_df <- lies_gebiet(wahllokale_url) 
  neue_fom_df <- wahllokale_df %>% 
    # Namen raus
    select(-name,-nr) %>% 
    # Daten aufsummieren
    summarize(zeitstempel = last(zeitstempel),
      across(2:ncol(.), ~ sum(.,na.rm=T)))
  # Alte und neue Daten identisch? Dann brich ab. 
  if (vergleiche_stand(letzte_fom_df,neue_fom_df)) {
    return(FALSE)
  } else {
    # Archiviere die Rohdaten 
    archiviere(wahllokale_df,"archiv/wahllokale/")
    # Ergänze das fom_df um die neuen Daten und sichere es
    fom_df <- fom_df %>% bind_rows(neue_fom_df)
    saveRDS(fom_df,"daten/fom_df.rds")
    # Bilde das Dataframe
    
    
    
    # Aktualisiere auch die Stadtteilkarten
    aktualisiere_karten()
    # Sende die Daten an Datawrapper und aktualisiere
    fom_dw_df <- fom_df %>% 
      mutate(ausgezählt = wahlberechtigt / ffm_waehler *100) %>% 
      mutate(prozent30 = wahlberechtigt * 0.3) %>% 
      mutate(quorum = ja / wahlberechtigt * 100) %>% 
      select(ausgezählt, wahlberechtigt, ungueltig, ja, nein, quorum, prozent30) %>% 
      # Noch den Endpunkt der 30-Prozent-Linie
      bind_rows(tibble(ausgezählt = 100, prozent30 = ffm_waehler * 0.3))
    dw_data_to_chart(fom_dw_df,fom_id)
    dw_publish_chart(fom_id)
    
    
    
    # Teams-Meldung
    teams_meldung(title="Feldmann-o-meter","Update: ",
                  floor(neue_fom_df$wahlberechtigt/ ffm_waehler * 100),
                  "% ausgezählt")
  }
}


#---- MAIN ----
# Ruft aktualisiere_fom() auf
# (die dann wieder aktualisiere_karten() aufruft)

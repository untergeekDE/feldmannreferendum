library(readr)
library(lubridate)
library(tidyr)
library(stringr)
library(dplyr)

# lies_aktuellen_stand.R
#
# Enthält die Funktion zum Lesen der aktuellen Daten. 

#---- Vorbereitung ----
# Statische Daten einlesen
# (das später durch ein schnelleres .rda ersetzen)


load ("index/index.rda")

# Konfiguration auslesen und in Variablen schreiben
config_df <- read_csv("index/config.csv")
for (i in c(1:nrow(config_df))) {
  # Erzeuge neue Variablen mit den Namen und Werten aus der CSV
  assign(config_df$name[i],
         # Kann man den Wert auch als Zahl lesen?
         # Fieses Regex sucht nach reiner Zahl oder Kommawerten.
         # Keine Exponentialschreibweise!
         ifelse(grepl("^[0-9]*\\.*[0-9]+$",config_df$value[i]),
                # Ist eine Zahl - wandle um
                as.numeric(config_df$value[i]),
                # Keine Zahl - behalte den String
                config_df$value[i]))
}


#---- Daten ins Archiv schreiben oder daraus lesen
archiviere <- function(df,a_directory = "daten/stimmbezirke") {
  if (!dir.exists(a_directory)) {
    dir.create(a_directory)
  }
  write_csv(df,
            paste0(a_directory,"/",
                   # Zeitstempel isolieren und alle Doppelpunkte
                   # durch Bindestriche ersetzen
                   str_replace_all(df %>% pull(zeitstempel) %>% last(),
                               "\\:","_"),
                   ".csv"))
}

hole_letztes_df <- function(a_directory = "daten/stimmbezirke") {
  if (!dir.exists(a_directory)) return(tibble())
  neuester_file <- list.files(a_directory, full.names=TRUE) %>% 
    file.info() %>% 
    # Legt eine Spalte namens path an
    tibble::rownames_to_column(var = "path") %>% 
    arrange(desc(ctime)) %>% 
    head(1) %>% 
    # Pfad wieder rausziehen
    pull(path)
  if (length(neuester_file)==0) {
    # Falls keine Daten archiviert, gibt leeres df zurück
    return(tibble())
  } else {
    return(read_csv(neuester_file))
  }
}


#---- Lese-Funktionen ----
lies_gebiet <- function(stand_url = stimmbezirke_url) {
  ts <- now()
  # Versuch Daten zu lesen - und gib ggf. Warnung oder Fehler zurück
  check = tryCatch(
    { stand_df <- read_delim(stand_url, 
                         delim = ";", escape_double = FALSE, 
                         locale = locale(date_names = "de", 
                                         decimal_mark = ",", 
                                         grouping_mark = "."), 
                         trim_ws = TRUE) %>% 
      # Spalten umbenennen, Zeitstempel-Spalte einfügen
                    mutate(zeitstempel=ts) %>% 
                    select(zeitstempel,
                           nr = `gebiet-nr`,
                           name = `gebiet-name`,
                           meldungen_anz = `anz-schnellmeldungen`,
                           meldungen_max = `max-schnellmeldungen`,
                           # Ergebniszellen
                           wahlberechtigt = A,
                           # Mehr zum Wahlschein hier: https://www.bundeswahlleiter.de/service/glossar/w/wahlscheinvermerk.html
                           waehler_regulaer = A1,
                           waehler_wahlschein = A2,
                           waehler_nv = A3,
                           stimmen = B,
                           stimmen_wahlschein = B1, 
                           ungueltig = C,
                           gueltig = D,
                           ja = D1,
                           nein = D2)
      },
    warning = function(w) {teams_warning(w,title="Feldmann: Datenakquise")},
    error = function(e) {teams_warning(e,title="Feldmann: Datenakquise")})
  # Spalten umbenennen, 
  return(stand_df)
}


# Sind die beiden df abgesehen vom Zeitstempel identisch?
# Funktion vergleicht die numerischen Werte - Spalte für Spalte.
vergleiche_stand <- function(alt_df, neu_df) {
  neu_sum_df <- alt_df %>% summarize_if(is.numeric,sum,na.rm=T)
  alt_sum_df <- neu_df %>% summarize_if(is.numeric,sum,na.rm=T)
  # Unterschiedliche Spaltenzahlen? Dann können sie keine von Finns Männern sein.
  if (length(neu_sum_df) != length(alt_sum_df)) return(FALSE)
  # Differenzen? Dann können sie keine von Finns Männern sein. 
  return(sum(abs(neu_sum_df - alt_sum_df))==0)
}

#' Liest Stimmbezirke, gibt nach Ortsteil aggregierte Daten zurück
#' (hier: kein Sicherheitscheck)
aggregiere_stadtteile <- function(stimmbezirke_df) {
  ortsteile_df <- stimmbezirke_df %>% 
    left_join(zuordnung_stimmbezirke_df,by=c("nr","name")) %>% 
    group_by(ortsteilnr) %>% 
    summarize(zeitstempel = last(zeitstempel),
              across(meldungen_anz:nein, ~ sum(.,na.rm = T))) %>%
    rename(nr = ortsteilnr) %>% 
    # Stadtteilnamen, 2018er Ergebnisse, Geokoordinaten dazuholen
    left_join(stadtteile_df, by="nr") %>% 
    # Nach Ortsteil sortieren
    arrange(nr) %>% 
    # Wichtige Daten für bessere Lesbarkeit nach vorn
    relocate(zeitstempel,nr,name,lon,lat)
    
  # Sicherheitscheck: Warnen, wenn nicht alle Ortsteile zugeordnet
  if (nrow(ortsteile_df) != nrow(stadtteile_df)) teams_warnung("Nicht alle Ortsteile zugeordnet")
  if (nrow(zuordnung_stimmbezirke_df) != length(unique(stimmbezirke_df$nr))) teams_warnung("Nicht alle Stimmbezirke zugeordnet")
  return(ortsteile_df)
}

aggregiere_stadtteile_mit_briefwahl <- function(stimmbezirke_df) {
  ortsteile_df <- stimmbezirke_df %>% 
    left_join(zuordnung_stimmbezirke_df,by=c("nr","name")) %>%
    left_join(opendata_wahllokale_df %>% 
                select (nr = `Bezirk-Nr`,
                        typ = `Bezirk-Art`), by="nr") %>% 
    group_by(ortsteilnr) %>% 
    summarize(zeitstempel = last(zeitstempel),
              # Bool'sche Multiplikation: Wenn Stimmbezirk kein Briefwahlbezirk, 
              # wird mit 0 multipliziert; nur die Briefwahl-Stimmbezirke zählen.
              briefwahl = sum((typ == "B") * stimmen),
              across(meldungen_anz:nein, ~ sum(.,na.rm = T))) %>%
    rename(nr = ortsteilnr) %>% 
    # Stadtteilnamen, 2018er Ergebnisse, Geokoordinaten dazuholen
    left_join(stadtteile_df, by="nr") %>% 
    # Nach Ortsteil sortieren
    arrange(nr) %>% 
    # Wichtige Daten für bessere Lesbarkeit nach vorn
    relocate(zeitstempel,nr,name,lon,lat)
  
  # Sicherheitscheck: Warnen, wenn nicht alle Ortsteile zugeordnet
  if (nrow(ortsteile_df) != nrow(stadtteile_df)) teams_warnung("Nicht alle Ortsteile zugeordnet")
  if (nrow(zuordnung_stimmbezirke_df) != length(unique(stimmbezirke_df$nr))) teams_warnung("Nicht alle Stimmbezirke zugeordnet")
  return(ortsteile_df)
}


# Aggregation auf Wahllokal-Ebene
aggregiere_wahllokale <- function(stimmbezirke_df) {
  wahllokale_df <- stimmbezirke_df %>% 
    # Zuordnung der Stimmbezirke zu Ortsteilen
    left_join(zuordnung_stimmbezirke_df,by=c("nr","name")) %>%
    # Zuordnung der Stimmbezirke zu Wahllokalen über die Stimmbezirks-Nr
    left_join(opendata_wahllokale_df %>% 
                select (nr = `Bezirk-Nr`,
                        typ = `Bezirk-Art`, # W = Wahllokal, B = Bezirk,
                        wl_name = `Wahlraum-Bezeichnung`,
                        adresse = `Wahlraum-Adresse`), 
              by = "nr")  %>% 
    # Stadtteilnamen, 2018er Ergebnisse dazuholen
    left_join(stadtteile_df %>% 
                select(ortsteilnr = nr,
                       ortsteil = name, 
                       wahlberechtigt_2018,
                       waehler_2018,
                       gueltig_2018,
                       feldmann_2018), by="ortsteilnr") %>%
    # Die Bezeichner-Felder nach vorn sortieren
    relocate(zeitstempel, 
             nr,
             name,
             wl_name,
             typ,
             adresse,
             ortsteilnr,
             ortsteil) %>% 
    # Nach Wahllokal aggregieren  
    group_by(wl_name, adresse) %>% 
    summarize(zeitstempel = last(zeitstempel),
              wl_name = last(wl_name),
              typ = last(typ),
              adresse = last(adresse),
              ortsteil = last(ortsteil),
              across(meldungen_anz:nein, ~ sum(.,na.rm = T))) %>%
    # Nach Ortsteil sortieren
    arrange(ortsteil) 
  # Sicherheitscheck: Warnen, wenn nicht alle Wahllokale zugeordnet
  if (nrow(wahllokale_df) != length(unique(opendata_wahllokale_df$`Wahlraum-Bezeichnung`))) teams_warnung("Nicht alle Stimmbezirke zugeordnet")
  return(wahllokale_df)
}



lies_stadtteil_direkt <- function(stand_url = ortsteile_url) {
  neu_df <- lies_gebiet(stand_url)  %>%
    # nr bei Ortsteil-Daten leer/ignorieren
    select(!nr) %>% 
    # Stadtteilnr., Geodaten und Feldmann-2018-Daten reinholen:
    left_join(stadtteile_df, by=c("name")) %>% 
    mutate(trend = (meldungen_anz < meldungen_max),
           quorum_erreicht = (ja >= (wahlberechtigt * 0.3)))
  return(neu_df)
}


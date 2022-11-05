#' generiere_testdaten.R
#' 
#' Macht aus den Templates für Ortsteil- und Wahllokal-Ergebnisse
#' jeweils eine Serie von fiktiven Livedaten, um das Befüllen der
#' Grafiken testen zu können. 
#' 

require(tidyr)
require(dplyr)
require(readr)

# Alles weg, was noch im Speicher rumliegt
rm(list=ls())

source("R/lies_aktuellen_stand.R")

#---- Funktion zum Testdaten-Löschen ----
lösche_testdaten <- function(){
  q <- tolower(readline(prompt = "Testdaten löschen - sicher? "))
  if (!(q %in% c("j","y","ja"))) { return() }
  # Datenarchiv weg
  if (file.exists("daten/fom_df.rds")){
    file.remove("daten/fom_df.rds")
  }
  # Testdaten
  testdaten_files <- list.files("testdaten", full.names=TRUE) 
  for (f in testdaten_files) {
    # Grausam, I know. 
    if (str_detect(f,"ortsteile[0-9]+\\.csv") |
        str_detect(f,"wahllokale[0-9]+\\.csv")) {
      file.remove(f)
    }
  }
}

# Vorlagen laden
vorlage_wahllokale_df <- read_delim("testdaten/Open-Data-06412000-Buergerentscheid-zur-Abwahl-des-Oberbuergermeisters-der-Stadt-Frankfurt-am-Main_-Herrn-Peter-Feldmann-Stimmbezirk.csv", 
                                   delim = ";", escape_double = FALSE, 
                                   locale = locale(date_names = "de", 
                                                   decimal_mark = ",", 
                                                   grouping_mark = "."), 
                                   trim_ws = TRUE)

wahllokale_max <- sum(vorlage_wahllokale_df$`max-schnellmeldungen`)

# Konstanten für die Simulation - werden jeweils um bis zu +/-25% variiert
c_wahlberechtigt = 510000 / wahllokale_max # Gleich große Wahlbezirke
c_wahlbeteiligung = 0.3 # Wahlbeteiligung um 30%, wird im Lauf der "Wahl" erhöht (kleinere WL sind schneller ausgezählt)
c_wahlschein = 0.25 # 25% Briefwähler
c_nv = 0.05 # 0,5% wählen "spontan" und sind nicht verzeichnet (nv) im Wählerverzeichnis
c_ungültig = 0.01 # 1% Ungültige
c_nein = 0.15 # unter den gültigen: 85% Ja-Stimmen (Varianz also von ca 81-89%)

variiere <- function(x = 1) {
  # Variiert den übergebenen Wert zufällig um -25% bis +25%:
  # Zufallswerte zwischen 0,75 und 1,25 erstellen und multiplizieren
  #
  # Die Length-Funktion ist wichtig - sonst erstellt runif() nur einen 
  # Zufallswert, mit dem alle Werte von x multipliziert werden. 
  return(floor(x * (runif(length(x),0.75,1.25))))
}



i = 1
# Schleife für die Wahllokale: Solange noch nicht alle "ausgezählt" sind...
while(sum(vorlage_wahllokale_df$`anz-schnellmeldungen`) < wahllokale_max) {
  # ...splitte das df in die gemeldeten (meldungen_anz == 1) und nicht gemeldeten Zeilen
  tmp_gemeldet_df <- vorlage_wahllokale_df %>% filter(`anz-schnellmeldungen` == 1)
  # Die Variable rand wird als Anteil von 20 Meldungen an debn noch offenen Wahllokale berechnet
  rand <- 20 / (nrow(vorlage_wahllokale_df) - nrow(tmp_gemeldet_df)) 
  tmp_sample_df <- vorlage_wahllokale_df %>% 
    filter(`anz-schnellmeldungen` == 0) %>% 
    # Bei den noch nicht ausgefüllten "Meldungen" mit einer Wahrscheinlichkeit
    # von rand in die Gruppe sortieren, die neu "gemeldet" wird
    mutate(sample = (runif(nrow(.)) < rand))
  tmp_offen_df <- tmp_sample_df %>% 
    filter(sample == 0) %>%
    # sample-Variable wieder raus
    select(-sample)
  tmp_neu_df <- tmp_sample_df %>% 
    filter(sample == 1) %>% 
  select(-sample) %>% 
    # Alle als gemeldet markieren
    mutate(`anz-schnellmeldungen` = 1) %>%
    # Und jetzt der Reihe nach (weil die Werte z.T. aufeinander aufbauen)
    # Wahlberechtigte
    mutate(A = floor(c_wahlberechtigt * runif(nrow(.),0.75,1.25))) %>% 
    # Wahlschein
    mutate(A2 = floor(A * c_wahlschein * runif(nrow(.),0.75,1.25))) %>% 
    # Nicht verzeichnet
    mutate(A3 = floor(A * c_nv * runif(nrow(.),0.75,1.25))) %>% 
    # Regulär Wahlberechtigte (ohne Wahlschein oder nv)
    mutate(A1 = A - A2 - A3) %>% 
    # Abgegebene Stimmen
    mutate(B = floor(A * c_wahlbeteiligung * runif(nrow(.),0.75,1.25))) %>% 
    # davon mit Wahlschein
    mutate(B1 = floor(B * c_wahlschein * runif(nrow(.),0.75,1.25))) %>% 
    # davon ungültig
    mutate(C = floor(B * c_ungültig * runif(nrow(.),0.75,1.25))) %>% 
    # gültig
    mutate(D = B - C) %>% 
    # davon ja
    mutate(D2 = floor(D * c_nein *runif(nrow(.),0.75,1.25))) %>% 
    mutate(D1 = D - D2)
  # Kurze Statusmeldung
  cat("Neu gemeldet:",nrow(tmp_neu_df),"noch offen:",nrow(tmp_offen_df))
  # Phew. Aktualisierte Testdatei zusammenführen und anlegen. 
  vorlage_wahllokale_df <- tmp_gemeldet_df %>% 
    bind_rows(tmp_neu_df) %>% 
    bind_rows(tmp_offen_df) %>%
    # wieder in die Reihenfolge nach Wahllokal-Nummer
    arrange(`gebiet-nr`)
  
  write_csv2(vorlage_wahllokale_df,
             paste0("testdaten/wahllokale",
                    sprintf("%02i",i),
                    ".csv"),
             escape = "backslash")
  # Generiere die passende Ortsteil-Meldung
  # Geht aus irgeneindem Grund nicht, aber wir brauchens ja auch nicht. 
  # ortsteile_df <- zuordnung_wahllokale_df %>% 
  #   select(`gebiet-name` = name,ortsteilnr) %>% 
  #   left_join(vorlage_wahllokale_df,by="gebiet-name") %>% 
  #   # Zuordnung der Wahllokale
  #   group_by(ortsteilnr) %>% 
  #   # Das crasht - WTF???
  #   summarize(across(7:18, ~ sum(.,na.rm = T))) %>%
  #   left_join(stadtteile_df %>% select(ortsteilnr = nr,name),by="ortsteilnr") %>% 
  #   rename(`gebiet-nr` = ortsteilnr) %>% 
  #   mutate(`gebiet-name` = name) %>% 
  #   select(-ortsteilnr) 
    
  i <- i+1
  # Wahlbeteiligung schrittweise ein wenig anheben - um zu simulieren, 
  # dass "kleinere" Wahllokale zuerst ausgezählt werden
  c_wahlbeteiligung <- c_wahlbeteiligung + 0.002
}



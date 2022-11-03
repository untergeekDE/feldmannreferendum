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

# Vorlagen laden
vorlage_wahllokale_df <- read_delim("testdaten/Open-Data-06412000-Buergerentscheid-zur-Abwahl-des-Oberbuergermeisters-der-Stadt-Frankfurt-am-Main_-Herrn-Peter-Feldmann-Stimmbezirk.csv", 
                                   delim = ";", escape_double = FALSE, 
                                   locale = locale(date_names = "de", 
                                                   decimal_mark = ",", 
                                                   grouping_mark = "."), 
                                   trim_ws = TRUE)

wahllokale_max <- sum(vorlage_wahllokale_df$`max-schnellmeldungen`)

# Konstanten für die Simulation - werden jeweils um bis zu +/-25% variiert
rand <- 0.5 # Wahrscheinlichkeit für eine neue "Meldung" bei 1/2
c_wahlberechtigt = 510000 / wahllokale_max # Gleich große Wahlbezirke
c_wahlbeteiligung = 0.31 # Wahlbeteiligung um 31%
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
             paste0("testdaten/wahllokale",i,".csv"),
             escape = "backslash")
  i <- i+1
}


# Ortsteile werden noch vollkommen separat erzeugt. 
# Das ist natürlich nicht realistisch, aber da ich die Zuordnung noch nicht habe...

rand <- 0.9 # Wahrscheinlichkeit für eine neue "Meldung" bei 90%

# Indexdatei mit den alten Bevölkerungszahlen
index_df <- read_csv("index/stadtteile.csv") %>% 
  select(name,waehler_2018) %>%
  # Errechne Variationen der Ortsteile
  mutate(waehler = variiere(waehler_2018)) %>% 
  select(-waehler_2018)

vorlage_ortsteile_df <- read_delim("testdaten/Open-Data-06412000-Buergerentscheid-zur-Abwahl-des-Oberbuergermeisters-der-Stadt-Frankfurt-am-Main_-Herrn-Peter-Feldmann-Ortsteil.csv", 
                                   delim = ";", escape_double = FALSE, 
                                   locale = locale(date_names = "de", 
                                                   decimal_mark = ",", 
                                                   grouping_mark = "."), 
                                   trim_ws = TRUE)
  

i = 1
# Schleife für die Wahllokale: Solange noch nicht alle "ausgezählt" sind...
while(sum(vorlage_ortsteile_df$`anz-schnellmeldungen`) < wahllokale_max) {
  # ...splitte das df in die gemeldeten (meldungen_anz == meldungen_max) und nicht gemeldeten Zeilen
  tmp_gemeldet_df <- vorlage_ortsteile_df %>% 
    filter(`anz-schnellmeldungen` == `max-schnellmeldungen`)
  tmp_sample_df <- vorlage_ortsteile_df %>% 
    filter(`anz-schnellmeldungen` < `max-schnellmeldungen`) %>% 
    # Bei den noch nicht ausgefüllten "Meldungen" mit einer Wahrscheinlichkeit
    # von rand in die Gruppe sortieren, die neu "gemeldet" wird
    mutate(sample = (runif(nrow(.)) < rand))
  tmp_offen_df <- tmp_sample_df %>% 
    filter(sample == 0) %>%
    # sample-Variable wieder raus
    select(-sample)
  # Kleiner Unrealismus: Immer nur eine Meldung pro Ortsbezirk.
  # Der Einfachheit halber. 
  tmp_neu_df <- tmp_sample_df %>% 
    filter(sample == 1) %>% 
    select(-sample) %>% 
    # Alle als gemeldet markieren
    mutate(`anz-schnellmeldungen` = `anz-schnellmeldungen` + 1) %>%
    # Hole die Zahl der Wahlberechtigten dazu
    left_join(index_df, by = c("gebiet-name" = "name")) %>%
    # Wahlberechtigte je Ortsbezirk als eine fiktive Zahl zum Vergleich
    # Wir rechnen wieder mit fiktiven, tendenziell gleich großen Wahlbezirken
    # (die sich aus der Anzahl der fiktiven Wähler durch die Anzahl der WL ergeben)
    mutate(wl_waehler = floor((waehler / `max-schnellmeldungen`) * runif(nrow(.),0.75,1.25))) %>% 
    # Erhöhe die Zahl der Wahlberechtigten nach Auszählung
    mutate(A = if_else(is.na(A),
                       wl_waehler,
                       # A erhöhen; über dem definierten Limit?
                       if_else(A + wl_waehler > waehler,
                               waehler,
                               A + wl_waehler))) %>% 
    select(-waehler,-wl_waehler) %>% 
    # Und jetzt der Reihe nach (weil die Werte z.T. aufeinander aufbauen)
    # Wahlberechtigte
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
    mutate(D2 = variiere(c_nein * D)) %>% 
    mutate(D1 = D - D2)
  # Kurze Statusmeldung
  cat("Neu gemeldet:",nrow(tmp_neu_df),"noch offen:",nrow(tmp_offen_df))
  # Phew. Aktualisierte Testdatei zusammenführen und anlegen. 
  vorlage_ortsteile_df <- tmp_gemeldet_df %>% 
    bind_rows(tmp_neu_df) %>% 
    bind_rows(tmp_offen_df) %>%
    # wieder in die Reihenfolge nach Wahllokal-Nummer
    arrange(`gebiet-name`)
  
  write_csv2(vorlage_ortsteile_df,
             paste0("testdaten/ortsteile",i,".csv"),
             escape = "backslash")
  i <- i+1
}


